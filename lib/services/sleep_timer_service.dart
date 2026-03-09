/// sleep_timer_service.dart
/// A standalone sleep timer that counts down and fires a callback on expiry.
///
/// Used by ReaderProvider to manage the reading sleep timer independently
/// from the auto-scroll engine and progress auto-save timers.
///
/// Why a separate service?
///   Keeping the timer logic in its own class makes it easy to:
///   - Unit test in isolation
///   - Cancel cleanly without touching unrelated provider state
///   - Reuse if we ever add a background notification on expiry
///
/// Usage:
///   final timer = SleepTimerService(
///     durationMinutes: 30,
///     onTick:    (remaining) => updateCountdown(remaining),
///     onExpired: () => showSleepOverlay(),
///   );
///   timer.start();
///   ...
///   timer.cancel(); // e.g. when user taps "Keep reading"

import 'dart:async';

// ─────────────────────────────────────────────────────────────────────────────
// SLEEP TIMER SERVICE
// ─────────────────────────────────────────────────────────────────────────────

class SleepTimerService {
  /// Duration in minutes before the timer fires.
  final int durationMinutes;

  /// Called every second with the number of seconds remaining.
  /// Use this to display a countdown if desired.
  final void Function(int remainingSeconds)? onTick;

  /// Called once when the countdown reaches zero.
  final VoidCallback onExpired;

  // ── Internal state ────────────────────────────────────────────────────────

  Timer?  _timer;
  int     _remainingSeconds = 0;
  bool    _isRunning        = false;

  // ── Public read-only state ────────────────────────────────────────────────

  bool get isRunning => _isRunning;
  int  get remainingSeconds => _remainingSeconds;

  SleepTimerService({
    required this.durationMinutes,
    required this.onExpired,
    this.onTick,
  });

  // ─────────────────────────────────────────────────────────────────────────
  // START
  // ─────────────────────────────────────────────────────────────────────────

  /// Starts the countdown. If already running, resets to the full duration.
  void start() {
    cancel(); // Cancel any existing timer first

    _remainingSeconds = durationMinutes * 60;
    _isRunning        = true;

    // Tick every second
    _timer = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  void _onTick(Timer timer) {
    _remainingSeconds--;

    // Notify the UI about the remaining time
    onTick?.call(_remainingSeconds);

    if (_remainingSeconds <= 0) {
      // Time's up — stop the timer and notify
      cancel();
      onExpired();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CANCEL / PAUSE / EXTEND
  // ─────────────────────────────────────────────────────────────────────────

  /// Cancels the timer completely. Call this when the user taps "Keep reading".
  void cancel() {
    _timer?.cancel();
    _timer        = null;
    _isRunning    = false;
    _remainingSeconds = 0;
  }

  /// Pauses the countdown without resetting it.
  /// Useful if the user pauses auto-scroll mid-session.
  void pause() {
    if (!_isRunning) return;
    _timer?.cancel();
    _timer     = null;
    _isRunning = false;
    // Note: _remainingSeconds is preserved so resume() picks up where we left off
  }

  /// Resumes a paused timer.
  void resume() {
    if (_isRunning || _remainingSeconds <= 0) return;
    _isRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  /// Adds [extraMinutes] to the current remaining time.
  /// Called when the user taps "Keep reading" but wants to extend rather
  /// than cancel entirely.
  void extend(int extraMinutes) {
    _remainingSeconds += extraMinutes * 60;
    // If not currently running, restart it
    if (!_isRunning) resume();
  }

  /// Clean up — always call this when the reader closes.
  void dispose() => cancel();
}

// Shorthand type alias so callers don't need to import dart:ui
typedef VoidCallback = void Function();
