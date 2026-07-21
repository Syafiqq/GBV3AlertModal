//
//  FloatingTraversalControl.swift
//  GBV3AlertModalExample
//
//  A fixed floating pill — `‹ Prev | "<name> (i/N)" | Next ›` — installed by
//  `AppDelegate` directly on the key window (pinned above the safe-area
//  bottom), the same window `SampleAlertModal.show()` adds presented dialogs
//  to. `GalleryViewController.presentEntry(at:)` re-asserts this view's
//  front-most z-order after every presentation (`bringSubviewToFront`) so it
//  stays visible and tappable above whatever dialog is currently shown.
//

import UIKit

final class FloatingTraversalControl: UIView {
    /// Invoked when `‹ Prev` is tapped. Wired by `AppDelegate` to `GalleryViewController.step(by: -1)`.
    var onPrev: (() -> Void)?

    /// Invoked when `Next ›` is tapped. Wired by `AppDelegate` to `GalleryViewController.step(by: 1)`.
    var onNext: (() -> Void)?

    private let prevButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
    private let label: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.6
        label.text = " "
        return label
    }()

    init() {
        super.init(frame: .zero)
        setUpView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Sets the center label's text, e.g. `"standard-two-button (2/26)"`.
    func setLabel(_ text: String) {
        label.text = text
    }

    private func setUpView() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor.black.withAlphaComponent(0.85)
        layer.cornerRadius = 22
        clipsToBounds = true

        configure(button: prevButton, title: "‹ Prev", action: #selector(prevTapped))
        configure(button: nextButton, title: "Next ›", action: #selector(nextTapped))

        let stack = UIStackView(arrangedSubviews: [prevButton, label, nextButton])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        prevButton.setContentHuggingPriority(.required, for: .horizontal)
        nextButton.setContentHuggingPriority(.required, for: .horizontal)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }

    private func configure(button: UIButton, title: String, action: Selector) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    @objc
    private func prevTapped() {
        onPrev?()
    }

    @objc
    private func nextTapped() {
        onNext?()
    }
}
