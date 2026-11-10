import Foundation

/// Both app-local probes and the extension must start from bundled databases.
/// tvOS cache eviction is expected; recreate missing files before initializing Go.
enum TVRoutingAssets {
  static func prepare(home: URL, bundleURL: URL = Bundle.main.bundleURL) throws {
    let files = FileManager.default
    let app = bundleURL.pathExtension == "appex"
      ? bundleURL.deletingLastPathComponent().deletingLastPathComponent() : bundleURL
    try files.createDirectory(at: home, withIntermediateDirectories: true)
    for name in ["GeoIP.dat", "GeoSite.dat", "ASN.mmdb", "geoip.metadb"] {
      let destination = home.appendingPathComponent(name)
      if let size = try? destination.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 0 { continue }
      let data = try Data(contentsOf: app.appendingPathComponent(name), options: .mappedIfSafe)
      guard !data.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
      try data.write(to: destination, options: .atomic)
    }
  }
}
