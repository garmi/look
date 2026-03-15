import SwiftUI

struct LOOKEyeMark: View {
    var size: CGFloat = 28
    var background: Color = Color(red: 0.11, green: 0.11, blue: 0.18)
    var strokeColor: Color = Color(red: 0.91, green: 0.53, blue: 0.23)

    private var scale: CGFloat { size / 72.0 }

    var body: some View {
        ZStack {
            Circle()
                .fill(background)
                .frame(width: size, height: size)

            Path { path in
                path.move(to: CGPoint(x: 14 * scale, y: 36 * scale))
                path.addQuadCurve(
                    to: CGPoint(x: 58 * scale, y: 36 * scale),
                    control: CGPoint(x: 36 * scale, y: 14 * scale)
                )
                path.addQuadCurve(
                    to: CGPoint(x: 14 * scale, y: 36 * scale),
                    control: CGPoint(x: 36 * scale, y: 58 * scale)
                )
            }
            .stroke(strokeColor, lineWidth: 2.8 * scale)

            Circle()
                .stroke(strokeColor.opacity(0.55), lineWidth: 2 * scale)
                .frame(width: 20 * scale, height: 20 * scale)

            Path { path in
                path.move(to: CGPoint(x: 31 * scale, y: 33 * scale))
                path.addCurve(
                    to: CGPoint(x: 41 * scale, y: 33 * scale),
                    control1: CGPoint(x: 33 * scale, y: 30 * scale),
                    control2: CGPoint(x: 39 * scale, y: 30 * scale)
                )
                path.addCurve(
                    to: CGPoint(x: 38 * scale, y: 42 * scale),
                    control1: CGPoint(x: 43 * scale, y: 36 * scale),
                    control2: CGPoint(x: 41 * scale, y: 41 * scale)
                )
                path.addCurve(
                    to: CGPoint(x: 30 * scale, y: 38 * scale),
                    control1: CGPoint(x: 35 * scale, y: 43 * scale),
                    control2: CGPoint(x: 31 * scale, y: 41 * scale)
                )
                path.addCurve(
                    to: CGPoint(x: 31 * scale, y: 33 * scale),
                    control1: CGPoint(x: 29 * scale, y: 35 * scale),
                    control2: CGPoint(x: 29 * scale, y: 34 * scale)
                )
                path.closeSubpath()
            }
            .fill(strokeColor)

            Path { path in
                path.move(to: CGPoint(x: 29.5 * scale, y: 37.5 * scale))
                path.addQuadCurve(
                    to: CGPoint(x: 28 * scale, y: 33.5 * scale),
                    control: CGPoint(x: 26 * scale, y: 37 * scale)
                )
            }
            .stroke(
                background.opacity(0.55),
                style: StrokeStyle(lineWidth: 1.3 * scale, lineCap: .round)
            )

            Circle()
                .fill(Color.white.opacity(0.45))
                .frame(width: 4 * scale, height: 4 * scale)
                .offset(x: 3 * scale, y: -4 * scale)
        }
        .frame(width: size, height: size)
    }
}

struct LOOKEyeMark_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 16) {
            LOOKEyeMark(size: 24)
            LOOKEyeMark(size: 36)
            LOOKEyeMark(size: 60)
            LOOKEyeMark(
                size: 60,
                background: Color(red: 0.91, green: 0.53, blue: 0.23),
                strokeColor: .white
            )
        }
        .padding()
        .background(Color(red: 0.98, green: 0.97, blue: 0.95))
    }
}
