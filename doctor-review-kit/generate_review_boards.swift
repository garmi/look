import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

let base = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let screenshotsDir = base.appendingPathComponent("doctor-review-kit/screenshots", isDirectory: true)
let videoDir = base.appendingPathComponent("doctor-review-kit/video", isDirectory: true)
try? FileManager.default.createDirectory(at: screenshotsDir, withIntermediateDirectories: true)
try? FileManager.default.createDirectory(at: videoDir, withIntermediateDirectories: true)

let sunriseOrange = NSColor(calibratedRed: 0.91, green: 0.53, blue: 0.23, alpha: 1)
let healTeal = NSColor(calibratedRed: 0.00, green: 0.48, blue: 0.48, alpha: 1)
let sageGreen = NSColor(calibratedRed: 0.29, green: 0.49, blue: 0.35, alpha: 1)
let warmDawn = NSColor(calibratedRed: 0.98, green: 0.97, blue: 0.95, alpha: 1)
let darkInk = NSColor(calibratedRed: 0.11, green: 0.11, blue: 0.18, alpha: 1)
let mutedSand = NSColor(calibratedRed: 0.71, green: 0.66, blue: 0.60, alpha: 1)
let parchment = NSColor(calibratedRed: 0.98, green: 0.98, blue: 0.97, alpha: 1)
let cardBorder = NSColor.black.withAlphaComponent(0.06)
let canvas = NSSize(width: 1600, height: 900)

func bodyFont(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
    if let custom = NSFont(name: "DM Sans", size: size) { return custom }
    return NSFont.systemFont(ofSize: size, weight: weight)
}

func displayFont(_ size: CGFloat) -> NSFont {
    if let custom = NSFont(name: "DM Serif Display", size: size) { return custom }
    return NSFont(name: "Georgia", size: size) ?? NSFont.systemFont(ofSize: size, weight: .semibold)
}

func paragraph(_ align: NSTextAlignment = .left, _ lineHeight: CGFloat? = nil) -> NSMutableParagraphStyle {
    let style = NSMutableParagraphStyle()
    style.alignment = align
    if let lineHeight {
        style.minimumLineHeight = lineHeight
        style.maximumLineHeight = lineHeight
    }
    return style
}

func drawText(_ text: String, _ rect: NSRect, _ font: NSFont, _ color: NSColor, _ align: NSTextAlignment = .left, _ lineHeight: CGFloat? = nil) {
    NSString(string: text).draw(in: rect, withAttributes: [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph(align, lineHeight)
    ])
}

func rounded(_ rect: NSRect, _ radius: CGFloat, _ fill: NSColor, _ stroke: NSColor? = nil, _ lineWidth: CGFloat = 1) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    fill.setFill(); path.fill()
    if let stroke { stroke.setStroke(); path.lineWidth = lineWidth; path.stroke() }
}

func chip(_ text: String, _ rect: NSRect, _ fill: NSColor, _ textColor: NSColor) {
    rounded(rect, rect.height / 2, fill)
    drawText(text, rect.insetBy(dx: 10, dy: 6), bodyFont(16, weight: .medium), textColor, .center)
}

func spark(_ values: [CGFloat], in rect: NSRect, color: NSColor, marks: Set<Int> = []) {
    guard values.count > 1 else { return }
    let minV = values.min() ?? 0
    let maxV = values.max() ?? 1
    let range = max(maxV - minV, 1)
    let path = NSBezierPath()
    for (i, v) in values.enumerated() {
        let x = rect.minX + rect.width * CGFloat(i) / CGFloat(values.count - 1)
        let y = rect.minY + rect.height * ((v - minV) / range)
        if i == 0 { path.move(to: .init(x: x, y: y)) } else { path.line(to: .init(x: x, y: y)) }
        let marker = NSBezierPath(ovalIn: NSRect(x: x - 5, y: y - 5, width: 10, height: 10))
        (marks.contains(i) ? sunriseOrange : color).setFill(); marker.fill()
    }
    color.setStroke(); path.lineWidth = 4; path.stroke()
}

