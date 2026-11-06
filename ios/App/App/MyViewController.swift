import UIKit
import Capacitor

class MyViewController: CAPBridgeViewController {
    private var launchOverlay: UIView?
    private var launchArtwork: UIView?
    private var launchBackground: UIImageView?
    private var launchStarted = false
    private var allowsNoteRotation = false
    private var appearancePreference = "system"

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

    func setAppearance(_ preference: String, dark: Bool) {
        appearancePreference = preference
        let style: UIUserInterfaceStyle = preference == "system" ? .unspecified : (dark ? .dark : .light)
        overrideUserInterfaceStyle = style
        view.window?.overrideUserInterfaceStyle = style
        updateBackground(traitCollection.userInterfaceStyle == .dark)
    }

    private func updateBackground(_ dark: Bool) {
        let background = UIColor(red: dark ? 8.0 / 255.0 : 247.0 / 255.0,
                                 green: dark ? 12.0 / 255.0 : 248.0 / 255.0,
                                 blue: dark ? 18.0 / 255.0 : 246.0 / 255.0,
                                 alpha: 1.0)
        view.window?.backgroundColor = background
        view.backgroundColor = background
        webView?.backgroundColor = background
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if appearancePreference == "system" {
            updateBackground(traitCollection.userInterfaceStyle == .dark)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let overlay = UIView(frame: view.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.backgroundColor = .clear

        let launchImage = UIImageView(frame: overlay.bounds)
        launchImage.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        launchImage.image = UIImage(named: "SplashBackground")
        launchImage.contentMode = .scaleAspectFill
        launchImage.clipsToBounds = true
        overlay.addSubview(launchImage)

        view.addSubview(overlay)
        launchOverlay = overlay
        launchBackground = launchImage
        if let source = UIImage(named: "Splash")?.cgImage {
            let rect = CGRect(x: CGFloat(source.width) * 278 / 884,
                              y: CGFloat(source.height) * 624 / 1780,
                              width: CGFloat(source.width) * 328 / 884,
                              height: CGFloat(source.height) * 335 / 1780).integral
            if let crop = source.cropping(to: rect) {
                let card = UIView()
                let image = UIImageView(image: UIImage(cgImage: crop))
                image.contentMode = .scaleToFill
                image.clipsToBounds = true
                image.tag = 401
                card.addSubview(image)
                card.layer.shadowColor = UIColor.black.cgColor
                card.layer.shadowOpacity = 0.13
                card.layer.shadowRadius = 8
                card.layer.shadowOffset = CGSize(width: 0, height: 4)
                overlay.addSubview(card)
                launchArtwork = card
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let overlay = launchOverlay, let card = launchArtwork,
              card.transform == .identity, let source = UIImage(named: "Splash") else { return }
        let scale = max(overlay.bounds.width / source.size.width, overlay.bounds.height / source.size.height)
        let width = source.size.width * scale, height = source.size.height * scale
        card.frame = CGRect(x: (overlay.bounds.width - width) / 2 + width * 278 / 884,
                            y: (overlay.bounds.height - height) / 2 + height * 624 / 1780,
                            width: width * 328 / 884, height: height * 335 / 1780)
        if let image = card.viewWithTag(401) {
            image.frame = card.bounds
            image.layer.cornerRadius = card.bounds.width * 0.20
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard !launchStarted, let overlay = launchOverlay else { return }
        let artwork = launchArtwork ?? overlay
        launchStarted = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self, weak overlay, weak artwork] in
            guard let self, let overlay, let artwork, overlay.superview != nil else { return }
            let finish = {
                overlay.removeFromSuperview()
                self.launchOverlay = nil
                self.launchArtwork = nil
                self.launchBackground = nil
            }
            if UIAccessibility.isReduceMotionEnabled {
                UIView.animate(withDuration: 0.18, animations: { overlay.alpha = 0 }, completion: { _ in finish() })
                return
            }
            UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseInOut], animations: {
                artwork.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
            }, completion: { _ in
                UIView.animate(withDuration: 0.56, delay: 0, options: [.curveEaseIn], animations: {
                    artwork.transform = CGAffineTransform(scaleX: 3.4, y: 3.4)
                })
                UIView.animate(withDuration: 0.36, delay: 0.20, options: [.curveEaseInOut], animations: {
                    artwork.alpha = 0
                })
                UIView.animate(withDuration: 0.12, delay: 0.44, options: [.curveEaseInOut], animations: {
                    self.launchBackground?.alpha = 0
                }, completion: { _ in finish() })
            })
        }
    }

    override func capacitorDidLoad() {
        bridge?.registerPluginInstance(DutarTunerPlugin())

        webView?.isOpaque = false
        setAppearance("system", dark: traitCollection.userInterfaceStyle == .dark)
    }
}
