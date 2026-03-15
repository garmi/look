import SwiftUI
import UIKit

struct LOOKNavBar: View {
    var pageTitle: String = ""
    var showNotificationDot: Bool = true
    var background: Color = Color(red: 0.98, green: 0.98, blue: 0.97)

    var body: some View {
        HStack(spacing: 9) {
            LOOKEyeMark(size: 28)

            Text("LOOK")
                .font(navTitleFont)
                .tracking(4)
                .foregroundColor(Color(red: 0.11, green: 0.11, blue: 0.18))

            if !pageTitle.isEmpty {
                Text("·")
                    .foregroundColor(Color(red: 0.71, green: 0.66, blue: 0.60))
                    .font(.system(size: 12))

                Text(pageTitle)
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(Color(red: 0.71, green: 0.66, blue: 0.60))
            }

            Spacer()

            if showNotificationDot {
                Circle()
                    .fill(Color(red: 0.91, green: 0.53, blue: 0.23))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(background)
        .overlay(
            Rectangle()
                .fill(Color.black.opacity(0.05))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }

    private var navTitleFont: Font {
        if UIFont(name: "DM Serif Display", size: 17) != nil {
            return .custom("DM Serif Display", size: 17)
        }
        return .custom("Georgia", size: 17)
    }
}
