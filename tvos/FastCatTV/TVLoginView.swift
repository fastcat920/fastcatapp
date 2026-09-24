import CoreImage.CIFilterBuiltins
import SwiftUI

private enum TVLoginMethod {
  case qr
  case account
}

struct TVLoginView: View {
  @EnvironmentObject private var session: SessionStore
  @State private var loginMethod: TVLoginMethod = .qr
  @State private var challenge: QRLoginChallenge?
  @State private var isLoading = false
  @State private var errorMessage: String?
  @State private var pollTask: Task<Void, Never>?
  @State private var email = ""
  @State private var password = ""

  var body: some View {
    ZStack {
      TVTheme.background.ignoresSafeArea()
      VStack(spacing: 26) {
        HStack(spacing: 16) {
          ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(TVTheme.primary)
            Image(systemName: "bolt.shield.fill")
              .font(.system(size: 27, weight: .semibold))
              .foregroundStyle(TVTheme.onPrimary)
          }
          .frame(width: 56, height: 56)
          Text("快猫").font(.system(size: 32, weight: .bold))
          Spacer()
        }
        .frame(maxWidth: 1180)

        HStack(spacing: 10) {
          loginMethodButton(.qr, title: "扫码登录", icon: "qrcode")
          loginMethodButton(.account, title: "账号登录", icon: "person.crop.circle")
        }
        .frame(width: 620)

        TVGlassCard {
          Group {
            if loginMethod == .qr {
              qrLoginContent
            } else {
              accountLoginContent
            }
          }
          .padding(28)
        }
        .frame(width: 620)
      }
      .padding(.horizontal, 72)
      .padding(.vertical, 44)
    }
    .task { loadChallenge() }
    .onDisappear { pollTask?.cancel() }
  }

  private func loginMethodButton(_ method: TVLoginMethod, title: String, icon: String) -> some View {
    TVFocusButton(cornerRadius: 16, action: {
      loginMethod = method
      errorMessage = nil
      if method == .qr, challenge == nil {
        loadChallenge()
      } else if method == .account {
        pollTask?.cancel()
      }
    }) { focused in
      Label(title, systemImage: icon)
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(loginMethod == method ? TVTheme.onPrimary : TVTheme.textPrimary)
        .frame(maxWidth: .infinity, minHeight: 58)
        .background(loginMethod == method ? TVTheme.primary : focused ? TVTheme.surfaceStrong : TVTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
  }

  private var qrLoginContent: some View {
    VStack(spacing: 18) {
      Text("扫码登录").font(.system(size: 24, weight: .bold))
      Text("使用已登录快猫的手机扫描并确认")
        .font(.system(size: 16)).foregroundStyle(TVTheme.textSecondary)
      Group {
        if let challenge {
          QRCodeView(payload: challenge.qrData)
            .frame(width: 300, height: 300)
            .padding(20).background(.white, in: RoundedRectangle(cornerRadius: 22))
        } else if isLoading {
          ProgressView("正在生成二维码…").frame(width: 340, height: 340)
        } else {
          ContentUnavailableView(
            "二维码不可用",
            systemImage: "wifi.exclamationmark",
            description: Text(errorMessage ?? "请检查网络后重新尝试")
          )
          .frame(width: 340, height: 340)
        }
      }
      TVFocusButton(cornerRadius: 15, action: loadChallenge) { focused in
        Label(isLoading ? "正在刷新…" : "刷新二维码", systemImage: "arrow.clockwise")
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(focused ? TVTheme.onPrimary : TVTheme.primaryBright)
          .padding(.horizontal, 22)
          .frame(height: 52)
          .background(focused ? TVTheme.primary : TVTheme.surfaceStrong)
          .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
      }
      .disabled(isLoading)
      Text("请在手机快猫中选择“扫一扫”，扫描此二维码完成登录")
        .foregroundStyle(TVTheme.textSecondary).font(.system(size: 14))
    }
  }

  private var accountLoginContent: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text("账号登录").font(.system(size: 24, weight: .bold))
      Text("使用快猫账号和密码登录 Apple TV")
        .font(.system(size: 16)).foregroundStyle(TVTheme.textSecondary)
      TextField("邮箱", text: $email)
        .textContentType(.emailAddress)
        .textInputAutocapitalization(.never)
        .padding(.horizontal, 20)
        .frame(height: 64)
        .background(TVTheme.surfaceStrong)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      SecureField("密码", text: $password)
        .textContentType(.password)
        .padding(.horizontal, 20)
        .frame(height: 64)
        .background(TVTheme.surfaceStrong)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      if let errorMessage {
        Text(errorMessage).font(.system(size: 14, weight: .medium)).foregroundStyle(Color.orange)
      }
      TVFocusButton(cornerRadius: 16, action: loginWithAccount) { focused in
        HStack(spacing: 10) {
          if isLoading { ProgressView().controlSize(.small).tint(TVTheme.onPrimary) }
          Text(isLoading ? "正在登录…" : "登录")
        }
        .font(.system(size: 18, weight: .bold))
        .foregroundStyle(TVTheme.onPrimary)
        .frame(maxWidth: .infinity, minHeight: 60)
        .background(focused ? TVTheme.primaryBright : TVTheme.primary)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      }
      .disabled(isLoading || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)
    }
  }

  private func loadChallenge() {
    pollTask?.cancel()
    challenge = nil; isLoading = true; errorMessage = nil
    Task {
      do {
        let client = try await GatewayClient.configured()
        let next = try await client.createQRSession()
        guard !Task.isCancelled else { return }
        challenge = next; isLoading = false
        beginPolling(next)
      } catch {
        isLoading = false; errorMessage = error.localizedDescription
      }
    }
  }

  private func beginPolling(_ challenge: QRLoginChallenge) {
    pollTask = Task {
      while !Task.isCancelled {
        do {
          let client = try await GatewayClient.configured()
          let status = try await client.pollQRSession(challenge)
          if status.status == "approved", let login = status.login,
             let token = login.authData ?? login.token, !token.isEmpty {
            session.signIn(token: token, email: login.email)
            return
          }
        } catch { errorMessage = error.localizedDescription; return }
        try? await Task.sleep(for: .seconds(2))
      }
    }
  }

  private func loginWithAccount() {
    guard !isLoading else { return }
    let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalizedEmail.isEmpty, !password.isEmpty else {
      errorMessage = "请输入邮箱和密码"
      return
    }
    pollTask?.cancel()
    isLoading = true
    errorMessage = nil
    Task {
      do {
        let client = try await GatewayClient.configured()
        let result = try await client.login(email: normalizedEmail, password: password)
        guard let token = result.authData ?? result.token, !token.isEmpty else {
          throw GatewayClient.GatewayError.server("登录失败，请重试")
        }
        session.signIn(token: token, email: result.email ?? normalizedEmail)
        isLoading = false
      } catch {
        isLoading = false
        errorMessage = error.localizedDescription
      }
    }
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
    filter.message = Data(payload.utf8); filter.correctionLevel = "M"
    guard let output = filter.outputImage?.transformed(by: .init(scaleX: 12, y: 12)),
          let cgImage = context.createCGImage(output, from: output.extent) else { return nil }
    return UIImage(cgImage: cgImage)
  }
}
