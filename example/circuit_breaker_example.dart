import 'dart:math';
import 'package:circuit_breaker/circuit_breaker.dart';

void main() async {
  print('=== Circuit Breaker Example ===\n');

  // Create a circuit breaker with:
  // - threshold: 3 failures before opening
  // - timeout: 2 seconds before transitioning to half-open
  // - halfOpenThreshold: 2 successful calls to close from half-open
  final circuitBreaker = CircuitBreaker(
    threshold: 3,
    timeout: const Duration(seconds: 2),
    halfOpenThreshold: 2,
  );

  print('Initial state: ${circuitBreaker.state}');
  print('Circuit breaker configuration: $circuitBreaker\n');

  // Example 1: Demonstrate normal operation (closed state)
  print('--- Example 1: Normal Operation ---');
  await demonstrateNormalOperation(circuitBreaker);

  // Example 2: Demonstrate circuit opening due to failures
  print('\n--- Example 2: Circuit Opening ---');
  await demonstrateCircuitOpening(circuitBreaker);

  // Example 3: Demonstrate circuit staying open
  print('\n--- Example 3: Circuit Staying Open ---');
  await demonstrateCircuitOpen(circuitBreaker);

  // Example 4: Demonstrate transition to half-open and recovery
  print('\n--- Example 4: Recovery Process ---');
  await demonstrateRecovery(circuitBreaker);
}

/// Mock service that simulates an unreliable external service
class MockService {
  static final Random _random = Random();
  static int _callCount = 0;
  static bool _shouldFail = false;

  /// Sets whether the service should fail
  static void setShouldFail(bool shouldFail) {
    _shouldFail = shouldFail;
  }

  /// Simulates an API call that may succeed or fail
  static Future<String> apiCall() async {
    _callCount++;

    // Simulate network delay
    await Future.delayed(Duration(milliseconds: 100 + _random.nextInt(200)));

    if (_shouldFail || _random.nextDouble() < 0.3) {
      // 30% chance of failure when not forced
      throw Exception('Service temporarily unavailable (call #$_callCount)');
    }

    return 'Success response from API call #$_callCount';
  }

  /// Simulates a database query
  static Future<Map<String, dynamic>> databaseQuery() async {
    _callCount++;

    await Future.delayed(Duration(milliseconds: 50 + _random.nextInt(100)));

    if (_shouldFail) {
      throw Exception('Database connection failed (query #$_callCount)');
    }

    return {
      'id': _callCount,
      'data': 'Sample data from query #$_callCount',
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  static void reset() {
    _callCount = 0;
    _shouldFail = false;
  }
}

/// Demonstrates normal operation when service is working
Future<void> demonstrateNormalOperation(CircuitBreaker circuitBreaker) async {
  MockService.reset();
  MockService.setShouldFail(false);
  circuitBreaker.reset();

  print('Making successful calls through circuit breaker...');

  for (int i = 1; i <= 3; i++) {
    try {
      final result = await circuitBreaker.execute(() => MockService.apiCall());
      print('Call $i: $result');
      print(
        '  State: ${circuitBreaker.state}, Failures: ${circuitBreaker.failureCount}',
      );
    } catch (e) {
      print('Call $i failed: $e');
      print(
        '  State: ${circuitBreaker.state}, Failures: ${circuitBreaker.failureCount}',
      );
    }
  }
}

/// Demonstrates circuit opening when failures exceed threshold
Future<void> demonstrateCircuitOpening(CircuitBreaker circuitBreaker) async {
  MockService.reset();
  MockService.setShouldFail(true); // Force failures
  circuitBreaker.reset();

  print('Making failing calls to trigger circuit opening...');

  for (int i = 1; i <= 5; i++) {
    try {
      final result = await circuitBreaker.execute(
        () => MockService.databaseQuery(),
      );
      print('Call $i: $result');
    } catch (e) {
      if (e is CircuitOpenException) {
        print('Call $i: Circuit is OPEN - ${e.message}');
      } else {
        print('Call $i failed: ${e.toString()}');
      }
      print(
        '  State: ${circuitBreaker.state}, Failures: ${circuitBreaker.failureCount}',
      );
    }
  }
}

/// Demonstrates that calls are rejected when circuit is open
Future<void> demonstrateCircuitOpen(CircuitBreaker circuitBreaker) async {
  print('Attempting calls while circuit is open...');

  for (int i = 1; i <= 3; i++) {
    try {
      await circuitBreaker.execute(() => MockService.apiCall());
    } catch (e) {
      print('Call $i: ${e.toString()}');
      print('  State: ${circuitBreaker.state}');
    }
  }
}

/// Demonstrates transition to half-open state and recovery
Future<void> demonstrateRecovery(CircuitBreaker circuitBreaker) async {
  print('Waiting for timeout to transition to half-open...');

  // Wait for the timeout period
  await Future.delayed(const Duration(seconds: 3));

  // Service is now working again
  MockService.setShouldFail(false);

  print('Making calls after timeout (half-open state)...');

  for (int i = 1; i <= 4; i++) {
    try {
      final result = await circuitBreaker.execute(() => MockService.apiCall());
      print('Call $i: $result');
      print(
        '  State: ${circuitBreaker.state}, Successes: ${circuitBreaker.successCount}',
      );

      if (circuitBreaker.state == CircuitBreakerState.closed) {
        print('  🎉 Circuit is now CLOSED - normal operation restored!');
        break;
      }
    } catch (e) {
      if (e is CircuitOpenException) {
        print('Call $i: Circuit is OPEN - ${e.message}');
      } else {
        print('Call $i failed: ${e.toString()}');
      }
      print('  State: ${circuitBreaker.state}');
    }
  }

  print('\nFinal circuit breaker state: $circuitBreaker');
}

/// Additional example showing different usage patterns
void additionalExamples() async {
  print('\n=== Additional Usage Examples ===\n');

  final cb = CircuitBreaker(
    threshold: 2,
    timeout: const Duration(seconds: 1),
    halfOpenThreshold: 1,
  );

  // Example: Wrapping different types of operations
  print('--- Wrapping Different Operations ---');

  try {
    // HTTP request simulation
    final httpResponse = await cb.execute<Map<String, dynamic>>(() async {
      await Future.delayed(const Duration(milliseconds: 100));
      return {'status': 200, 'body': 'OK'};
    });
    print('HTTP Response: $httpResponse');

    // File operation simulation
    final fileContent = await cb.execute<String>(() async {
      await Future.delayed(const Duration(milliseconds: 50));
      return 'File content loaded successfully';
    });
    print('File Content: $fileContent');

    // Database operation simulation
    final dbResult = await cb.execute<List<String>>(() async {
      await Future.delayed(const Duration(milliseconds: 150));
      return ['record1', 'record2', 'record3'];
    });
    print('Database Result: $dbResult');
  } catch (e) {
    print('Operation failed: $e');
  }

  print('\nCircuit breaker final state: ${cb.state}');
}
