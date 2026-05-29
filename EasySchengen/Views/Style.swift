import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var symbol: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

extension Color {
    static let appBackground = adaptive(
        light: RGB(0.96, 0.97, 0.95),
        dark: RGB(0.06, 0.08, 0.09)
    )
    static let appSurface = adaptive(
        light: RGB(1.00, 1.00, 1.00),
        dark: RGB(0.11, 0.13, 0.15)
    )
    static let appElevatedSurface = adaptive(
        light: RGB(1.00, 1.00, 1.00),
        dark: RGB(0.15, 0.17, 0.19)
    )
    static let appBorder = adaptive(
        light: RGB(0.00, 0.00, 0.00, 0.07),
        dark: RGB(1.00, 1.00, 1.00, 0.10)
    )
    static let ink = adaptive(
        light: RGB(0.10, 0.15, 0.18),
        dark: RGB(0.90, 0.94, 0.96)
    )
    static let trip = adaptive(
        light: RGB(0.00, 0.20, 0.60),
        dark: RGB(0.25, 0.55, 0.90)
    )
    static let available = adaptive(
        light: RGB(0.12, 0.52, 0.39),
        dark: RGB(0.35, 0.78, 0.61)
    )
    static let unavailable = adaptive(
        light: RGB(0.68, 0.16, 0.14),
        dark: RGB(0.95, 0.42, 0.38)
    )
    static let lastDay = adaptive(
        light: RGB(0.88, 0.46, 0.10),
        dark: RGB(1.00, 0.64, 0.24)
    )

    private struct RGB {
        var red: Double
        var green: Double
        var blue: Double
        var alpha: Double

        init(_ red: Double, _ green: Double, _ blue: Double, _ alpha: Double = 1) {
            self.red = red
            self.green = green
            self.blue = blue
            self.alpha = alpha
        }
    }

    private static func adaptive(light: RGB, dark: RGB) -> Color {
        #if os(iOS)
        return Color(uiColor: UIColor { traits in
            let color = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: color.red,
                green: color.green,
                blue: color.blue,
                alpha: color.alpha
            )
        })
        #elseif os(macOS)
        return Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let color = isDark ? dark : light
            return NSColor(
                red: color.red,
                green: color.green,
                blue: color.blue,
                alpha: color.alpha
            )
        })
        #else
        return Color(
            red: light.red,
            green: light.green,
            blue: light.blue,
            opacity: light.alpha
        )
        #endif
    }
}

extension View {
    func sectionSurface() -> some View {
        self
            .padding(16)
            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.appBorder)
            )
    }

    @ViewBuilder
    func inlineNavigationTitleWhenAvailable() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
