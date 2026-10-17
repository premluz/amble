import 'package:flutter/services.dart';

/// The platform side of "Connect to Claude" (channel
/// `com.amble/claude_connect`, implemented on macOS). Every method degrades
/// to "not available" where there is no handler, so the Settings screen can
/// explain instead of failing.
class ClaudeConnectService {
  const ClaudeConnectService();

  static const _channel = MethodChannel('com.amble/claude_connect');

  Future<bool> isClaudeInstalled() async =>
      await _invoke<bool>('isClaudeInstalled') ?? false;

  /// The person's Downloads folder, where the extension file is written for
  /// Claude to open; null when unavailable.
  Future<String?> downloadsDirectory() => _invoke<String>('downloadsDirectory');

  /// Hands the file at [path] to Claude Desktop, which shows its Install
  /// dialog. True when Claude accepted it.
  Future<bool> openInClaude(String path) async =>
      await _invoke<bool>('openInClaude', path) ?? false;

  /// Opens Claude's download page in the browser. False when it can't.
  Future<bool> openClaudeDownloadPage() async =>
      await _invoke<bool>('openClaudeDownloadPage') ?? false;

  Future<T?> _invoke<T>(String method, [Object? argument]) async {
    try {
      return await _channel.invokeMethod<T>(method, argument);
    } on MissingPluginException {
      return null;
    }
  }
}
