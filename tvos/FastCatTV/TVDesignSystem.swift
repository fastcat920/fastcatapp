import SwiftUI
import UIKit

enum TVLanguage: String, CaseIterable {
  case system
  case simplifiedChinese = "zh-CN"
  case english = "en"

  static let preferenceKey = "fastcat.tv.language"

  static func resolved(from rawValue: String) -> TVLanguage {
    let selected = TVLanguage(rawValue: rawValue) ?? .system
    guard selected == .system else { return selected }
    return Locale.preferredLanguages.first?.lowercased().hasPrefix("zh") == true
      ? .simplifiedChinese : .english
  }

  var locale: Locale {
    Locale(identifier: self == .simplifiedChinese ? "zh_CN" : "en_US")
  }

  var displayName: String {
    switch self {
    case .system: return "跟随系统 / System"
    case .simplifiedChinese: return "简体中文"
    case .english: return "English"
    }
  }
}

func tvText(_ chinese: String, _ english: String, language: String) -> String {
  TVLanguage.resolved(from: language) == .simplifiedChinese ? chinese : english
}

/// Converts Android TV's 1280×720 design units into native tvOS layout units.
/// Values are aligned to the output pixel grid so text, strokes, and icons are
/// laid out at their final size instead of scaling an already-rendered view.
enum TVLayout {
  static let referenceSize = CGSize(width: 1280, height: 720)

  static var scale: CGFloat {
    let size = UIScreen.main.bounds.size
    guard size.width > 0, size.height > 0 else { return 1 }
    return min(size.width / referenceSize.width, size.height / referenceSize.height)
  }

  static func value(_ designValue: CGFloat) -> CGFloat {
    let outputScale = max(UIScreen.main.scale, 1)
    return (designValue * scale * outputScale).rounded() / outputScale
  }
}

@inline(__always)
func tv(_ designValue: CGFloat) -> CGFloat {
  TVLayout.value(designValue)
}

enum TVTheme {
  static let preferenceKey = "fastcat.tv.prefers-dark-theme"
  static let background = dynamicColor(
    light: hex(0xFAFBFD), dark: hex(0x121318)
  )
  static let surface = dynamicColor(
    light: .white, dark: hex(0x1A1B20)
  )
  static let surfaceStrong = dynamicColor(
    light: hex(0xF0F2F5), dark: hex(0x1E1F25)
  )
  static let surfaceHighest = dynamicColor(light: hex(0xE2E2E9), dark: hex(0x33353A))
  static let inputFill = dynamicColor(light: hex(0xF5F7FA), dark: hex(0x1E1F25))
  static let stroke = dynamicColor(
    light: hex(0xEEF0F4), dark: hex(0x8F9099, alpha: 0.18)
  )
  static let primary = dynamicColor(light: hex(0x475D91), dark: hex(0xB0C6FF))
  static let primaryBright = primary
  static let primaryContainer = dynamicColor(light: hex(0xD9E2FF), dark: hex(0x2E4578))
  static let onPrimaryContainer = dynamicColor(light: hex(0x2E4578), dark: hex(0xD9E2FF))
  static let focusRing = primary
  static let success = dynamicColor(light: hex(0x4CAF50), dark: hex(0x66BB6A))
  static let danger = dynamicColor(light: hex(0xF44336), dark: hex(0xEF5350))
  static let warning = dynamicColor(light: hex(0xFF9800), dark: hex(0xFFB74D))
  static let error = dynamicColor(light: hex(0xBA1A1A), dark: hex(0xFFB4AB))
  static let errorContainer = dynamicColor(light: hex(0xFFDAD6), dark: hex(0x93000A))
  static let textPrimary = dynamicColor(light: hex(0x1A1B20), dark: hex(0xE2E2E9))
  static let textSecondary = dynamicColor(light: hex(0x44464F), dark: hex(0xC5C6D0))
  static let outline = dynamicColor(light: hex(0x757780), dark: hex(0x8F9099))
  static let outlineVariant = dynamicColor(light: hex(0xC5C6D0), dark: hex(0x44464F))
  static let inputBorder = dynamicColor(light: hex(0xEEF0F4), dark: hex(0x8F9099))
  static let onPrimary = dynamicColor(light: .white, dark: hex(0x152E60))
  static let cardRadius: CGFloat = tv(20)
  static let compactRadius: CGFloat = tv(14)
  static let controlRadius: CGFloat = tv(12)
  static let smallRadius: CGFloat = tv(10)
  static let focusWidth: CGFloat = tv(2)

