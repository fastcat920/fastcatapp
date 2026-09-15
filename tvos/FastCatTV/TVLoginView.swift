import CoreImage.CIFilterBuiltins
import SwiftUI

struct TVLoginView: View {
  @EnvironmentObject private var session: SessionStore
  @State private var challenge: QRLoginChallenge?
  @State private var isLoading = false
  @State private var errorMessage: String?
  @State private var pollTask: Task<Void, Never>?

  var body: some View {
    ZStack {
      LinearGradient(colors: [.blue.opacity(0.35), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
        .ignoresSafeArea()
      VStack(spacing: 28) {
        VStack(spacing: 8) {
          Image(systemName: "bolt.shield.fill").font(.system(size: 64)).foregroundStyle(.white)
          Text("快猫").font(.system(size: 42, weight: .bold))
          Text("使用已登录快猫的手机扫描并确认")
            .font(.title3).foregroundStyle(.secondary)
        }
        Group {
          if let challenge {
            QRCodeView(payload: challenge.qrData)
              .frame(width: 360, height: 360)
              .padding(24).background(.white, in: RoundedRectangle(cornerRadius: 28))
          } else if isLoading {
            ProgressView("正在生成二维码…").frame(width: 360, height: 360)
          } else {
            ContentUnavailableView("二维码不可用", systemImage: "wifi.exclamationmark", description: Text(errorMessage ?? "请检查网络后重新尝试"))
              .frame(width: 360, height: 360)
          }
        }
        Button(action: loadChallenge) {
          Label("刷新二维码", systemImage: "arrow.clockwise")
        }
        .buttonStyle(.borderedProminent)
        .disabled(isLoading)
        Text("请在手机快猫中选择“扫一扫”，扫描此二维码完成登录")
          .foregroundStyle(.secondary).font(.footnote)
      }
      .padding(60)
    }
    .task { loadChallenge() }
    .onDisappear { pollTask?.cancel() }
  }

  private func loadChallenge() {
    pollTask?.cancel()
    challenge = nil; isLoading = true; errorMessage = nil
    Task {
      do {
        let next = try await GatewayClient().createQRSession()
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
          let status = try await GatewayClient().pollQRSession(challenge)
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
