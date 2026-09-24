import SwiftUI

enum TVTheme {
  static let background = Color(red: 0.025, green: 0.055, blue: 0.105)
  static let surface = Color.white.opacity(0.075)
  static let surfaceStrong = Color.white.opacity(0.12)
  static let stroke = Color.white.opacity(0.13)
  static let primary = Color(red: 0.27, green: 0.50, blue: 0.96)
  static let primaryBright = Color(red: 0.36, green: 0.66, blue: 1.0)
  static let focusRing = Color(red: 0.27, green: 0.78, blue: 1.0)
  static let success = Color(red: 0.25, green: 0.84, blue: 0.55)
  static let textSecondary = Color.white.opacity(0.62)
  static let cardRadius: CGFloat = 26
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
