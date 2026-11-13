import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
    private var privacyOverlays: [UIView] = []

    override func sceneWillResignActive(_ scene: UIScene) {
        super.sceneWillResignActive(scene)
        guard let windowScene = scene as? UIWindowScene else { return }
        for window in windowScene.windows {
            let cover = UIView(frame: window.bounds)
            cover.backgroundColor = .systemBackground
            cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            let label = UILabel()
            label.text = "FamilyVault"
            label.font = .systemFont(ofSize: 28, weight: .semibold)
            label.textColor = .label
            label.translatesAutoresizingMaskIntoConstraints = false
            cover.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: cover.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: cover.centerYAnchor)
            ])
            window.addSubview(cover)
            privacyOverlays.append(cover)
        }
    }

    override func sceneDidBecomeActive(_ scene: UIScene) {
        super.sceneDidBecomeActive(scene)
        privacyOverlays.forEach { $0.removeFromSuperview() }
        privacyOverlays.removeAll()
    }
}
