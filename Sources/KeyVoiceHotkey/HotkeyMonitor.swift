import Foundation
import CoreGraphics
import KeyVoiceCore

/// Global push-to-talk on the Right-Option key, via a **listen-only** CGEvent tap so normal
/// typing and ⌥-accent combos are never blocked (plan Phase 2, seam 5).
///
/// Why a tap and not an `NSEvent` global monitor: only a session event tap gives reliable
/// modifier up/down for a key that is otherwise swallowed by the accent/IME machinery, and it
/// sees `keyDown` for *other* keys so we can detect combos. The tap is `.listenOnly`, so the
/// callback never suppresses anything — it returns every event unchanged.
///
/// Gesture state machine (all mutated on the run loop the tap is attached to — the main thread —
/// so no locking is needed):
///   • Right-Option DOWN  → arm: record time, schedule a `.begin` check after `minHold`.
///   • debounce fires      → still held & not poisoned → emit `.begin`.
///   • any other key/mod   → poison; on release we emit `.cancel(.comboKey)`.
///   • Right-Option UP     → poisoned ⇒ `.cancel(.comboKey)`; began ⇒ `.commit`; else ⇒ `.cancel(.tooShort)`.
public final class HotkeyMonitor: HotkeyMonitoring {
    public var onEvent: ((HotkeyEvent) -> Void)?

    private let config: AppConfig

    // Tap lifetime.
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // Gesture state. Touched only from the tap callback / debounce work item, both of which run
    // on the run loop the tap is added to, so access is serial and lock-free.
    private var isRightOptionDown = false
    private var didBegin = false
    private var poisoned = false
    private var downTimestamp: CFAbsoluteTime = 0
    private var pendingBegin: DispatchWorkItem?

    public init(config: AppConfig = AppConfig()) {
        self.config = config
    }

    // MARK: - HotkeyMonitoring

    public func start() throws {
        // Input Monitoring is the permission a listen-only key tap needs. If it isn't granted,
        // kick off the system prompt and bail — the app retries start() after the user grants it.
        if !CGPreflightListenEventAccess() {
            CGRequestListenEventAccess()
            throw KeyVoiceError.inputMonitoringDenied
        }

        // Already running? Nothing to do.
        guard eventTap == nil else { return }

        let mask: CGEventMask =
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.keyDown.rawValue)

        // Non-capturing C callback: recover `self` from the refcon and forward.
        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
            return monitor.handle(proxy: proxy, type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            // tapCreate returns nil when Input Monitoring is not actually granted yet.
            throw KeyVoiceError.inputMonitoringDenied
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source
    }

    public func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        resetGesture()
    }

    // MARK: - Tap callback

    private func handle(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent> {
        // Pass-through: whatever we do, the event leaves untouched (listen-only anyway).
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // The OS disabled us (slow callback, or a security-sensitive field). Re-arm and forget
            // any half-formed gesture rather than emitting a bogus commit/cancel.
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            resetGesture()

        case .flagsChanged:
            handleFlagsChanged(event)

        case .keyDown:
            // Any real key pressed while Right-Option is held is a combo (e.g. ⌥ + a letter).
            if isRightOptionDown {
                poisoned = true
            }

        default:
            break
        }

        return Unmanaged.passUnretained(event)
    }

    private func handleFlagsChanged(_ event: CGEvent) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let optionDownNow = event.flags.contains(.maskAlternate)

        if keyCode == config.rightOptionKeyCode {
            if optionDownNow {
                rightOptionPressed()
            } else {
                rightOptionReleased()
            }
        } else {
            // A different modifier changed. If it happens mid-hold it's a combo (e.g. ⌥⇧),
            // so poison the gesture; the cancel is emitted on release.
            if isRightOptionDown {
                poisoned = true
            }
        }
    }

    // MARK: - Gesture transitions

    private func rightOptionPressed() {
        // Ignore duplicate downs (shouldn't happen for modifiers, but stay defensive).
        guard !isRightOptionDown else { return }

        isRightOptionDown = true
        didBegin = false
        poisoned = false
        downTimestamp = CFAbsoluteTimeGetCurrent()

        // Debounce: only after minHold, and only if still cleanly held, do we spin up the mic.
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.isRightOptionDown, !self.poisoned, !self.didBegin else { return }
            self.didBegin = true
            self.onEvent?(.begin)
        }
        pendingBegin = work
        DispatchQueue.main.asyncAfter(deadline: .now() + config.minHold, execute: work)
    }

    private func rightOptionReleased() {
        guard isRightOptionDown else { return }
        isRightOptionDown = false

        pendingBegin?.cancel()
        pendingBegin = nil

        if poisoned {
            // A combo key touched the gesture — discard it whether or not begin already fired.
            onEvent?(.cancel(reason: .comboKey))
        } else if didBegin {
            onEvent?(.commit(holdDuration: CFAbsoluteTimeGetCurrent() - downTimestamp))
        } else {
            // Released before the debounce elapsed — a tap, not dictation.
            onEvent?(.cancel(reason: .tooShort))
        }

        didBegin = false
        poisoned = false
    }

    private func resetGesture() {
        pendingBegin?.cancel()
        pendingBegin = nil
        isRightOptionDown = false
        didBegin = false
        poisoned = false
    }
}
