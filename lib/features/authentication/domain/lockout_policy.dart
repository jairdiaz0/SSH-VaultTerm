/// Progressive, persistent anti-brute-force policy for the local profile
/// password. All values are persisted in the catalog so they survive restarts.
class LockoutPolicy {
  const LockoutPolicy({
    this.freeAttempts = 3,
    this.baseDelay = const Duration(seconds: 2),
    this.maxDelay = const Duration(minutes: 5),
    this.maxShift = 10,
  });

  /// Failures allowed before any delay is applied.
  final int freeAttempts;
  final Duration baseDelay;
  final Duration maxDelay;

  /// Upper bound for the exponential shift, to avoid absurd values.
  final int maxShift;

  /// Delay to apply after [failedAttempts] consecutive failures.
  Duration delayFor(int failedAttempts) {
    if (failedAttempts < freeAttempts) return Duration.zero;
    final shift = (failedAttempts - freeAttempts).clamp(0, maxShift);
    final millis = baseDelay.inMilliseconds * (1 << shift);
    return millis >= maxDelay.inMilliseconds
        ? maxDelay
        : Duration(milliseconds: millis);
  }

  bool isLocked(DateTime? lockoutUntil, DateTime now) =>
      lockoutUntil != null && now.isBefore(lockoutUntil);
}
