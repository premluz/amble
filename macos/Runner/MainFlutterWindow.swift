import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    CalendarReadBridge.register(with: flutterViewController.engine.binaryMessenger)
    SystemSettingsBridge.register(with: flutterViewController.engine.binaryMessenger)
    ClaudeConnectBridge.register(with: flutterViewController.engine.binaryMessenger)

    // Full-bleed window: the app paints to the top edge and the window
    // buttons float over its sidebar, as in Notion Calendar. The bar stays
    // (transparent) so the window still drags from the top; the app keeps
    // its controls below it (ShellLayoutTokens.macTitleBarHeight).
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.styleMask.insert(.fullSizeContentView)

    super.awakeFromNib()
  }
}
