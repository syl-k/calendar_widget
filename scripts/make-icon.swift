import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let W = CGFloat(size)
let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil, width: size, height: size,
                          bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    fatalError("ctx")
}

func rr(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}
func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: r/255, green: g/255, blue: b/255, alpha: a)
}

// 背景: 角丸スクエア + 縦方向グラデーション(インディゴ→ブルー)
ctx.saveGState()
let bg = rr(CGRect(x: 0, y: 0, width: W, height: W), 230)
ctx.addPath(bg)
ctx.clip()
let bgColors = [rgb(90, 141, 246), rgb(58, 78, 214)] as CFArray
let bgGrad = CGGradient(colorsSpace: cs, colors: bgColors, locations: [0, 1])!
ctx.drawLinearGradient(bgGrad, start: CGPoint(x: 0, y: W), end: CGPoint(x: 0, y: 0), options: [])
ctx.restoreGState()

// カード(ウィジェット本体)を白で。落ち影付き。
let card = CGRect(x: 232, y: 210, width: 560, height: 604)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 40,
              color: rgb(20, 30, 80, 0.35))
ctx.addPath(rr(card, 76))
ctx.setFillColor(rgb(255, 255, 255, 0.97))
ctx.fillPath()
ctx.restoreGState()

// カード内クリップ
ctx.saveGState()
ctx.addPath(rr(card, 76))
ctx.clip()

let innerLeft = card.minX + 56      // ガター境界
let gutterX = card.minX + 40
let innerRight = card.maxX - 48

// 時刻ガターの目盛り線(薄いグレー、水平)
ctx.setStrokeColor(rgb(120, 130, 150, 0.22))
ctx.setLineWidth(3)
for gy in stride(from: card.minY + 70, to: card.maxY - 40, by: 96) {
    ctx.move(to: CGPoint(x: innerLeft, y: gy))
    ctx.addLine(to: CGPoint(x: innerRight, y: gy))
    ctx.strokePath()
}

// 予定ブロック(左に色帯 + 薄い塗り)。(y, 幅, 色)
struct Ev { let y: CGFloat; let h: CGFloat; let w: CGFloat; let c: CGColor }
let events: [Ev] = [
    Ev(y: 636, h: 76, w: 300, c: rgb(52, 152, 219)),   // 青
    Ev(y: 512, h: 92, w: 372, c: rgb(46, 204, 113)),   // 緑
    Ev(y: 356, h: 76, w: 250, c: rgb(155, 120, 236)),  // 紫
    Ev(y: 268, h: 60, w: 320, c: rgb(241, 148, 60)),   // 橙
]
for e in events {
    let block = CGRect(x: innerLeft, y: e.y, width: e.w, height: e.h)
    ctx.addPath(rr(block, 16))
    ctx.setFillColor(e.c.copy(alpha: 0.22)!)
    ctx.fillPath()
    // 左端の色帯
    let bar = CGRect(x: innerLeft, y: e.y + 8, width: 12, height: e.h - 16)
    ctx.addPath(rr(bar, 6))
    ctx.setFillColor(e.c)
    ctx.fillPath()
}

// 現在時刻ライン(赤 + 左端のドット)
let nowY: CGFloat = 452
ctx.setStrokeColor(rgb(235, 64, 52))
ctx.setLineWidth(9)
ctx.move(to: CGPoint(x: gutterX + 6, y: nowY))
ctx.addLine(to: CGPoint(x: innerRight, y: nowY))
ctx.strokePath()
ctx.setFillColor(rgb(235, 64, 52))
ctx.fillEllipse(in: CGRect(x: gutterX - 6, y: nowY - 15, width: 30, height: 30))

ctx.restoreGState()

// 書き出し
guard let image = ctx.makeImage() else { fatalError("image") }
let outURL = URL(fileURLWithPath: CommandLine.arguments[1])
guard let dest = CGImageDestinationCreateWithURL(outURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("dest")
}
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
print("wrote \(outURL.path)")
