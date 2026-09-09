import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // App Intents can launch the application WITHOUT connecting a scene.
    // Start Dart here, then let SceneDelegate attach to this same engine.
    AmbleFlutterHost.shared.start()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
