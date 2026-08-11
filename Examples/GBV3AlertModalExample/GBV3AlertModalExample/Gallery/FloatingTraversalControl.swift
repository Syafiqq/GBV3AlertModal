//
//  FloatingTraversalControl.swift
//  GBV3AlertModalExample
//
//  A fixed floating pill — `‹ Prev | ▶ | 1.0s | "<name> (i/N)" | Next ›` —
//  installed by `AppDelegate` directly on the key window (pinned above the
//  safe-area bottom), the same window `SampleAlertModal.show()` adds
//  presented dialogs to. `GalleryViewController.presentEntry(at:)`
//  re-asserts this view's front-most z-order after every presentation
//  (`bringSubviewToFront`) so it stays visible and tappable above whatever
//  dialog is currently shown.
//
//  The play/pause button drives a repeating timer that calls `onNext` every
//  `interval` seconds — the exact same closure `Next ›` uses — so auto-play
//  walks the same combined traversal (wraps at both ends, spans Geniebook +
//  Stress groups) as manual stepping. The interval label cycles through a
//  fixed set of presets on tap and restarts the timer (if running) so the
//  new cadence takes effect immediately.
//

import UIKit

@MainActor
final class FloatingTraversalControl: UIView {
    /// Invoked when `‹ Prev` is tapped. Wired by `AppDelegate` to `GalleryViewController.step(by: -1)`.
    var onPrev: (() -> Void)?

    /// Invoked when `Next ›` is tapped, and by the auto-play timer on every tick.
    /// Wired by `AppDelegate` to `GalleryViewController.step(by: 1)`.
    var onNext: (() -> Void)?

    /// The cycle of selectable auto-play cadences, in seconds. Index 1 (`1.0`) is the default.
    private static let intervalOptions: [TimeInterval] = [0.5, 1.0, 2.0, 3.0]

    private var intervalIndex = 1
    private var interval: TimeInterval { Self.intervalOptions[intervalIndex] }

    private var timer: Timer?
    private(set) var isPlaying = false

    private let prevButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
    private let playPauseButton = UIButton(type: .system)
    private let intervalButton = UIButton(type: .system)
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

    /// Stops auto-play without touching traversal state. Called by
    /// `GalleryViewController` whenever the user drives traversal manually
    /// (a list row tap) — `‹ Prev`/`Next ›` pause themselves directly.
    func pauseAutoPlay() {
        guard isPlaying else {
            return
        }
        isPlaying = false
        stopTimer()
        updatePlayPauseTitle()
    }

    private func setUpView() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor.black.withAlphaComponent(0.85)
        layer.cornerRadius = 22
        clipsToBounds = true

        configure(button: prevButton, title: "‹ Prev", action: #selector(prevTapped))
        configure(button: nextButton, title: "Next ›", action: #selector(nextTapped))
        configure(button: playPauseButton, title: "▶", action: #selector(playPauseTapped))
        configure(button: intervalButton, title: intervalTitle, action: #selector(intervalTapped), fontSize: 12)

        let stack = UIStackView(arrangedSubviews: [prevButton, playPauseButton, intervalButton, label, nextButton])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        [prevButton, nextButton, playPauseButton, intervalButton].forEach {
            $0.setContentHuggingPriority(.required, for: .horizontal)
            $0.setContentCompressionResistancePriority(.required, for: .horizontal)
        }

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }

    private func configure(button: UIButton, title: String, action: Selector, fontSize: CGFloat = 15) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: fontSize, weight: .semibold)
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    // MARK: - Traversal (manual)

    @objc
    private func prevTapped() {
        pauseAutoPlay()
        onPrev?()
    }

    @objc
    private func nextTapped() {
        pauseAutoPlay()
        onNext?()
    }

    // MARK: - Auto-play

    @objc
    private func playPauseTapped() {
        isPlaying.toggle()
        updatePlayPauseTitle()
        if isPlaying {
            startTimer()
        } else {
            stopTimer()
        }
    }

    private func updatePlayPauseTitle() {
        playPauseButton.setTitle(isPlaying ? "⏸" : "▶", for: .normal)
    }

    private func startTimer() {
        stopTimer()
        let newTimer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            // `RunLoop.main.add(_:forMode:)` below guarantees this fires on the main
            // thread/actor, same as a plain `Timer.scheduledTimer` would — `assumeIsolated`
            // just makes that existing guarantee visible to the type system.
            MainActor.assumeIsolated {
                self?.onNext?()
            }
        }
        // `.common` (not `.default`) so auto-play keeps ticking while the table view is
        // being scrolled/tracked — a plain `scheduledTimer` would silently stall then.
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Interval

    private var intervalTitle: String {
        String(format: "%.1fs", interval)
    }

    @objc
    private func intervalTapped() {
        intervalIndex = (intervalIndex + 1) % Self.intervalOptions.count
        intervalButton.setTitle(intervalTitle, for: .normal)
        // Cadence changed — restart so the new interval takes effect immediately, not
        // after the currently-running (old-interval) tick fires.
        if isPlaying {
            startTimer()
        }
    }
}
