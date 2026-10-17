import Cocoa
import FlutterMacOS

/// The macOS side of "Connect to Claude", for the Dart `ClaudeConnectService`
/// (channel `com.amble/claude_connect`): finds Claude Desktop, says where
/// Downloads is, and hands the Amble extension file to Claude, which shows
/// its own Install dialog.
final class ClaudeConnectBridge {
  private static let channelName = "com.amble/claude_connect"

  /// Claude Desktop's bundle identifier, read from its Info.plist
  /// (2.31226.1, 2026-10-10).
  private static let claudeBundleId = "com.anthropic.claudefordesktop"

  private static let downloadPage = "https://claude.ai/download"

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "isClaudeInstalled":
        result(claudeURL() != nil)
      case "downloadsDirectory":
        result(downloadsDirectory())
      case "openClaudeDownloadPage":
        guard let url = URL(string: downloadPage) else {
          result(false)
          return
        }
        result(NSWorkspace.shared.open(url))
      case "openInClaude":
        guard let path = call.arguments as? String else {
          result(false)
          return
        }
        openInClaude(path: path, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func claudeURL() -> URL? {
    NSWorkspace.shared.urlForApplication(withBundleIdentifier: claudeBundleId)
  }

  /// The real ~/Downloads. Inside the sandbox the Downloads entitlement
  /// makes the container's Downloads a link to it; resolving the link
  /// gives Claude a path outside Amble's container.
  private static func downloadsDirectory() -> String? {
    FileManager.default
      .urls(for: .downloadsDirectory, in: .userDomainMask)
      .first?
      .resolvingSymlinksInPath()
      .path
  }

  private static func openInClaude(path: String, result: @escaping FlutterResult) {
    guard let claude = claudeURL() else {
      result(false)
      return
    }
    NSWorkspace.shared.open(
      [URL(fileURLWithPath: path)],
      withApplicationAt: claude,
      configuration: NSWorkspace.OpenConfiguration()
    ) { _, error in
      DispatchQueue.main.async { result(error == nil) }
    }
  }
}
