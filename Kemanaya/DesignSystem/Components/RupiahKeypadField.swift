import KemanayaCore
import SwiftUI
import UIKit

/// The rupiah keypad as a real keyboard (D-067): an invisible responder whose `inputView` hosts
/// ``RupiahKeypad``. iOS then treats it like any keyboard, so moving focus to a text field swaps it for the
/// system keyboard (never both on screen), and dragging a scroll view with `.scrollDismissesKeyboard`
/// dismisses it the same way.
///
/// It draws nothing: put it behind the amount the keypad types into and set `isFocused` to show the
/// keypad (for example when the amount is tapped). `isFocused` follows the responder both ways: it
/// turns false when another field takes focus or the keyboard is dismissed.
///
/// The keys keep their identifiers (`<identifierPrefix>.0` … `.9`, `.000`, `.backspace`), VoiceOver
/// labels and Dynamic Type, taken from this view's environment. They play the system keyboard click when
/// the user has keyboard clicks on. A hardware keyboard types digits and deletes too.
struct RupiahKeypadField: UIViewRepresentable {
    @Binding var isFocused: Bool
    let identifierPrefix: String
    let onPress: (KeypadInput) -> Void

    init(isFocused: Binding<Bool>, identifierPrefix: String, onPress: @escaping (KeypadInput) -> Void) {
        _isFocused = isFocused
        self.identifierPrefix = identifierPrefix
        self.onPress = onPress
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> KeypadResponder {
        let coordinator = context.coordinator
        let responder = KeypadResponder(keypad: KeypadInputView(rootView: keypadHost(context)))
        responder.onPress = { coordinator.press($0) }
        responder.onFocusChange = { coordinator.focusChanged($0) }
        return responder
    }

    func updateUIView(_ responder: KeypadResponder, context: Context) {
        context.coordinator.field = self
        responder.keypad.update(rootView: keypadHost(context), colorScheme: context.environment.colorScheme)
        responder.setFocused(isFocused)
    }

    private func keypadHost(_ context: Context) -> KeypadHost {
        let coordinator = context.coordinator
        return KeypadHost(
            identifierPrefix: identifierPrefix,
            dynamicTypeSize: context.environment.dynamicTypeSize,
            colorScheme: context.environment.colorScheme,
            locale: context.environment.locale,
            onPress: { coordinator.press($0) }
        )
    }

    final class Coordinator {
        var field: RupiahKeypadField

        init(_ field: RupiahKeypadField) {
            self.field = field
        }

        func press(_ key: KeypadInput) {
            UIDevice.current.playInputClick()
            field.onPress(key)
        }

        /// Called by the responder after it gained or lost focus. Deferred, because it can happen while
        /// SwiftUI updates the view (``KeypadResponder/setFocused(_:)``).
        func focusChanged(_ isFocused: Bool) {
            Task { @MainActor in
                if field.isFocused != isFocused { field.isFocused = isFocused }
            }
        }
    }
}

/// The keypad inside the keyboard, with the add sheet's environment: the keyboard lives in its own
/// window, which doesn't inherit the sheet's SwiftUI environment.
struct KeypadHost: View {
    let identifierPrefix: String
    let dynamicTypeSize: DynamicTypeSize
    let colorScheme: ColorScheme
    let locale: Locale
    let onPress: (KeypadInput) -> Void

    var body: some View {
        RupiahKeypad(identifierPrefix: identifierPrefix, onPress: onPress)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .foregroundStyle(Color(.textPrimary))
            .environment(\.dynamicTypeSize, dynamicTypeSize)
            .environment(\.colorScheme, colorScheme)
            .environment(\.locale, locale)
    }
}

/// The input view: the hosted keypad on the sheet's background, sized to the keypad plus the home
/// indicator's safe area, like the current keypad at this text size.
///
/// The keyboard takes an input view's frame height (it follows neither the hosted view's size nor
/// `intrinsicContentSize`), so ``fit(bottomInset:)`` measures the keypad and sets the frame before it shows.
final class KeypadInputView: UIInputView, UIInputViewAudioFeedback {
    private let host: UIHostingController<KeypadHost>

    var enableInputClicksWhenVisible: Bool { true }

    init(rootView: KeypadHost) {
        host = UIHostingController(rootView: rootView)
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 300), inputViewStyle: .default)
        autoresizingMask = .flexibleWidth
        backgroundColor = UIColor(resource: .appBackground)

        host.sizingOptions = .intrinsicContentSize
        host.safeAreaRegions = []
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: topAnchor),
            host.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func update(rootView: KeypadHost, colorScheme: ColorScheme) {
        host.rootView = rootView
        overrideUserInterfaceStyle = colorScheme == .dark ? .dark : .light
    }

    /// Sets the frame height to the keypad's fitted height at this text size plus `bottomInset` (the
    /// home indicator's safe area, which the keyboard area includes).
    /// - Returns: whether the height changed, so a keyboard already on screen must be reloaded.
    @discardableResult
    func fit(bottomInset: CGFloat) -> Bool {
        // Before the keyboard first shows the width is still 0; the keys only grow with the text size,
        // so any phone width gives the same height.
        let width = bounds.width > 0 ? bounds.width : 390
        let keypad = host.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude)).height
        let height = (keypad + bottomInset).rounded(.up)
        guard abs(frame.height - height) > 0.5 else { return false }
        frame.size.height = height
        return true
    }
}

/// The first responder that owns the keypad. It is invisible and hidden from VoiceOver; the amount
/// it sits behind is what people see and tap.
final class KeypadResponder: UIView, UIKeyInput {
    let keypad: KeypadInputView
    var onPress: ((KeypadInput) -> Void)?
    var onFocusChange: ((Bool) -> Void)?

    /// Focus asked for before the view was in a window (the sheet opening with the keypad up).
    private var wantsFocus = false

    init(keypad: KeypadInputView) {
        self.keypad = keypad
        super.init(frame: .zero)
        isAccessibilityElement = false
        accessibilityElementsHidden = true
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var canBecomeFirstResponder: Bool { true }
    override var inputView: UIView? { keypad }

    /// Makes the responder match `isFocused`, now or once it is in a window, and keeps the keypad's
    /// height in step with the text size.
    func setFocused(_ isFocused: Bool) {
        wantsFocus = isFocused
        guard let window else { return }
        if keypad.fit(bottomInset: window.safeAreaInsets.bottom), isFirstResponder {
            reloadInputViews()
        }
        if isFocused, !isFirstResponder {
            becomeFirstResponder()
        } else if !isFocused, isFirstResponder {
            resignFirstResponder()
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil, wantsFocus, !isFirstResponder { becomeFirstResponder() }
    }

    @discardableResult
    override func becomeFirstResponder() -> Bool {
        if let window { keypad.fit(bottomInset: window.safeAreaInsets.bottom) }
        let became = super.becomeFirstResponder()
        if became { onFocusChange?(true) }
        return became
    }

    @discardableResult
    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned {
            wantsFocus = false
            onFocusChange?(false)
        }
        return resigned
    }

    // MARK: UIKeyInput (a hardware keyboard)

    var hasText: Bool { true }

    func insertText(_ text: String) {
        for character in text {
            if let digit = character.wholeNumberValue, (0...9).contains(digit) {
                onPress?(.digit(digit))
            }
        }
    }

    func deleteBackward() {
        onPress?(.backspace)
    }
}