func navbar(_ page: String, dot: Bool) {
    drawText("LOOK", NSRect(x: 84, y: 820, width: 120, height: 28), displayFont(22), darkInk)
    drawText(page, NSRect(x: 182, y: 822, width: 200, height: 22), bodyFont(16, weight: .light), mutedSand)
    rounded(NSRect(x: 48, y: 818, width: 28, height: 28), 14, darkInk)
    let eye = NSBezierPath(ovalIn: NSRect(x: 57, y: 827, width: 10, height: 10))
    sunriseOrange.setStroke(); eye.lineWidth = 2; eye.stroke()
    if dot { rounded(NSRect(x: 1518, y: 828, width: 12, height: 12), 6, sunriseOrange) }
    rounded(NSRect(x: 0, y: 790, width: 1600, height: 1), 0, NSColor.black.withAlphaComponent(0.06))
}

func sectionHeader(_ title: String, _ subtitle: String) {
    drawText(title, NSRect(x: 72, y: 706, width: 700, height: 60), displayFont(44), darkInk)
    drawText(subtitle, NSRect(x: 72, y: 676, width: 840, height: 28), bodyFont(20, weight: .light), mutedSand)
    let bandRect = NSRect(x: 72, y: 650, width: 520, height: 6)
    let gradient = NSGradient(colors: [sunriseOrange, NSColor(calibratedRed: 0.96, green: 0.76, blue: 0.50, alpha: 1), NSColor(calibratedRed: 0.83, green: 0.77, blue: 0.71, alpha: 1)])!
    let path = NSBezierPath(roundedRect: bandRect, xRadius: 3, yRadius: 3)
    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    gradient.draw(in: bandRect, angle: 0)
    NSGraphicsContext.restoreGraphicsState()
}

func savePNG(_ name: String, draw: () -> Void) throws {
    let image = NSImage(size: canvas)
    image.lockFocus()
    parchment.setFill(); NSBezierPath(rect: NSRect(origin: .zero, size: canvas)).fill()
    draw()
    image.unlockFocus()
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { throw NSError(domain: "png", code: 1) }
    try png.write(to: screenshotsDir.appendingPathComponent(name))
}

