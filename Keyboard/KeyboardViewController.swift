import SwiftUI
import UIKit

/// Adopting UIInputViewAudioFeedback enables the standard keyboard click sound.
final class KeyboardInputView: UIInputView, UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool { true }
}

final class KeyboardViewController: UIInputViewController {
    let state = KeyboardState()
    private var host: UIHostingController<KeyboardRootView>?
    private var heightConstraint: NSLayoutConstraint?

    override func loadView() {
        let v = KeyboardInputView(frame: CGRect(x: 0, y: 0, width: 320, height: 300), inputViewStyle: .keyboard)
        v.allowsSelfSizing = true
        view = v
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        state.controller = self
        state.onScreenChange = { [weak self] in self?.updateHeight() }
        state.reload()

        let host = UIHostingController(rootView: KeyboardRootView(state: state))
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 16.4, *) {
            host.safeAreaRegions = []
        }
        addChild(host)
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)
        self.host = host

        requestSupplementaryLexicon { [weak self] lexicon in
            self?.state.autocorrector.setLexicon(lexicon)
        }

        let h = view.heightAnchor.constraint(equalToConstant: preferredHeight())
        h.priority = UILayoutPriority(999)
        h.isActive = true
        heightConstraint = h
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        state.reload()
        applyTheme()
        updateHeight()
        state.textDidChange()
        if case .panel(.clipboard) = state.screen { state.captureClipboard(force: false) }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateHeight()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in self.updateHeight() })
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        state.textDidChange()
    }

    override func selectionDidChange(_ textInput: UITextInput?) {
        super.selectionDidChange(textInput)
        state.afterEdit()
    }

    private func applyTheme() {
        switch state.settings.theme {
        case .system: view.overrideUserInterfaceStyle = .unspecified
        case .light: view.overrideUserInterfaceStyle = .light
        case .dark: view.overrideUserInterfaceStyle = .dark
        }
    }

    private func updateHeight() {
        let h = preferredHeight()
        if let c = heightConstraint, abs(c.constant - h) > 0.5 {
            c.constant = h
        }
    }

    private func preferredHeight() -> CGFloat {
        let screen = view.window?.windowScene?.screen.bounds ?? UIScreen.main.bounds
        let landscape = screen.width > screen.height
        let pad = traitCollection.userInterfaceIdiom == .pad && view.bounds.width != 0
            ? view.bounds.width > 600
            : traitCollection.userInterfaceIdiom == .pad
        // One fixed height for letters and panels: resizing the keyboard while a
        // panel is open leaves lazy grids with unrendered (blank) cells.
        let base: CGFloat
        if pad {
            base = landscape ? 410 : 360
        } else {
            base = landscape ? 210 : 280
        }
        return (base * CGFloat(state.settings.heightScale)).rounded()
    }
}
