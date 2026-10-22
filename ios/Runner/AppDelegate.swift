import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = self.registrar(forPlugin: "Mptrack3Media") {
      let channel = FlutterMethodChannel(
        name: "mptrack3/ios_media",
        binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        MediaMetadataReader.handle(call, result: result)
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

/// Reads tags and artwork of files in the app's Documents folder.
enum MediaMetadataReader {
  private static let queue = DispatchQueue(label: "mptrack3.metadata", qos: .userInitiated)

  static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let path = args["path"] as? String else {
      result(FlutterError(code: "ARGS", message: "missing path", details: nil))
      return
    }
    let url = URL(fileURLWithPath: path)
    switch call.method {
    case "metadata":
      queue.async {
        let value = metadata(url)
        DispatchQueue.main.async { result(value) }
      }
    case "artwork":
      let size = args["size"] as? Int ?? 512
      queue.async {
        let data = artwork(url, size: size)
        DispatchQueue.main.async {
          result(data.map { FlutterStandardTypedData(bytes: $0) })
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func metadata(_ url: URL) -> [String: Any] {
    let asset = AVURLAsset(url: url)
    var out: [String: Any] = [:]
    for item in asset.commonMetadata {
      guard let key = item.commonKey, let value = item.stringValue else { continue }
      switch key {
      case .commonKeyTitle: out["title"] = value
      case .commonKeyArtist: out["artist"] = value
      case .commonKeyAlbumName: out["album"] = value
      default: break
      }
    }
    let seconds = CMTimeGetSeconds(asset.duration)
    if seconds.isFinite && seconds > 0 {
      out["durationMs"] = Int(seconds * 1000)
    }
    return out
  }

  private static func artwork(_ url: URL, size: Int) -> Data? {
    let asset = AVURLAsset(url: url)
    for item in asset.commonMetadata where item.commonKey == .commonKeyArtwork {
      guard let data = item.dataValue, let image = UIImage(data: data) else { continue }
      let longest = max(image.size.width, image.size.height)
      let scale = min(1, CGFloat(size) / max(longest, 1))
      if scale >= 1 { return image.jpegData(compressionQuality: 0.9) }
      let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
      let resized = UIGraphicsImageRenderer(size: target).image { _ in
        image.draw(in: CGRect(origin: .zero, size: target))
      }
      return resized.jpegData(compressionQuality: 0.9)
    }
    return nil
  }
}
