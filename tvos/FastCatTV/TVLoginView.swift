import CoreImage.CIFilterBuiltins
import SwiftUI

private enum TVLoginMethod { case qr, account }
private enum TVAuthScreen { case login, register, forgotPassword }

struct TVLoginView: View {
  @EnvironmentObject private var session: SessionStore
  @AppStorage(TVTheme.preferenceKey) private var prefersDarkTheme = true
  @AppStorage(TVLanguage.preferenceKey) private var language = TVLanguage.system.rawValue
  @AppStorage("fastcat.tv.remember-password") private var rememberPassword = false

  @State private var screen: TVAuthScreen = .login
  @State private var loginMethod: TVLoginMethod = .qr
  @State private var challenge: QRLoginChallenge?
  @State private var remainingSeconds = 0
  @State private var isLoading = false
  @State private var errorMessage: String?
  @State private var successMessage: String?
  @State private var pollTask: Task<Void, Never>?
  @State private var countdownTask: Task<Void, Never>?
  @State private var lastQRRefreshAt: Date?
  @State private var showLanguagePicker = false
  @State private var guestConfig = TVGuestConfig(requiresEmailVerification: false, requiresInviteCode: false)

  @State private var email = ""
  @State private var password = ""
  @State private var confirmPassword = ""
  @State private var emailCode = ""
  @State private var inviteCode = ""
  @State private var isSendingCode = false
  @FocusState private var languageButtonFocused: Bool
  @FocusState private var themeButtonFocused: Bool
  @FocusState private var qrFocused: Bool
  @FocusState private var loginMethodFocused: Bool
  @FocusState private var systemLanguageFocused: Bool
  @FocusState private var chineseLanguageFocused: Bool
  @FocusState private var englishLanguageFocused: Bool

  private var isChinese: Bool { TVLanguage.resolved(from: language) == .simplifiedChinese }
  private var qrExpired: Bool { challenge != nil && remainingSeconds <= 0 }

  var body: some View {
    TVDesignCanvas {
      ZStack {
        TVTheme.background
        Group {
          VStack(spacing: tv(0)) {
            if screen == .login {
              toolbar
              loginScreen.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
              credentialScreen(isReset: screen == .forgotPassword)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
          }
        }
        .disabled(showLanguagePicker)
        .allowsHitTesting(!showLanguagePicker)
        if showLanguagePicker { languagePicker.zIndex(1) }
      }
    }
    .task {
      restoreSavedCredentials()
      if challenge == nil { await refreshChallenge(userInitiated: false) }
      await loadGuestConfig()
    }
    .onDisappear {
      pollTask?.cancel()
      countdownTask?.cancel()
      if let challenge, !qrExpired {
        Task { try? await GatewayClient.configured().cancelQRSession(challenge) }
      }
    }
    .onExitCommand {
      if showLanguagePicker {
        showLanguagePicker = false
      } else if screen != .login {
        screen = .login
      }
    }
    .onChange(of: loginMethodFocused) { _, focused in
      if focused { qrFocused = false }
    }
    .onChange(of: qrFocused) { _, focused in
      if focused { loginMethodFocused = false }
    }
    .onChange(of: showLanguagePicker) { _, presented in
      if presented {
        focusLanguageOption(TVLanguage(rawValue: language) ?? .system)
      } else {
        clearLanguageOptionFocus()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
          languageButtonFocused = true
        }
      }
    }
  }

  private var toolbar: some View {
    HStack {
      TVToolbarButton(
        title: tvText("语言", "Language", language: language),
        icon: .languageOutlined,
        focus: $languageButtonFocused,
        action: { showLanguagePicker = true }
      )
      .onMoveCommand { direction in
        if direction == .right { themeButtonFocused = true }
        if direction == .down { loginMethodFocused = true }
      }
      Spacer()
      TVToolbarButton(
        title: tvText("切换主题", "Switch Theme", language: language),
        icon: prefersDarkTheme ? .lightModeOutlined : .darkModeOutlined,
        focus: $themeButtonFocused,
        action: { prefersDarkTheme.toggle() }
      )
      .onMoveCommand { direction in
        if direction == .left { languageButtonFocused = true }
        if direction == .down { loginMethodFocused = true }
      }
    }
    .padding(.horizontal, tv(20))
    .frame(height: tv(56))
  }

