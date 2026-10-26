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

    var title: LocalizedStringKey {
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
        light: RGB(0.96, 0.97, 0.99),
        dark: RGB(0.035, 0.055, 0.09)
    )
    static let appSurface = adaptive(
        light: RGB(1.00, 1.00, 1.00, 0.92),
        dark: RGB(0.075, 0.105, 0.16, 0.94)
    )
    static let appElevatedSurface = adaptive(
        light: RGB(0.965, 0.975, 0.995),
        dark: RGB(0.105, 0.14, 0.21)
    )
    static let appBorder = adaptive(
        light: RGB(0.12, 0.22, 0.38, 0.09),
        dark: RGB(0.70, 0.82, 1.00, 0.12)
    )
    static let ink = adaptive(
        light: RGB(0.07, 0.12, 0.22),
        dark: RGB(0.93, 0.96, 1.00)
    )
    static let trip = adaptive(
        light: RGB(0.14, 0.34, 0.92),
        dark: RGB(0.35, 0.58, 1.00)
    )
    static let available = adaptive(
        light: RGB(0.04, 0.58, 0.47),
        dark: RGB(0.24, 0.82, 0.66)
    )
    static let unavailable = adaptive(
        light: RGB(0.68, 0.16, 0.14),
        dark: RGB(0.95, 0.42, 0.38)
    )
    static let lastDay = adaptive(
        light: RGB(0.96, 0.45, 0.12),
        dark: RGB(1.00, 0.65, 0.28)
    )

    static let brandIndigo = Color(red: 0.20, green: 0.29, blue: 0.88)
    static let brandCyan = Color(red: 0.05, green: 0.68, blue: 0.72)

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

extension LinearGradient {
    /// Background of the allowance hero and the trip editor summary.
    static let hero = LinearGradient(
        colors: [Color(red: 0.10, green: 0.16, blue: 0.46), Color(red: 0.08, green: 0.43, blue: 0.48)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension View {
    func sectionSurface() -> some View {
        self
            .padding(18)
            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.appBorder)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 18, y: 8)
    }

    func appBackground() -> some View {
        self.background {
            ZStack {
                Color.appBackground
                RadialGradient(
                    colors: [Color.brandIndigo.opacity(0.13), .clear],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 420
                )
                RadialGradient(
                    colors: [Color.brandCyan.opacity(0.08), .clear],
                    center: .bottomLeading,
                    startRadius: 0,
                    endRadius: 360
                )
            }
            .ignoresSafeArea()
        }
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