try savePNG("01_dashboard_board.png") {
    navbar("Home", dot: true)
    sectionHeader("Morning Dashboard", "Daily check-in, medication confirmation, and document upload")
    rounded(NSRect(x: 72, y: 374, width: 690, height: 236), 28, darkInk)
    drawText("MORNING CHECK-IN", NSRect(x: 100, y: 566, width: 200, height: 18), bodyFont(13, weight: .medium), mutedSand.withAlphaComponent(0.6))
    drawText("How are you\nfeeling today?", NSRect(x: 100, y: 470, width: 300, height: 92), displayFont(34), .white, .left, 38)
    chip("🟢  All good", NSRect(x: 100, y: 404, width: 170, height: 42), sageGreen.withAlphaComponent(0.18), sageGreen)
    chip("🟡  Unsure", NSRect(x: 282, y: 404, width: 150, height: 42), sunriseOrange.withAlphaComponent(0.16), sunriseOrange)
    chip("🔴  Help", NSRect(x: 444, y: 404, width: 120, height: 42), NSColor.systemRed.withAlphaComponent(0.14), .systemRed)

    rounded(NSRect(x: 792, y: 474, width: 336, height: 136), 24, sageGreen.withAlphaComponent(0.06), sageGreen.withAlphaComponent(0.14))
    drawText("Medication", NSRect(x: 820, y: 556, width: 180, height: 26), bodyFont(24, weight: .medium), darkInk)
    drawText("Taken · 08:03", NSRect(x: 820, y: 528, width: 180, height: 22), bodyFont(16, weight: .light), mutedSand)
    chip("Taken ✓", NSRect(x: 968, y: 494, width: 126, height: 40), sageGreen.withAlphaComponent(0.12), sageGreen)

    rounded(NSRect(x: 1156, y: 474, width: 372, height: 136), 24, warmDawn, sunriseOrange.withAlphaComponent(0.12))
    drawText("Safety", NSRect(x: 1184, y: 556, width: 160, height: 26), bodyFont(24, weight: .medium), darkInk)
    drawText("LOOK supports and prepares. It does not diagnose.", NSRect(x: 1184, y: 500, width: 300, height: 50), bodyFont(16, weight: .light), mutedSand, .left, 22)

    rounded(NSRect(x: 792, y: 280, width: 356, height: 160), 24, .white, cardBorder)
    drawText("Blood Report", NSRect(x: 820, y: 386, width: 200, height: 24), bodyFont(22, weight: .medium), darkInk)
    drawText("PDF or photo upload", NSRect(x: 820, y: 356, width: 200, height: 20), bodyFont(16, weight: .light), mutedSand)
    drawText("🩸", NSRect(x: 818, y: 308, width: 60, height: 40), bodyFont(34, weight: .regular), darkInk)
    drawText("Tap to upload", NSRect(x: 886, y: 318, width: 120, height: 24), bodyFont(15, weight: .regular), healTeal)

    rounded(NSRect(x: 1172, y: 280, width: 356, height: 160), 24, .white, cardBorder)
    drawText("Prescription", NSRect(x: 1200, y: 386, width: 200, height: 24), bodyFont(22, weight: .medium), darkInk)
    drawText("PDF or photo upload", NSRect(x: 1200, y: 356, width: 200, height: 20), bodyFont(16, weight: .light), mutedSand)
    drawText("📄", NSRect(x: 1198, y: 308, width: 60, height: 40), bodyFont(34, weight: .regular), darkInk)
    drawText("Tap to upload", NSRect(x: 1266, y: 318, width: 120, height: 24), bodyFont(15, weight: .regular), healTeal)

    rounded(NSRect(x: 72, y: 170, width: 690, height: 172), 24, sunriseOrange.withAlphaComponent(0.08), sunriseOrange.withAlphaComponent(0.18))
    drawText("Today's insight", NSRect(x: 100, y: 298, width: 200, height: 24), bodyFont(18, weight: .medium), sunriseOrange)
    drawText("\"Missing even one dose of tacrolimus can trigger rejection. The pill works invisibly — take it anyway.\"", NSRect(x: 100, y: 214, width: 610, height: 80), displayFont(26), darkInk, .left, 32)
}

