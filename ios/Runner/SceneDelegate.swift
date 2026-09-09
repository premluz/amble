import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
                     options connectionOptions: UIScene.ConnectionOptions) {
    guard let windowScene = scene as? UIWindowScene else { return }
    let host = AmbleFlutterHost.shared
    host.start()
    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = host.engine.viewController ??
      FlutterViewController(engine: host.engine, nibName: nil, bundle: nil)
    self.window = window
    // Keep Flutter's plugin lifecycle/notification/deep-link forwarding.
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    window.makeKeyAndVisible()
  }
}
