//
//  PauseController.swift
//  MyPasteApp
//
//  Owns whether clipboard capture is paused, and for how long.
//

import AppKit
import Foundation

/// Whether capture is running, and until when it isn't.
///
/// Deliberately not persisted: an app that comes back silently paused makes
/// the user lose hours of history thinking it broke.
enum PauseState: Equatable {
    case active
    case pausedIndefinitely
    case pausedUntil(Date)

    func isPaused(at now: Date) -> Bool {
        switch self {
        case .active:
            return false
        case .pausedIndefinitely:
            return true
        case .pausedUntil(let deadline):
            return now < deadline
        }
    }
}

/// One of the durations offered in the status menu.
struct PauseDuration: Equatable {
    let seconds: TimeInterval

    var title: String {
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "\(minutes) minutes" }
        let hours = minutes / 60
        return hours == 1 ? "1 hour" : "\(hours) hours"
    }

    /// Someone pausing for privacy usually wants the whole meeting or the
    /// whole workday, not ten minutes.
    static let offered: [PauseDuration] = [
        PauseDuration(seconds: 15 * 60),
        PauseDuration(seconds: 30 * 60),
        PauseDuration(seconds: 60 * 60),
        PauseDuration(seconds: 3 * 60 * 60),
        PauseDuration(seconds: 8 * 60 * 60),
    ]
}

@MainActor
final class PauseController {
    /// Posted on every transition, so the status bar icon can follow along.
    static let stateChanged = Notification.Name("MyPasteApp.pauseStateChanged")

    private(set) var state: PauseState = .active
    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?

    init() {
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshAfterWake() }
        }
    }

    var isPaused: Bool { state.isPaused(at: .now) }

    func pauseIndefinitely() {
        transition(to: .pausedIndefinitely)
    }

    func pause(for duration: PauseDuration) {
        transition(to: .pausedUntil(Date.now.addingTimeInterval(duration.seconds)))
        let timer = Timer.scheduledTimer(withTimeInterval: duration.seconds,
                                         repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in self?.resume() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func resume() {
        transition(to: .active)
    }

    /// Used by the global shortcut, which has no way to pick a duration.
    func toggle() {
        isPaused ? resume() : pauseIndefinitely()
    }

    private func transition(to newState: PauseState) {
        timer?.invalidate()
        timer = nil
        state = newState
        NotificationCenter.default.post(name: Self.stateChanged, object: self)
    }

    /// A Timer doesn't fire while the machine sleeps and comes back late.
    /// Capture already resumes on its own — `isPaused` is decided against the
    /// clock — but without this the icon would keep claiming the app is
    /// paused while it is in fact collecting.
    private func refreshAfterWake() {
        guard case .pausedUntil = state, !isPaused else { return }
        resume()
    }

    deinit {
        timer?.invalidate()
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
    }
}