try savePNG("02_trials_board.png") {
    navbar("Health", dot: false)
    sectionHeader("Daily Trials", "Structured symptom, medication, and mood logging")
    rounded(NSRect(x: 72, y: 566, width: 360, height: 64), 24, NSColor(calibratedRed: 0.93, green: 0.91, blue: 0.89, alpha: 1))
    rounded(NSRect(x: 78, y: 572, width: 168, height: 52), 20, .white)
    drawText("Daily Log", NSRect(x: 78, y: 588, width: 168, height: 20), bodyFont(17, weight: .medium), darkInk, .center)
    drawText("Medication", NSRect(x: 246, y: 588, width: 178, height: 20), bodyFont(17, weight: .regular), mutedSand, .center)

    rounded(NSRect(x: 72, y: 252, width: 708, height: 272), 24, .white, cardBorder)
    drawText("Overall today", NSRect(x: 100, y: 478, width: 180, height: 20), bodyFont(16, weight: .medium), mutedSand)
    let widths: [CGFloat] = [205,205,205]
    let colors: [NSColor] = [sageGreen, sunriseOrange, .systemRed]
    let labels = ["Stable", "Watch", "Escalate"]
    let emojis = ["🟢", "🟡", "🔴"]
    for i in 0..<3 {
        let x = 100 + CGFloat(i) * 215
        rounded(NSRect(x: x, y: 320, width: widths[i], height: 122), 20, colors[i].withAlphaComponent(i == 0 ? 0.18 : 0.08), colors[i].withAlphaComponent(i == 0 ? 1 : 0.22), i == 0 ? 2 : 1)
        drawText(emojis[i], NSRect(x: x, y: 382, width: widths[i], height: 24), bodyFont(28, weight: .regular), colors[i], .center)
        drawText(labels[i], NSRect(x: x, y: 348, width: widths[i], height: 20), bodyFont(16, weight: .medium), colors[i], .center)
    }

    rounded(NSRect(x: 820, y: 414, width: 708, height: 214), 24, .white, cardBorder)
    drawText("How is your energy today?", NSRect(x: 848, y: 580, width: 300, height: 26), bodyFont(24, weight: .medium), darkInk)
    drawText("Compared to your own baseline", NSRect(x: 848, y: 552, width: 300, height: 20), bodyFont(16, weight: .light), mutedSand)
    let chipLabels = ["Very low", "Low", "Normal", "Good", "Great"]
    let chipColors = [sunriseOrange, sunriseOrange, sageGreen, sageGreen, sageGreen]
    for i in 0..<5 {
        let x = 848 + CGFloat(i) * 132
        chip(chipLabels[i], NSRect(x: x, y: 470, width: 122, height: 40), chipColors[i].withAlphaComponent(i == 3 ? 0.18 : 0.08), chipColors[i])
    }

    rounded(NSRect(x: 820, y: 170, width: 708, height: 214), 24, .white, cardBorder)
    drawText("Medication taken today", NSRect(x: 848, y: 336, width: 280, height: 26), bodyFont(24, weight: .medium), darkInk)
    drawText("Custom reminder logs and acknowledgements", NSRect(x: 848, y: 308, width: 340, height: 20), bodyFont(16, weight: .light), mutedSand)
    chip("Tacrolimus 8:00 AM", NSRect(x: 848, y: 238, width: 176, height: 38), healTeal.withAlphaComponent(0.12), healTeal)
    chip("Mycophenolate 9:00 AM", NSRect(x: 1036, y: 238, width: 214, height: 38), sunriseOrange.withAlphaComponent(0.12), sunriseOrange)
    chip("Acknowledged ✓", NSRect(x: 1262, y: 238, width: 154, height: 38), sageGreen.withAlphaComponent(0.12), sageGreen)
}

try savePNG("03_insights_board.png") {
    navbar("Insights", dot: false)
    sectionHeader("Insights", "Trend graphs, notable days, and doctor-ready summaries")
    rounded(NSRect(x: 72, y: 346, width: 720, height: 280), 24, .white, cardBorder)
    drawText("7-day adherence", NSRect(x: 100, y: 580, width: 220, height: 26), bodyFont(24, weight: .medium), darkInk)
    drawText("Missed doses and stable days", NSRect(x: 100, y: 550, width: 240, height: 20), bodyFont(16, weight: .light), mutedSand)
    spark([78, 92, 88, 100, 61, 84, 100], in: NSRect(x: 110, y: 430, width: 650, height: 90), color: healTeal, marks: [4])
    chip("Missed tacrolimus", NSRect(x: 110, y: 378, width: 180, height: 38), sunriseOrange.withAlphaComponent(0.12), sunriseOrange)

    rounded(NSRect(x: 72, y: 126, width: 720, height: 180), 24, sunriseOrange.withAlphaComponent(0.06), sunriseOrange.withAlphaComponent(0.14))
    drawText("Lab trends", NSRect(x: 100, y: 264, width: 180, height: 26), bodyFont(24, weight: .medium), darkInk)
    spark([1.6, 1.5, 1.4, 1.45, 1.38, 1.34], in: NSRect(x: 110, y: 176, width: 650, height: 62), color: sunriseOrange)
    drawText("Creatinine baseline stabilizing over the last 2 weeks.", NSRect(x: 110, y: 142, width: 420, height: 20), bodyFont(16, weight: .light), mutedSand)

    rounded(NSRect(x: 826, y: 126, width: 702, height: 500), 24, warmDawn, sunriseOrange.withAlphaComponent(0.12))
    drawText("For Doctor", NSRect(x: 854, y: 580, width: 220, height: 30), bodyFont(26, weight: .medium), darkInk)
    drawText("Pre-visit summary generated from logs, labs, and questions", NSRect(x: 854, y: 548, width: 420, height: 20), bodyFont(16, weight: .light), mutedSand)
    drawText("• One missed evening medication confirmation this week\n• Energy stable, no red symptom flags\n• Creatinine trending down from 1.6 to 1.34\n• Patient wants guidance on tacrolimus timing and sun exposure", NSRect(x: 854, y: 324, width: 610, height: 176), bodyFont(24, weight: .light), darkInk, .left, 34)
    chip("Export PDF", NSRect(x: 854, y: 166, width: 140, height: 40), darkInk, .white)
}