  private var loginScreen: some View {
    VStack(spacing: tv(0)) {
      brandHeader
      Spacer().frame(height: tv(16))
      loginMethodSelector
      Spacer().frame(height: tv(10))
      if loginMethod == .qr { qrLoginCard } else { accountLoginCard }
    }
    .padding(.top, tv(2))
    .padding(.bottom, tv(10))
  }

  private var brandHeader: some View {
    VStack(spacing: tv(8)) {
      ZStack {
        Circle().fill(TVTheme.primary.opacity(0.10))
        TVBrandLogo()
          .frame(width: tv(64), height: tv(64))
          .clipShape(RoundedRectangle(cornerRadius: tv(14), style: .continuous))
      }
      .frame(width: tv(80), height: tv(80))
      Text(tvText("快猫", "FastCat", language: language))
        .font(TVFont.medium(28))
        .foregroundStyle(TVTheme.textPrimary)
        .frame(height: tv(36))
    }
  }

  private var loginMethodSelector: some View {
    TVFocusButton(cornerRadius: TVTheme.controlRadius, autofocus: true, focus: $loginMethodFocused, action: {
      setLoginMethod(loginMethod == .qr ? .account : .qr)
    }) { _ in
      HStack(spacing: tv(0)) {
        methodSegment(.qr, title: tvText("扫码登录", "QR Sign In", language: language), icon: .qrCodeOutlined)
        methodSegment(.account, title: tvText("账号登录", "Account Sign In", language: language), icon: .passwordOutlined)
      }
      .frame(width: tv(332), height: tv(40))
      .background(Color.clear)
      .clipShape(RoundedRectangle(cornerRadius: TVTheme.controlRadius, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: TVTheme.controlRadius, style: .continuous)
          .strokeBorder(TVTheme.outlineVariant, lineWidth: tv(1))
      }
    }
    .onMoveCommand { direction in
      if direction == .left { setLoginMethod(.qr) }
      if direction == .right { setLoginMethod(.account) }
      if direction == .up {
        if loginMethod == .qr { languageButtonFocused = true }
        else { themeButtonFocused = true }
      }
    }
  }

  private func methodSegment(_ method: TVLoginMethod, title: String, icon: MaterialGlyph) -> some View {
    HStack(spacing: tv(8)) {
      MaterialIcon(glyph: icon, size: 18, color: loginMethod == method ? TVTheme.onPrimaryContainer : TVTheme.textPrimary)
      Text(title).font(TVFont.medium(14))
    }
    .foregroundStyle(loginMethod == method ? TVTheme.onPrimaryContainer : TVTheme.textPrimary)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(loginMethod == method ? TVTheme.primaryContainer : Color.clear)
    .clipShape(RoundedRectangle(cornerRadius: TVTheme.controlRadius, style: .continuous))
  }

  private func setLoginMethod(_ method: TVLoginMethod) {
    guard loginMethod != method else { return }
    loginMethod = method
    errorMessage = nil
    successMessage = nil
    if method == .qr {
      if let challenge, !qrExpired { beginPolling(challenge) }
      else { Task { await refreshChallenge(userInitiated: false) } }
    } else {
      pollTask?.cancel()
    }
  }