  private static func dynamicColor(light: UIColor, dark: UIColor) -> Color {
    Color(uiColor: UIColor { traits in
      traits.userInterfaceStyle == .dark ? dark : light
    })
  }

  private static func hex(_ value: UInt32, alpha: CGFloat = 1) -> UIColor {
    UIColor(
      red: CGFloat((value >> 16) & 0xff) / 255,
      green: CGFloat((value >> 8) & 0xff) / 255,
      blue: CGFloat(value & 0xff) / 255,
      alpha: alpha
    )
  }
}

enum TVFont {
  /// Matches Android TV's global `TextScaler.linear(1.3)` while keeping
  /// icons, cards, focus rings, and other layout geometry unchanged.
  static let televisionTextScale: CGFloat = 1.3

  static func regular(_ size: CGFloat) -> Font {
    .custom("Roboto-Regular", fixedSize: tv(size * televisionTextScale))
  }

  static func medium(_ size: CGFloat) -> Font {
    .custom("Roboto-Medium", fixedSize: tv(size * televisionTextScale))
  }
}

enum MaterialGlyph: String {
  case altRoute = "\u{e080}"
  case arrowBack = "\u{e092}"
  case campaignOutlined = "\u{ef27}"
  case checkBox = "\u{e157}"
  case checkBoxOutlineBlank = "\u{e158}"
  case checkCircle = "\u{e159}"
  case chevronRight = "\u{e15f}"
  case circleOutlined = "\u{ef53}"
  case darkModeOutlined = "\u{ef9f}"
  case emailOutlined = "\u{f018}"
  case language = "\u{e366}"
  case languageOutlined = "\u{f14f}"
  case hubOutlined = "\u{f0616}"
  case lightModeOutlined = "\u{f162}"
  case lockOutlined = "\u{f197}"
  case logoutOutlined = "\u{f199}"
  case networkCheck = "\u{e424}"
  case passwordOutlined = "\u{f25e}"
  case personAddOutlined = "\u{f278}"
  case personOutline = "\u{e497}"
  case powerSettingsNew = "\u{e4e3}"
  case qrCodeOutlined = "\u{f2d8}"
  case refresh = "\u{e514}"
  case verifiedUserOutlined = "\u{f47d}"
  case wifiOff = "\u{e6eb}"
}

struct MaterialIcon: View {
  let glyph: MaterialGlyph
  let size: CGFloat
  var color: Color = TVTheme.textPrimary

  var body: some View {
    Text(glyph.rawValue)
      .font(.custom("MaterialIcons-Regular", fixedSize: tv(size)))
      .foregroundStyle(color)
      .frame(width: tv(size), height: tv(size))
  }
}

/// Android TV is authored against a 1280×720 canvas. Every descendant uses
/// native, scaled layout values; this container only centers the aspect-fit
/// canvas and never applies a rendering transform.
struct TVDesignCanvas<Content: View>: View {
  @ViewBuilder let content: () -> Content

  var body: some View {
    GeometryReader { geometry in
      let scale = min(geometry.size.width / 1280, geometry.size.height / 720)
      content()
        .frame(width: 1280 * scale, height: 720 * scale)
        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
    }
    .ignoresSafeArea()
  }
}

private struct TVBareButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
  }
}

struct TVFocusButton<Label: View>: View {
  @Environment(\.isEnabled) private var isEnabled
  let action: () -> Void
  let cornerRadius: CGFloat
  let autofocus: Bool
  let externalFocus: FocusState<Bool>.Binding?
  @ViewBuilder let label: (Bool) -> Label

  @FocusState private var focused: Bool

  init(
    cornerRadius: CGFloat = TVTheme.compactRadius,
    autofocus: Bool = false,
    focus: FocusState<Bool>.Binding? = nil,
    action: @escaping () -> Void,
    @ViewBuilder label: @escaping (Bool) -> Label
  ) {
    self.action = action
    self.cornerRadius = cornerRadius
    self.autofocus = autofocus
    self.externalFocus = focus
    self.label = label
  }