try savePNG("04_upload_board.png") {
    navbar("Upload", dot: false)
    sectionHeader("Document Upload", "Blood report and prescription extraction for review")
    rounded(NSRect(x: 72, y: 126, width: 650, height: 500), 24, warmDawn, sunriseOrange.withAlphaComponent(0.12))
    drawText("Blood report extraction", NSRect(x: 100, y: 578, width: 260, height: 28), bodyFont(26, weight: .medium), darkInk)
    drawText("Key values for transplant follow-up", NSRect(x: 100, y: 546, width: 280, height: 20), bodyFont(16, weight: .light), mutedSand)
    let rows = [
      ("Creatinine", "1.34 mg/dL", sageGreen),
      ("eGFR", "64 mL/min", sageGreen),
      ("Tacrolimus", "5.9 ng/mL", sunriseOrange),
      ("Potassium", "5.3 mmol/L", sunriseOrange)
    ]
    for (i, row) in rows.enumerated() {
      let y = 470 - CGFloat(i) * 86
      drawText(row.0, NSRect(x: 104, y: y, width: 220, height: 24), bodyFont(22, weight: .medium), darkInk)
      drawText(row.1, NSRect(x: 430, y: y, width: 220, height: 24), bodyFont(22, weight: .medium), row.2, .right)
      rounded(NSRect(x: 100, y: y - 20, width: 560, height: 1), 0, cardBorder)
    }
    drawText("Values worth discussing: tacrolimus trough timing and potassium.", NSRect(x: 104, y: 164, width: 520, height: 42), bodyFont(18, weight: .light), sunriseOrange, .left, 24)

    rounded(NSRect(x: 760, y: 126, width: 768, height: 500), 24, .white, cardBorder)
    drawText("Prescription extraction", NSRect(x: 788, y: 578, width: 280, height: 28), bodyFont(26, weight: .medium), darkInk)
    drawText("Medications, dose, frequency, timing", NSRect(x: 788, y: 546, width: 340, height: 20), bodyFont(16, weight: .light), mutedSand)
    chip("Tacrolimus · 1 mg · Twice daily", NSRect(x: 788, y: 470, width: 330, height: 42), healTeal.withAlphaComponent(0.12), healTeal)
    chip("Mycophenolate · 500 mg · Twice daily", NSRect(x: 788, y: 414, width: 394, height: 42), sunriseOrange.withAlphaComponent(0.12), sunriseOrange)
    chip("Prednisolone · 5 mg · Morning", NSRect(x: 788, y: 358, width: 326, height: 42), sageGreen.withAlphaComponent(0.12), sageGreen)
    drawText("Always follow the original prescription exactly. LOOK extraction is for reference and visit prep.", NSRect(x: 788, y: 214, width: 650, height: 54), bodyFont(18, weight: .light), mutedSand, .left, 24)
}