  private var qrLoginCard: some View {
    TVGlassCard(cornerRadius: tv(16), showsShadow: false) {
      VStack(spacing: tv(0)) {
        Text(tvText("扫码登录", "QR Sign In", language: language))
          .font(TVFont.medium(16))
        Spacer().frame(height: tv(4))
        Text(tvText("使用已登录快猫的手机扫描并确认", "Scan and confirm with a signed-in FastCat phone", language: language))
          .font(TVFont.regular(12))
          .foregroundStyle(TVTheme.textSecondary)
        Spacer().frame(height: tv(12))
        qrFocusArea
        Spacer().frame(height: tv(8))
        Text(qrStatusText)
          .font(qrExpired ? TVFont.medium(12) : TVFont.regular(12))
          .foregroundStyle(qrExpired ? TVTheme.error : TVTheme.textSecondary)
          .frame(height: tv(16))
      }
      .frame(maxWidth: .infinity, minHeight: tv(240))
      .padding(tv(12))
    }
    .frame(width: tv(332))
    .overlay { RoundedRectangle(cornerRadius: tv(16), style: .continuous).strokeBorder(TVTheme.outlineVariant, lineWidth: tv(1)) }
  }

  private var qrFocusArea: some View {
    TVFocusButton(cornerRadius: TVTheme.controlRadius, focus: $qrFocused, action: {
      Task { await refreshChallenge(userInitiated: true) }
    }) { _ in
      ZStack {
        RoundedRectangle(cornerRadius: TVTheme.controlRadius, style: .continuous).fill(.white)
        if let challenge {
          QRCodeView(payload: challenge.qrData)
        } else if !isLoading {
          VStack(spacing: tv(6)) {
            MaterialIcon(glyph: .wifiOff, size: 18, color: Color.gray)
            Text(tvText("二维码不可用", "QR code unavailable", language: language))
          }
          .font(TVFont.medium(12))
          .foregroundStyle(Color.gray)
        }
        if qrExpired {
          RoundedRectangle(cornerRadius: TVTheme.controlRadius, style: .continuous)
            .fill(Color.black.opacity(0.52))
          HStack(spacing: tv(7)) {
            MaterialIcon(glyph: .refresh, size: 18, color: TVTheme.onPrimary)
            Text(tvText("刷新二维码", "Refresh QR Code", language: language)).font(TVFont.regular(14))
          }
          .padding(.horizontal, tv(14))
          .frame(height: tv(40))
          .background(TVTheme.primary)
          .clipShape(RoundedRectangle(cornerRadius: tv(10), style: .continuous))
          .foregroundStyle(.white)
        }
        if isLoading {
          RoundedRectangle(cornerRadius: TVTheme.controlRadius, style: .continuous)
            .fill(Color.black.opacity(0.40))
          ProgressView().tint(.white).controlSize(.large)
        }
      }
      .frame(width: tv(160), height: tv(160))
      .clipShape(RoundedRectangle(cornerRadius: TVTheme.controlRadius, style: .continuous))
    }
    .disabled(isLoading)
  }

  private var qrStatusText: String {
    if isLoading { return tvText("正在生成二维码…", "Generating QR code…", language: language) }
    if let errorMessage { return errorMessage }
    if challenge == nil { return tvText("按确认键刷新二维码", "Press Select to refresh the QR code", language: language) }
    if qrExpired { return tvText("二维码已过期", "QR code expired", language: language) }
    let minutes = remainingSeconds / 60
    let seconds = remainingSeconds % 60
    let value = String(format: "%02d:%02d", minutes, seconds)
    return tvText("\(value)秒后过期", "Expires in \(value)", language: language)
  }