  var body: some View {
    let focusBinding = externalFocus ?? $focused
    let isFocused = externalFocus?.wrappedValue ?? focused
    let visuallyFocused = isEnabled && isFocused
    Button(action: action) { label(visuallyFocused) }
      .buttonStyle(TVBareButtonStyle())
      .focused(focusBinding)
      .overlay {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .strokeBorder(visuallyFocused ? TVTheme.focusRing : .clear, lineWidth: TVTheme.focusWidth)
          .allowsHitTesting(false)
      }
      .animation(.easeOut(duration: 0.15), value: visuallyFocused)
      .onAppear {
        if autofocus {
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            if let externalFocus { externalFocus.wrappedValue = true }
            else { focused = true }
          }
        }
      }
      .focusEffectDisabled()
  }
}

struct TVGlassCard<Content: View>: View {
  @Environment(\.colorScheme) private var colorScheme
  let cornerRadius: CGFloat
  let showsShadow: Bool
  @ViewBuilder let content: () -> Content

  init(cornerRadius: CGFloat = TVTheme.cardRadius, showsShadow: Bool = true, @ViewBuilder content: @escaping () -> Content) {
    self.cornerRadius = cornerRadius
    self.showsShadow = showsShadow
    self.content = content
  }

  var body: some View {
    content()
      .background(TVTheme.surface)
      .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .strokeBorder(TVTheme.stroke, lineWidth: tv(1))
      }
      .shadow(color: colorScheme == .dark || !showsShadow ? .clear : Color.black.opacity(0.08), radius: tv(14), x: tv(0), y: tv(4))
  }
}

struct TVToolbarButton: View {
  let title: String
  let icon: MaterialGlyph
  var horizontalPadding: CGFloat = 16
  var cornerRadius: CGFloat = TVTheme.smallRadius
  var height: CGFloat = 40
  var focus: FocusState<Bool>.Binding? = nil
  let action: () -> Void

  var body: some View {
    TVFocusButton(cornerRadius: cornerRadius, focus: focus, action: action) { _ in
      HStack(spacing: tv(8)) {
        MaterialIcon(glyph: icon, size: 20, color: TVTheme.primary)
        Text(title).font(TVFont.medium(14)).foregroundStyle(TVTheme.primary)
      }
      .padding(.horizontal, tv(horizontalPadding))
      .frame(height: tv(height))
      .background(TVTheme.primary.opacity(0.10))
      .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
  }
}

struct TVBrandLogo: View {
  private var image: UIImage? {
    guard let url = Bundle.main.url(forResource: "icon", withExtension: "png") else { return nil }
    return UIImage(contentsOfFile: url.path)
  }

  var body: some View {
    Group {
      if let image {
        Image(uiImage: image).resizable().interpolation(.high).scaledToFit()
      } else {
        MaterialIcon(glyph: .powerSettingsNew, size: 36, color: TVTheme.primary)
      }
    }
  }
}

struct TVDialog<Content: View, Actions: View>: View {
  let title: String
  let icon: MaterialGlyph?
  @ViewBuilder let content: () -> Content
  @ViewBuilder let actions: () -> Actions

  var body: some View {
    ZStack {
      Color.black.opacity(0.54).ignoresSafeArea()
      VStack(spacing: tv(0)) {
        HStack(spacing: tv(9)) {
          if let icon { MaterialIcon(glyph: icon, size: 20, color: TVTheme.primary) }
          Text(title).font(TVFont.medium(16)).foregroundStyle(TVTheme.textPrimary)
          Spacer()
        }
        .padding(tv(16))
        Rectangle().fill(TVTheme.outline.opacity(0.12)).frame(height: tv(1))
        content()
          .font(TVFont.regular(14))
          .foregroundStyle(TVTheme.textSecondary)
          .multilineTextAlignment(.leading)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(tv(16))
        Rectangle().fill(TVTheme.outline.opacity(0.12)).frame(height: tv(1))
        actions()
          .frame(maxWidth: .infinity, alignment: .trailing)
          .padding(.leading, tv(16)).padding(.trailing, tv(16)).padding(.top, tv(12)).padding(.bottom, tv(16))
      }
      .frame(width: tv(560))
      .background(TVTheme.surface)
      .clipShape(RoundedRectangle(cornerRadius: tv(24), style: .continuous))
      .overlay { RoundedRectangle(cornerRadius: tv(24), style: .continuous).strokeBorder(TVTheme.outline.opacity(0.10), lineWidth: tv(1)) }
      .shadow(color: .black.opacity(0.20), radius: tv(20), y: tv(10))
    }
    .transition(.opacity.combined(with: .scale(scale: 0.98)))
  }
}