try savePNG("05_directory_board.png") {
    navbar("Directory", dot: false)
    sectionHeader("Directory", "Clinicians, knowledge, and support groups")
    rounded(NSRect(x: 72, y: 410, width: 720, height: 216), 24, .white, cardBorder)
    drawText("Dr. Shalini Menon", NSRect(x: 100, y: 576, width: 280, height: 28), bodyFont(26, weight: .medium), darkInk)
    drawText("Transplant nephrology · Bengaluru", NSRect(x: 100, y: 544, width: 320, height: 20), bodyFont(16, weight: .light), mutedSand)
    drawText("Apollo Hospital · Tacrolimus management, post-transplant follow-up", NSRect(x: 100, y: 492, width: 540, height: 40), bodyFont(18, weight: .light), mutedSand, .left, 24)
    chip("Open profile", NSRect(x: 100, y: 438, width: 120, height: 36), healTeal.withAlphaComponent(0.12), healTeal)

    rounded(NSRect(x: 72, y: 154, width: 720, height: 216), 24, .white, cardBorder)
    drawText("Dr. Raghav Rao", NSRect(x: 100, y: 320, width: 280, height: 28), bodyFont(26, weight: .medium), darkInk)
    drawText("Kidney transplant surgeon · Hyderabad", NSRect(x: 100, y: 288, width: 360, height: 20), bodyFont(16, weight: .light), mutedSand)
    drawText("AIG Hospitals · Transplant follow-up, donor pathways", NSRect(x: 100, y: 236, width: 520, height: 40), bodyFont(18, weight: .light), mutedSand, .left, 24)
    chip("Open profile", NSRect(x: 100, y: 182, width: 120, height: 36), sunriseOrange.withAlphaComponent(0.12), sunriseOrange)

    rounded(NSRect(x: 826, y: 154, width: 702, height: 472), 24, healTeal.withAlphaComponent(0.05), healTeal.withAlphaComponent(0.12))
    drawText("Community and knowledge", NSRect(x: 854, y: 578, width: 320, height: 28), bodyFont(26, weight: .medium), darkInk)
    drawText("City, language, and caregiver-aware resources", NSRect(x: 854, y: 546, width: 360, height: 20), bodyFont(16, weight: .light), mutedSand)
    chip("Bengaluru · English group", NSRect(x: 854, y: 454, width: 242, height: 40), healTeal.withAlphaComponent(0.12), healTeal)
    chip("Hyderabad · Telugu group", NSRect(x: 1108, y: 454, width: 242, height: 40), healTeal.withAlphaComponent(0.12), healTeal)
    chip("Caregivers", NSRect(x: 1362, y: 454, width: 120, height: 40), sunriseOrange.withAlphaComponent(0.12), sunriseOrange)
    drawText("Articles include medication adherence, fatigue, sun exposure, and preparing better questions for clinic visits.", NSRect(x: 854, y: 344, width: 600, height: 70), bodyFont(20, weight: .light), darkInk, .left, 28)
}

let gifURL = videoDir.appendingPathComponent("LOOK_Doctor_Walkthrough.gif")
if FileManager.default.fileExists(atPath: gifURL.path) { try? FileManager.default.removeItem(at: gifURL) }
let frames = ["01_dashboard_board.png", "02_trials_board.png", "03_insights_board.png", "04_upload_board.png", "05_directory_board.png"]
guard let dest = CGImageDestinationCreateWithURL(gifURL as CFURL, UTType.gif.identifier as CFString, frames.count, nil) else {
    fatalError("Unable to create GIF")
}
CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
for name in frames {
    let url = screenshotsDir.appendingPathComponent(name)
    guard let img = NSImage(contentsOf: url), let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { fatalError("Missing frame \(name)") }
    CGImageDestinationAddImage(dest, cg, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 2.0]] as CFDictionary)
}
CGImageDestinationFinalize(dest)

let readme = """
LOOK Doctor Review Kit
Generated on 22 March 2026

Files to share
- docs/LOOK_Doctor_Review_Summary.pdf
- docs/LOOK_Doctor_Feedback_Form.md
- docs/LOOK_Doctor_Review_Email.txt
- screenshots/01_dashboard_board.png
- screenshots/02_trials_board.png
- screenshots/03_insights_board.png
- screenshots/04_upload_board.png
- screenshots/05_directory_board.png
- video/LOOK_Doctor_Walkthrough.gif

Notes
- The screenshots are review boards based on the current app flow and feature set.
- The GIF is a silent walkthrough for initial clinician assessment.
"""
try readme.write(to: base.appendingPathComponent("doctor-review-kit/README.txt"), atomically: true, encoding: .utf8)
print("Generated review boards and walkthrough GIF.")
