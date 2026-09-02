#!/usr/bin/env swift
// Generates KeyVoice's app icon — a glass droplet holding a soundwave — as a full .iconset and,
// via iconutil, Packaging/AppIcon.icns. Pure CoreGraphics so it's reproducible (no design tool).
// Usage: swift Scripts/gen-icon.swift            → writes /tmp/keyvoice-icon-1024.png + Packaging/AppIcon.icns
//        swift Scripts/gen-icon.swift preview     → writes only /tmp/keyvoice-icon-1024.png (for review)
import Foundation
import CoreGraphics
import ImageIO

func draw(_ ctx: CGContext, _ S: CGFloat) {
    let cs = CGColorSpaceCreateDeviceRGB()
    func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
        CGColor(colorSpace: cs, components: [r, g, b, a])!
    }
    ctx.setAllowsAntialiasing(true)

    // Rounded-rect background (squircle-ish) with a cool night gradient.
    let r = S * 0.2235
    let bg = CGPath(roundedRect: CGRect(x: 0, y: 0, width: S, height: S), cornerWidth: r, cornerHeight: r, transform: nil)
    ctx.saveGState(); ctx.addPath(bg); ctx.clip()
    let grad = CGGradient(colorsSpace: cs, colors: [c(0.07,0.12,0.24), c(0.03,0.04,0.09)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: S), end: CGPoint(x: 0, y: 0), options: [])
    // soft top glow
    let glow = CGGradient(colorsSpace: cs, colors: [c(0.30,0.55,0.95,0.35), c(0.30,0.55,0.95,0)] as CFArray, locations: [0,1])!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: S*0.5, y: S*0.86), startRadius: 0, endCenter: CGPoint(x: S*0.5, y: S*0.86), endRadius: S*0.6, options: [])

    // Droplet path (point up, round bottom).
    let cx = S*0.5, cy = S*0.455, R = S*0.205
    let topY = cy + R*2.1
    let drop = CGMutablePath()
    drop.move(to: CGPoint(x: cx, y: topY))
    // Convex sides that bulge out then taper to the tip → a rounded teardrop, not an arrowhead.
    drop.addCurve(to: CGPoint(x: cx - R, y: cy),
                  control1: CGPoint(x: cx - R*0.86, y: topY - R*0.75),
                  control2: CGPoint(x: cx - R*1.08, y: cy + R*0.72))
    drop.addArc(center: CGPoint(x: cx, y: cy), radius: R, startAngle: .pi, endAngle: 0, clockwise: true)
    drop.addCurve(to: CGPoint(x: cx, y: topY),
                  control1: CGPoint(x: cx + R*1.08, y: cy + R*0.72),
                  control2: CGPoint(x: cx + R*0.86, y: topY - R*0.75))
    drop.closeSubpath()

    // Glass fill (translucent ice) + rim.
    ctx.saveGState(); ctx.addPath(drop); ctx.clip()
    let glass = CGGradient(colorsSpace: cs, colors: [c(0.80,0.91,1.0,0.42), c(0.52,0.76,1.0,0.24)] as CFArray, locations: [0,1])!
    ctx.drawLinearGradient(glass, start: CGPoint(x: 0, y: topY), end: CGPoint(x: 0, y: cy - R*1.25), options: [])
    // specular highlight
    let spec = CGGradient(colorsSpace: cs, colors: [c(1,1,1,0.55), c(1,1,1,0)] as CFArray, locations: [0,1])!
    ctx.drawRadialGradient(spec, startCenter: CGPoint(x: cx - R*0.4, y: cy + R*0.5), startRadius: 0, endCenter: CGPoint(x: cx - R*0.4, y: cy + R*0.5), endRadius: R*0.9, options: [])
    ctx.restoreGState()
    ctx.addPath(drop); ctx.setStrokeColor(c(0.66,0.85,1.0,0.55)); ctx.setLineWidth(S*0.006); ctx.strokePath()

    // Soundwave — rounded bars centered in the droplet, ice/white.
    let bars: [CGFloat] = [0.42, 0.72, 1.0, 0.72, 0.48]
    let bw = R*0.16, gap = R*0.22
    let total = CGFloat(bars.count)*bw + CGFloat(bars.count - 1)*gap
    var x = cx - total/2
    for h in bars {
        let bh = R*0.95*h
        let rect = CGRect(x: x, y: cy - bh/2, width: bw, height: bh)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: bw/2, cornerHeight: bw/2, transform: nil))
        ctx.setFillColor(c(0.93,0.97,1.0,0.95)); ctx.fillPath()
        x += bw + gap
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
