/// Represents the three states of a circuit breaker.
enum CircuitBreakerState {
  /// Circuit is closed - normal operation, allowing all calls through.
  /// Failures are counted and when threshold is reached, transitions to Open.
  closed,

  /// Circuit is open - all calls are rejected immediately.
  /// After timeout period, transitions to HalfOpen for testing.
  open,

  /// Circuit is half-open - limited calls are allowed to test if the service has recovered.
  /// Success moves to Closed, failure moves back to Open.
  halfOpen,
}

/// Exception thrown when attempting to execute an action while the circuit is open.
class CircuitOpenException implements Exception {
  final String message;

  const CircuitOpenException(this.message);

  @override
  String toString() => 'CircuitOpenException: $message';
}

/// A Circuit Breaker implementation that provides fault tolerance by monitoring
/// the failure rate of operations and temporarily blocking calls when failures
/// exceed a configured threshold.
///
/// The circuit breaker operates in three states:
/// - **Closed**: Normal operation, calls pass through
/// - **Open**: All calls are rejected immediately
/// - **Half-Open**: Limited calls are allowed to test recovery
class CircuitBreaker {
  /// Number of failures required to open the circuit
  final int threshold;

  /// Duration to keep the circuit open before transitioning to half-open
  final Duration timeout;

  /// Number of successful calls in half-open state needed to close the circuit
  final int halfOpenThreshold;

  /// Current state of the circuit breaker
  CircuitBreakerState _state = CircuitBreakerState.closed;

  /// Counter for consecutive failures in closed state
  int _failureCount = 0;

  /// Counter for successful calls in half-open state
  int _successCount = 0;

  /// Timestamp when the circuit was opened
  DateTime? _lastFailureTime;

  /// Creates a new CircuitBreaker instance.
  ///
  /// [threshold] - Number of consecutive failures before opening the circuit
  /// [timeout] - Duration to keep the circuit open before allowing test calls
  /// [halfOpenThreshold] - Number of successful calls needed to close from half-open state
  CircuitBreaker({
    required this.threshold,
    required this.timeout,
    required this.halfOpenThreshold,
  }) : assert(threshold > 0, 'Threshold must be greater than 0'),
       assert(
         halfOpenThreshold > 0,
         'Half-open threshold must be greater than 0',
       );

  /// Gets the current state of the circuit breaker
  CircuitBreakerState get state => _state;

  /// Gets the current failure count
  int get failureCount => _failureCount;

  /// Gets the current success count in half-open state
  int get successCount => _successCount;

  /// Executes the provided action with circuit breaker protection.
  ///
  /// Returns the result of the action if successful.
  /// Throws [CircuitOpenException] if the circuit is open.
  /// Handles state transitions based on success/failure of the action.
  Future<T> execute<T>(Future<T> Function() action) async {
    // Check if we should transition from open to half-open
    _checkForStateTransition();

    // Reject calls immediately if circuit is open
    if (_state == CircuitBreakerState.open) {
      throw const CircuitOpenException(
        'Circuit breaker is open. Calls are not allowed.',
      );
    }

    try {
      // Execute the action
      final result = await action();

      // Handle successful execution
      _onSuccess();

      return result;
    } catch (error) {
      // Handle failed execution
      _onFailure();

      // Re-throw the original error
      rethrow;
    }
  }

  /// Checks if the circuit should transition from open to half-open state
  /// based on the timeout period.
  void _checkForStateTransition() {
    if (_state == CircuitBreakerState.open && _lastFailureTime != null) {
      final timeSinceLastFailure = DateTime.now().difference(_lastFailureTime!);

      if (timeSinceLastFailure >= timeout) {
        // Transition from Open to Half-Open
        _state = CircuitBreakerState.halfOpen;
        _successCount = 0; // Reset success counter for half-open state
      }
    }
  }

  /// Handles successful execution of an action.
  /// Updates state based on current circuit breaker state.
  void _onSuccess() {
    switch (_state) {
      case CircuitBreakerState.closed:
        // Reset failure count on success in closed state
        _failureCount = 0;
        break;

      case CircuitBreakerState.halfOpen:
        // Increment success count in half-open state
        _successCount++;

        // Check if we have enough successes to close the circuit
        if (_successCount >= halfOpenThreshold) {
          // Transition from Half-Open to Closed
          _state = CircuitBreakerState.closed;
          _failureCount = 0;
          _successCount = 0;
          _lastFailureTime = null;
        }
        break;

      case CircuitBreakerState.open:
        // This should not happen as calls are rejected in open state
        break;
    }
  }

  /// Handles failed execution of an action.
  /// Updates failure count and potentially opens the circuit.
  void _onFailure() {
    _lastFailureTime = DateTime.now();

    switch (_state) {
      case CircuitBreakerState.closed:
        // Increment failure count in closed state
        _failureCount++;

        // Check if we've reached the failure threshold
        if (_failureCount >= threshold) {
          // Transition from Closed to Open
          _state = CircuitBreakerState.open;
        }
        break;

      case CircuitBreakerState.halfOpen:
        // Any failure in half-open state immediately opens the circuit
        _state = CircuitBreakerState.open;
        _failureCount = threshold; // Set to threshold to maintain consistency
        _successCount = 0; // Reset success count
        break;

      case CircuitBreakerState.open:
        // Update failure count even in open state for consistency
        _failureCount++;
        break;
    }
  }

  /// Manually resets the circuit breaker to closed state.
  /// This can be useful for testing or administrative purposes.
  void reset() {
    _state = CircuitBreakerState.closed;
    _failureCount = 0;
    _successCount = 0;
    _lastFailureTime = null;
  }

  @override
  String toString() {
    return 'CircuitBreaker(state: $_state, failures: $_failureCount, '
        'successes: $_successCount, threshold: $threshold, '
        'halfOpenThreshold: $halfOpenThreshold)';
  }
}