  private var accountLoginCard: some View {
    VStack(alignment: .leading, spacing: tv(0)) {
        Spacer().frame(height: tv(16))
        compactTextField(tvText("邮箱", "Email", language: language), text: $email, secure: false, icon: .emailOutlined)
        Spacer().frame(height: tv(12))
        compactTextField(tvText("密码", "Password", language: language), text: $password, secure: true)
        Spacer().frame(height: tv(12))
        HStack {
          TVFocusButton(cornerRadius: tv(8), action: { rememberPassword.toggle() }) { _ in
            HStack(spacing: tv(8)) {
              MaterialIcon(glyph: rememberPassword ? .checkBox : .checkBoxOutlineBlank, size: 24, color: rememberPassword ? TVTheme.primary : TVTheme.textSecondary)
              Text(tvText("记住密码", "Remember password", language: language))
            }
            .font(TVFont.regular(14))
            .foregroundStyle(TVTheme.textSecondary)
            .frame(height: tv(32))
          }
          Spacer()
          textAction(tvText("忘记密码", "Forgot password", language: language)) { open(.forgotPassword) }
        }
        .padding(.horizontal, tv(12))
        Spacer().frame(height: tv(16))
        statusMessages
        primaryButton(title: tvText("登录", "Sign In", language: language), loadingTitle: tvText("正在登录…", "Signing in…", language: language), action: loginWithAccount)
        Spacer().frame(height: tv(9))
        HStack(spacing: tv(4)) {
          Text(tvText("还没有账号？", "No account?", language: language))
            .foregroundStyle(TVTheme.textSecondary)
          textAction(tvText("注册", "Register", language: language)) { open(.register) }
        }
        .font(TVFont.regular(14))
        .frame(maxWidth: .infinity)
    }
    .frame(width: tv(332))
  }

