import UIKit
import Capacitor

class MyViewController: CAPBridgeViewController {
    private var launchOverlay: UIView?
    private var allowsNoteRotation = false

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if allowsNoteRotation {
            return UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
        }
        return .portrait
    }

    func setNoteRotationAllowed(_ allowed: Bool) {
        allowsNoteRotation = allowed
        if #available(iOS 16.0, *) {
            setNeedsUpdateOfSupportedInterfaceOrientations()
            if let scene = view.window?.windowScene {
                let mask: UIInterfaceOrientationMask = allowed ? supportedInterfaceOrientations : .portrait
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
            }
        } else {
            UIViewController.attemptRotationToDeviceOrientation()
        }
    }

    func setDarkAppearance(_ dark: Bool) {
        let style: UIUserInterfaceStyle = dark ? .dark : .light
        let background = UIColor(red: dark ? 8.0 / 255.0 : 247.0 / 255.0,
                                 green: dark ? 12.0 / 255.0 : 248.0 / 255.0,
                                 blue: dark ? 18.0 / 255.0 : 246.0 / 255.0,
                                 alpha: 1.0)
        overrideUserInterfaceStyle = style
        view.window?.overrideUserInterfaceStyle = style
        view.window?.backgroundColor = background
        view.backgroundColor = background
        webView?.backgroundColor = background
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let overlay = UIView(frame: view.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.backgroundColor = .white

        let launchImage = UIImageView(frame: overlay.bounds)
        launchImage.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        launchImage.image = UIImage(named: "Splash")
        launchImage.contentMode = .scaleAspectFill
        launchImage.clipsToBounds = true
        overlay.addSubview(launchImage)

        view.addSubview(overlay)
        launchOverlay = overlay
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard let overlay = launchOverlay else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self, weak overlay] in
            guard let overlay else { return }
            UIView.animate(
                withDuration: 0.25,
                animations: {
                    overlay.alpha = 0
                },
                completion: { _ in
                    overlay.removeFromSuperview()
                    self?.launchOverlay = nil
                }
            )
        }
    }

    override func capacitorDidLoad() {
        bridge?.registerPluginInstance(DutarTunerPlugin())

        webView?.isOpaque = false
        setDarkAppearance(traitCollection.userInterfaceStyle == .dark)
    }
}
