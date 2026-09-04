#!/usr/bin/env swift
// Generates KeyVoice's app icon — a keycap holding a voice spectrum — as a full .iconset and,
// via iconutil, Packaging/AppIcon.icns. "Key" + "Voice": the mark names the push-to-talk interaction.
// Pure CoreGraphics so it's reproducible (no design tool).
// Usage: swift Scripts/gen-icon.swift            → /tmp/keyvoice-icon-1024.png + Packaging/AppIcon.icns
//        swift Scripts/gen-icon.swift preview     → only /tmp/keyvoice-icon-1024.png (for review)
import Foundation
import CoreGraphics
import ImageIO

func draw(_ ctx: CGContext, _ S: CGFloat) {
    let cs = CGColorSpaceCreateDeviceRGB()
    func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
        CGColor(colorSpace: cs, components: [r, g, b, a])!
    }
    ctx.setAllowsAntialiasing(true)

    // Warm-paper tile (matches the Studio canvas).
    let corner = S * 0.2235
    let bg = CGPath(roundedRect: CGRect(x: 0, y: 0, width: S, height: S), cornerWidth: corner, cornerHeight: corner, transform: nil)
    ctx.saveGState(); ctx.addPath(bg); ctx.clip()
    let paper = CGGradient(colorsSpace: cs, colors: [c(0.972, 0.964, 0.945), c(0.902, 0.890, 0.860)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(paper, start: CGPoint(x: 0, y: S), end: CGPoint(x: 0, y: 0), options: [])
    // faint warm top glow
    let glow = CGGradient(colorsSpace: cs, colors: [c(1, 1, 0.98, 0.5), c(1, 1, 0.98, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: S*0.5, y: S*0.9), startRadius: 0, endCenter: CGPoint(x: S*0.5, y: S*0.9), endRadius: S*0.7, options: [])

    // --- Keycap ------------------------------------------------------------------------------
    let capW = S * 0.52, capH = S * 0.52
    let capX = (S - capW) / 2, capY = (S - capH) / 2 - S * 0.01
    let capR = S * 0.155
    let cap = CGPath(roundedRect: CGRect(x: capX, y: capY, width: capW, height: capH), cornerWidth: capR, cornerHeight: capR, transform: nil)

    // Drop shadow of the cap onto the paper.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -S*0.012), blur: S*0.05, color: c(0.10, 0.08, 0.06, 0.35))
    ctx.addPath(cap); ctx.setFillColor(c(0.09, 0.082, 0.07)); ctx.fillPath()
    ctx.restoreGState()

    // Keycap body: vertical velvet gradient for depth.
    ctx.saveGState(); ctx.addPath(cap); ctx.clip()
    let velvet = CGGradient(colorsSpace: cs, colors: [c(0.145, 0.129, 0.109), c(0.055, 0.047, 0.039)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(velvet, start: CGPoint(x: 0, y: capY + capH), end: CGPoint(x: 0, y: capY), options: [])
    ctx.restoreGState()

    // Top rim highlight + a dished inner face.
    ctx.addPath(cap); ctx.setStrokeColor(c(1, 1, 1, 0.14)); ctx.setLineWidth(S*0.007); ctx.strokePath()
    let inset = S * 0.045
    let faceRect = CGRect(x: capX + inset, y: capY + inset, width: capW - inset*2, height: capH - inset*2)
    let faceR = capR - inset*0.7
    let face = CGPath(roundedRect: faceRect, cornerWidth: faceR, cornerHeight: faceR, transform: nil)
    ctx.saveGState(); ctx.addPath(face); ctx.clip()
    let dish = CGGradient(colorsSpace: cs, colors: [c(0.180, 0.160, 0.137), c(0.086, 0.074, 0.062)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(dish, start: CGPoint(x: 0, y: faceRect.maxY), end: CGPoint(x: 0, y: faceRect.minY), options: [])
    ctx.restoreGState()

    // --- Voice spectrum on the keycap face ---------------------------------------------------
    // Five rounded bars, left→right spectrum, glowing.
    let spectrum = [c(0.416, 0.298, 1.0), c(0.298, 0.482, 1.0), c(0.184, 0.816, 0.812), c(1.0, 0.694, 0.306), c(1.0, 0.361, 0.541)]
    let heights: [CGFloat] = [0.40, 0.72, 1.0, 0.66, 0.46]
    let n = heights.count
    let bw = faceRect.width * 0.085
    let gap = (faceRect.width * 0.60 - bw) / CGFloat(n - 1)
    let totalW = CGFloat(n) * bw + CGFloat(n - 1) * (gap - bw)
    var x = faceRect.midX - totalW / 2
    let maxBar = faceRect.height * 0.62
    for i in 0..<n {
        let bh = maxBar * heights[i]
        let rect = CGRect(x: x, y: faceRect.midY - bh/2, width: bw, height: bh)
        // soft glow
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: S*0.02, color: spectrum[i].copy(alpha: 0.7)!)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: bw/2, cornerHeight: bw/2, transform: nil))
        ctx.setFillColor(spectrum[i]); ctx.fillPath()
        ctx.restoreGState()
        x += gap
    }
    ctx.restoreGState()
}

func makePNG(_ S: Int, _ url: URL) {
    let cs = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(data: nil, width: S, height: S, bitsPerComponent: 8, bytesPerRow: 0,
                        space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    draw(ctx, CGFloat(S))
    guard let img = ctx.makeImage(),
          let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { return }
    CGImageDestinationAddImage(dest, img, nil)
    CGImageDestinationFinalize(dest)
}

let preview = CommandLine.arguments.contains("preview")
makePNG(1024, URL(fileURLWithPath: "/tmp/keyvoice-icon-1024.png"))
print("wrote /tmp/keyvoice-icon-1024.png")
if preview { exit(0) }

// Full iconset → icns
let iconset = URL(fileURLWithPath: "/tmp/KeyVoice.iconset")
try? FileManager.default.removeItem(at: iconset)
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
let specs: [(Int, String)] = [(16,"16x16"),(32,"16x16@2x"),(32,"32x32"),(64,"32x32@2x"),
    (128,"128x128"),(256,"128x128@2x"),(256,"256x256"),(512,"256x256@2x"),(512,"512x512"),(1024,"512x512@2x")]
for (px, name) in specs { makePNG(px, iconset.appendingPathComponent("icon_\(name).png")) }
FileManager.default.createFile(atPath: "Packaging/.keep", contents: nil)
let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", "Packaging/AppIcon.icns"]
try? p.run(); p.waitUntilExit()
print("wrote Packaging/AppIcon.icns")