  private func credentialScreen(isReset: Bool) -> some View {
    VStack(spacing: tv(0)) {
      HStack(spacing: tv(12)) {
        TVFocusButton(cornerRadius: TVTheme.controlRadius, autofocus: true, action: { open(.login) }) { _ in
          MaterialIcon(glyph: .arrowBack, size: 24, color: TVTheme.textPrimary)
            .frame(width: tv(48), height: tv(48))
            .background(TVTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: TVTheme.controlRadius, style: .continuous))
        }
        Text(isReset ? tvText("找回密码", "Reset Password", language: language) : tvText("创建账号", "Create Account", language: language))
          .font(TVFont.medium(22))
        Spacer()
      }
      .padding(tv(10))

      ScrollView {
        VStack(alignment: .leading, spacing: tv(0)) {
          Text(isReset ? tvText("输入邮箱以重置密码", "Enter your email to reset your password", language: language) : tvText("填写以下信息以创建账号", "Fill in the information below to create an account", language: language))
            .font(TVFont.regular(14)).foregroundStyle(TVTheme.textSecondary)
          Spacer().frame(height: tv(14))
          compactTextField(tvText("邮箱", "Email", language: language), text: $email, secure: false, icon: .emailOutlined)
          if guestConfig.requiresEmailVerification || isReset {
            Spacer().frame(height: tv(9))
            HStack(spacing: tv(8)) {
              compactTextField(tvText("邮箱验证码", "Email code", language: language), text: $emailCode, secure: false, icon: .verifiedUserOutlined)
              TVFocusButton(cornerRadius: TVTheme.controlRadius, action: sendVerificationCode) { _ in
                Text(isSendingCode ? tvText("发送中…", "Sending…", language: language) : tvText("发送验证码", "Send Code", language: language))
                  .font(TVFont.medium(11))
                  .foregroundStyle(TVTheme.primary)
                  .frame(width: tv(90), height: tv(44))
                  .background(TVTheme.primary.opacity(0.10))
                  .clipShape(RoundedRectangle(cornerRadius: TVTheme.controlRadius, style: .continuous))
              }
              .disabled(isSendingCode)
            }
          }
          Spacer().frame(height: tv(9))
          compactTextField(isReset ? tvText("新密码", "New password", language: language) : tvText("密码", "Password", language: language), text: $password, secure: true)
          Spacer().frame(height: tv(9))
          compactTextField(tvText("确认密码", "Confirm password", language: language), text: $confirmPassword, secure: true)
          if !isReset && guestConfig.requiresInviteCode {
            Spacer().frame(height: tv(9))
            compactTextField(tvText("邀请码", "Invite code", language: language), text: $inviteCode, secure: false, icon: .personAddOutlined)
          }
          Spacer().frame(height: tv(12))
          statusMessages
          primaryButton(
            title: isReset ? tvText("重置密码", "Reset Password", language: language) : tvText("注册", "Register", language: language),
            loadingTitle: tvText("请稍候…", "Please wait…", language: language),
            action: { submitCredentialScreen(isReset: isReset) }
          )
          Spacer().frame(height: tv(9))
          textAction(tvText("返回登录", "Back to Sign In", language: language)) { open(.login) }
        }
        .frame(width: tv(332))
      }
      .frame(maxWidth: .infinity)
    }
  }

  private func compactTextField(_ title: String, text: Binding<String>, secure: Bool, icon: MaterialGlyph? = nil) -> some View {
    HStack(spacing: tv(10)) {
      MaterialIcon(glyph: icon ?? (secure ? .lockOutlined : .emailOutlined), size: 20, color: TVTheme.textSecondary)
      Group {
        if secure { SecureField(title, text: text) } else { TextField(title, text: text) }
      }
      .textFieldStyle(.plain)
      .focusEffectDisabled()
    }
    .font(TVFont.regular(14))
    .textInputAutocapitalization(.never)
    .padding(.horizontal, tv(14))
    .frame(height: tv(44))
    .background(TVTheme.inputFill)
    .clipShape(RoundedRectangle(cornerRadius: TVTheme.controlRadius, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: TVTheme.controlRadius, style: .continuous)
        .strokeBorder(TVTheme.inputBorder, lineWidth: tv(1))
    }
  }

  private var statusMessages: some View {
    Group {
      if let errorMessage {
        Text(errorMessage).foregroundStyle(TVTheme.warning)
      } else if let successMessage {
        Text(successMessage).foregroundStyle(TVTheme.success)
      }
    }
    .font(TVFont.medium(11))
    .lineLimit(2)
  }

  private func primaryButton(title: String, loadingTitle: String, action: @escaping () -> Void) -> some View {
    TVFocusButton(cornerRadius: TVTheme.controlRadius, action: action) { _ in
      HStack(spacing: tv(7)) {
        if isLoading { ProgressView().controlSize(.small).tint(.white) }
        Text(isLoading ? loadingTitle : title)
      }
      .font(TVFont.medium(15))
      .foregroundStyle(TVTheme.onPrimary)
      .frame(maxWidth: .infinity, minHeight: tv(44))
      .background(TVTheme.primary)
      .clipShape(RoundedRectangle(cornerRadius: TVTheme.controlRadius, style: .continuous))
    }
    .disabled(isLoading)
  }

  private func textAction(_ title: String, action: @escaping () -> Void) -> some View {
    TVFocusButton(cornerRadius: tv(7), action: action) { focused in
      Text(title)
        .font(TVFont.medium(14))
        .foregroundStyle(TVTheme.primary)
        .padding(.horizontal, tv(5)).padding(.vertical, tv(4))
        .background(Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: tv(7), style: .continuous))
    }
  }

  private var languagePicker: some View {
    TVDialog(title: tvText("选择语言", "Choose Language", language: language), icon: .language) {
      VStack(spacing: tv(8)) {
        ForEach(TVLanguage.allCases, id: \.self) { item in
          TVFocusButton(cornerRadius: TVTheme.controlRadius, focus: languageFocusBinding(for: item), action: {
            language = item.rawValue
            showLanguagePicker = false
          }) { focused in
            HStack {
              Text(item.displayName)
              Spacer()
              if language == item.rawValue { MaterialIcon(glyph: .checkCircle, size: 20, color: TVTheme.primary) }
            }
            .font(TVFont.medium(15))
            .foregroundStyle(TVTheme.textPrimary)
            .padding(.horizontal, tv(14))
            .frame(height: tv(44))
            .background(TVTheme.surfaceStrong)
            .clipShape(RoundedRectangle(cornerRadius: TVTheme.controlRadius, style: .continuous))
          }
          .onMoveCommand { direction in
            moveLanguageFocus(from: item, direction: direction)
          }
        }
      }
    } actions: {
      EmptyView()
    }
  }

  private func languageFocusBinding(for item: TVLanguage) -> FocusState<Bool>.Binding {
    switch item {
    case .system: return $systemLanguageFocused
    case .simplifiedChinese: return $chineseLanguageFocused
    case .english: return $englishLanguageFocused
    }
  }

  private func focusLanguageOption(_ item: TVLanguage) {
    clearLanguageOptionFocus()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
      switch item {
      case .system: systemLanguageFocused = true
      case .simplifiedChinese: chineseLanguageFocused = true
      case .english: englishLanguageFocused = true
      }
    }
  }

  private func clearLanguageOptionFocus() {
    systemLanguageFocused = false
    chineseLanguageFocused = false
    englishLanguageFocused = false
  }

  private func moveLanguageFocus(from item: TVLanguage, direction: MoveCommandDirection) {
    let items = TVLanguage.allCases
    guard let index = items.firstIndex(of: item) else { return }
    if direction == .down, index < items.count - 1 {
      focusLanguageOption(items[index + 1])
    } else if direction == .up, index > 0 {
      focusLanguageOption(items[index - 1])
    }
  }

  private func open(_ destination: TVAuthScreen) {
    screen = destination
    errorMessage = nil
    successMessage = nil
    password = ""
    confirmPassword = ""
    emailCode = ""
    inviteCode = ""
    if destination == .login, loginMethod == .qr, let challenge, !qrExpired { beginPolling(challenge) }
    else { pollTask?.cancel() }
  }

  @MainActor
  private func refreshChallenge(userInitiated: Bool) async {
    guard !isLoading else { return }
    if userInitiated, let lastQRRefreshAt,
       Date().timeIntervalSince(lastQRRefreshAt) < 5, !qrExpired { return }
    isLoading = true
    errorMessage = nil
    successMessage = nil
    pollTask?.cancel()
    countdownTask?.cancel()
    let previous = challenge
    do {
      let client = try await GatewayClient.configured()
      if let previous, previous.expiresAt > Date() {
        try await client.cancelQRSession(previous)
      }
      let next = try await client.createQRSession()
      challenge = next
      lastQRRefreshAt = Date()
      updateRemainingTime(for: next)
      beginCountdown(next)
      beginPolling(next)
      qrFocused = true
    } catch {
      errorMessage = error.localizedDescription
      if let previous { updateRemainingTime(for: previous) }
    }
    isLoading = false
  }

  private func beginCountdown(_ challenge: QRLoginChallenge) {
    countdownTask?.cancel()
    countdownTask = Task {
      while !Task.isCancelled {
        await MainActor.run { updateRemainingTime(for: challenge) }
        if challenge.expiresAt <= Date() {
          pollTask?.cancel()
          return
        }
        try? await Task.sleep(for: .seconds(1))
      }
    }
  }

  @MainActor
  private func updateRemainingTime(for challenge: QRLoginChallenge) {
    remainingSeconds = max(0, Int(ceil(challenge.expiresAt.timeIntervalSinceNow)))
  }

  private func beginPolling(_ challenge: QRLoginChallenge) {
    pollTask?.cancel()
    guard challenge.expiresAt > Date(), loginMethod == .qr, screen == .login else { return }
    pollTask = Task {
      while !Task.isCancelled, challenge.expiresAt > Date() {
        do {
          let client = try await GatewayClient.configured()
          let status = try await client.pollQRSession(challenge)
          if status.status == "expired" {
            await MainActor.run { remainingSeconds = 0 }
            return
          }
          if status.status == "approved", let login = status.login,
             let token = login.authData ?? login.token, !token.isEmpty {
            await MainActor.run { session.signIn(token: token, email: login.email) }
            return
          }
        } catch {
          await MainActor.run { errorMessage = error.localizedDescription }
          return
        }
        try? await Task.sleep(for: .seconds(2))
      }
    }
  }

  private func loginWithAccount() {
    let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalizedEmail.isEmpty, !password.isEmpty else {
      errorMessage = tvText("请输入邮箱和密码", "Enter your email and password", language: language)
      return
    }
    isLoading = true
    errorMessage = nil
    Task {
      do {
        let client = try await GatewayClient.configured()
        let result = try await client.login(email: normalizedEmail, password: password)
        guard let token = result.authData ?? result.token, !token.isEmpty else {
          throw GatewayClient.GatewayError.server(tvText("登录失败，请重试", "Sign in failed. Try again.", language: language))
        }
        if rememberPassword {
          KeychainStore.write(normalizedEmail, key: "saved-login-email")
          KeychainStore.write(password, key: "saved-login-password")
        } else {
          KeychainStore.delete(key: "saved-login-email")
          KeychainStore.delete(key: "saved-login-password")
        }
        await MainActor.run {
          isLoading = false
          session.signIn(token: token, email: result.email ?? normalizedEmail)
        }
      } catch {
        await MainActor.run { isLoading = false; errorMessage = error.localizedDescription }
      }
    }
  }

  private func sendVerificationCode() {
    let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
    guard normalizedEmail.contains("@") else {
      errorMessage = tvText("请输入有效邮箱", "Enter a valid email", language: language)
      return
    }
    isSendingCode = true
    errorMessage = nil
    Task {
      do {
        try await GatewayClient.configured().sendEmailVerification(to: normalizedEmail)
        await MainActor.run {
          isSendingCode = false
          successMessage = tvText("验证码已发送", "Verification code sent", language: language)
        }
      } catch {
        await MainActor.run { isSendingCode = false; errorMessage = error.localizedDescription }
      }
    }
  }

  private func submitCredentialScreen(isReset: Bool) {
    let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
    guard normalizedEmail.contains("@"), !password.isEmpty, password == confirmPassword else {
      errorMessage = tvText("请检查邮箱，两次输入的密码需一致", "Check the email and make sure both passwords match", language: language)
      return
    }
    if (guestConfig.requiresEmailVerification || isReset) && emailCode.isEmpty {
      errorMessage = tvText("请输入邮箱验证码", "Enter the email verification code", language: language)
      return
    }
    if !isReset && guestConfig.requiresInviteCode && inviteCode.isEmpty {
      errorMessage = tvText("请输入邀请码", "Enter an invite code", language: language)
      return
    }
    isLoading = true
    errorMessage = nil
    Task {
      do {
        let client = try await GatewayClient.configured()
        if isReset {
          try await client.resetPassword(email: normalizedEmail, password: password, emailCode: emailCode)
        } else {
          try await client.register(
            email: normalizedEmail,
            password: password,
            emailCode: guestConfig.requiresEmailVerification ? emailCode : nil,
            inviteCode: guestConfig.requiresInviteCode ? inviteCode : nil
          )
        }
        await MainActor.run {
          isLoading = false
          successMessage = isReset
            ? tvText("密码已重置，请返回登录", "Password reset. Return to sign in.", language: language)
            : tvText("注册成功，请返回登录", "Account created. Return to sign in.", language: language)
        }
      } catch {
        await MainActor.run { isLoading = false; errorMessage = error.localizedDescription }
      }
    }
  }

  @MainActor
  private func loadGuestConfig() async {
    do { guestConfig = try await GatewayClient.configured().fetchGuestConfig() }
    catch { guestConfig = TVGuestConfig(requiresEmailVerification: false, requiresInviteCode: false) }
  }

  private func restoreSavedCredentials() {
    guard rememberPassword else { return }
    email = KeychainStore.read(key: "saved-login-email") ?? ""
    password = KeychainStore.read(key: "saved-login-password") ?? ""
  }
}

private struct QRCodeView: View {
  let payload: String
  private let context = CIContext()
  private let filter = CIFilter.qrCodeGenerator()

  var body: some View {
    if let image = makeImage() {
      Image(uiImage: image).interpolation(.none).resizable().scaledToFit()
    }
  }

  private func makeImage() -> UIImage? {
    filter.message = Data(payload.utf8)
    filter.correctionLevel = "M"
    guard let output = filter.outputImage?.transformed(by: .init(scaleX: 12, y: 12)),
          let cgImage = context.createCGImage(output, from: output.extent) else { return nil }
    return UIImage(cgImage: cgImage)
  }
}
