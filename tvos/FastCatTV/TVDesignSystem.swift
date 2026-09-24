import SwiftUI
import UIKit

enum TVTheme {
  static let preferenceKey = "fastcat.tv.prefers-dark-theme"
  static let background = dynamicColor(
    light: UIColor(red: 0.98, green: 0.984, blue: 0.992, alpha: 1),
    dark: UIColor(red: 0.025, green: 0.055, blue: 0.105, alpha: 1)
  )
  static let surface = dynamicColor(
    light: .white,
    dark: UIColor(white: 1, alpha: 0.075)
  )
  static let surfaceStrong = dynamicColor(
    light: UIColor(red: 0.93, green: 0.945, blue: 0.975, alpha: 1),
    dark: UIColor(white: 1, alpha: 0.12)
  )
  static let stroke = dynamicColor(
    light: UIColor(white: 0, alpha: 0.10),
    dark: UIColor(white: 1, alpha: 0.13)
  )
  static let primary = Color(red: 0.27, green: 0.50, blue: 0.96)
  static let primaryBright = dynamicColor(
    light: UIColor(red: 0.16, green: 0.38, blue: 0.86, alpha: 1),
    dark: UIColor(red: 0.36, green: 0.66, blue: 1.0, alpha: 1)
  )
  static let focusRing = Color(red: 0.27, green: 0.78, blue: 1.0)
  static let success = Color(red: 0.25, green: 0.84, blue: 0.55)
  static let danger = Color(red: 0.90, green: 0.24, blue: 0.24)
  static let textPrimary = Color.primary
  static let textSecondary = Color.secondary
  static let onPrimary = Color.white
  static let cardRadius: CGFloat = 26

  private static func dynamicColor(light: UIColor, dark: UIColor) -> Color {
    Color(uiColor: UIColor { traits in
      traits.userInterfaceStyle == .dark ? dark : light
    })
  }
}

private struct TVBareButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .opacity(configuration.isPressed ? 0.82 : 1)
  }
}

struct TVFocusButton<Label: View>: View {
  let action: () -> Void
  let cornerRadius: CGFloat
  let autofocus: Bool
  @ViewBuilder let label: (Bool) -> Label

  @FocusState private var focused: Bool

  init(
    cornerRadius: CGFloat = TVTheme.cardRadius,
    autofocus: Bool = false,
    action: @escaping () -> Void,
    @ViewBuilder label: @escaping (Bool) -> Label
  ) {
    self.action = action
    self.cornerRadius = cornerRadius
    self.autofocus = autofocus
    self.label = label
  }

  var body: some View {
    Button(action: action) { label(focused) }
      .buttonStyle(TVBareButtonStyle())
      .focused($focused)
      .overlay {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .strokeBorder(focused ? TVTheme.focusRing : .clear, lineWidth: 3)
      }
      .animation(.easeOut(duration: 0.16), value: focused)
      .onAppear {
        if autofocus { focused = true }
      }
      .focusEffectDisabled()
  }
}

struct TVGlassCard<Content: View>: View {
  @ViewBuilder let content: () -> Content

  var body: some View {
    content()
      .background(TVTheme.surface)
      .clipShape(RoundedRectangle(cornerRadius: TVTheme.cardRadius, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: TVTheme.cardRadius, style: .continuous)
          .stroke(TVTheme.stroke, lineWidth: 1)
      }
  }
}
