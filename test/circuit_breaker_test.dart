import 'package:dart_circuit_breaker/dart_circuit_breaker.dart';
import 'package:test/test.dart';

void main() {
  group('CircuitBreaker', () {
    late CircuitBreaker circuitBreaker;

    setUp(() {
      circuitBreaker = CircuitBreaker(
        threshold: 3,
        timeout: const Duration(milliseconds: 100),
        halfOpenThreshold: 2,
      );
    });

    group('Constructor', () {
      test('should create circuit breaker with valid parameters', () {
        expect(circuitBreaker.state, equals(CircuitBreakerState.closed));
        expect(circuitBreaker.threshold, equals(3));
        expect(
          circuitBreaker.timeout,
          equals(const Duration(milliseconds: 100)),
        );
        expect(circuitBreaker.halfOpenThreshold, equals(2));
        expect(circuitBreaker.failureCount, equals(0));
        expect(circuitBreaker.successCount, equals(0));
      });

      test('should throw assertion error for invalid threshold', () {
        expect(
          () => CircuitBreaker(
            threshold: 0,
            timeout: const Duration(seconds: 1),
            halfOpenThreshold: 1,
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('should throw assertion error for invalid halfOpenThreshold', () {
        expect(
          () => CircuitBreaker(
            threshold: 1,
            timeout: const Duration(seconds: 1),
            halfOpenThreshold: 0,
          ),
          throwsA(isA<AssertionError>()),
        );
      });
    });

    group('Closed State', () {
      test('should execute successful actions and remain closed', () async {
        final result = await circuitBreaker.execute(() async => 'success');

        expect(result, equals('success'));
        expect(circuitBreaker.state, equals(CircuitBreakerState.closed));
        expect(circuitBreaker.failureCount, equals(0));
      });

      test('should reset failure count on successful execution', () async {
        // Cause some failures but not enough to open
        for (int i = 0; i < 2; i++) {
          try {
            await circuitBreaker.execute(() async => throw Exception('fail'));
          } catch (_) {}
        }

        expect(circuitBreaker.failureCount, equals(2));

        // Successful call should reset failure count
        await circuitBreaker.execute(() async => 'success');

        expect(circuitBreaker.failureCount, equals(0));
        expect(circuitBreaker.state, equals(CircuitBreakerState.closed));
      });

      test('should increment failure count on failed execution', () async {
        try {
          await circuitBreaker.execute(() async => throw Exception('fail'));
        } catch (_) {}

        expect(circuitBreaker.failureCount, equals(1));
        expect(circuitBreaker.state, equals(CircuitBreakerState.closed));
      });

      test(
        'should transition to open state when threshold is reached',
        () async {
          // Cause failures equal to threshold
          for (int i = 0; i < 3; i++) {
            try {
              await circuitBreaker.execute(() async => throw Exception('fail'));
            } catch (_) {}
          }

          expect(circuitBreaker.state, equals(CircuitBreakerState.open));
          expect(circuitBreaker.failureCount, equals(3));
        },
      );

      test('should rethrow original exceptions', () async {
        final originalException = Exception('original error');

        expect(
          () => circuitBreaker.execute(() async => throw originalException),
          throwsA(equals(originalException)),
        );
      });
    });

    group('Open State', () {
      setUp(() async {
        // Force circuit to open state
        for (int i = 0; i < 3; i++) {
          try {
            await circuitBreaker.execute(() async => throw Exception('fail'));
          } catch (_) {}
        }
      });

      test('should throw CircuitOpenException when circuit is open', () async {
        expect(
          () => circuitBreaker.execute(() async => 'success'),
          throwsA(isA<CircuitOpenException>()),
        );
      });

      test('should not execute action when circuit is open', () async {
        bool actionExecuted = false;

        try {
          await circuitBreaker.execute(() async {
            actionExecuted = true;
            return 'success';
          });
        } catch (_) {}

        expect(actionExecuted, isFalse);
      });

      test('should transition to half-open after timeout', () async {
        expect(circuitBreaker.state, equals(CircuitBreakerState.open));

        // Wait for timeout
        await Future.delayed(const Duration(milliseconds: 150));

        // Make a call to trigger state check
        try {
          await circuitBreaker.execute(() async => 'success');
        } catch (_) {}

        expect(circuitBreaker.state, equals(CircuitBreakerState.halfOpen));
      });
    });

    group('Half-Open State', () {
      setUp(() async {
        // Force circuit to open state
        for (int i = 0; i < 3; i++) {
          try {
            await circuitBreaker.execute(() async => throw Exception('fail'));
          } catch (_) {}
        }

        // Wait for timeout to transition to half-open
        await Future.delayed(const Duration(milliseconds: 150));
      });

      test('should allow execution in half-open state', () async {
        final result = await circuitBreaker.execute(() async => 'success');

        expect(result, equals('success'));
        expect(circuitBreaker.state, equals(CircuitBreakerState.halfOpen));
        expect(circuitBreaker.successCount, equals(1));
      });

      test(
        'should transition to closed after enough successful calls',
        () async {
          // Make successful calls equal to halfOpenThreshold
          for (int i = 0; i < 2; i++) {
            await circuitBreaker.execute(() async => 'success');
          }

          expect(circuitBreaker.state, equals(CircuitBreakerState.closed));
          expect(circuitBreaker.successCount, equals(0));
          expect(circuitBreaker.failureCount, equals(0));
        },
      );

      test('should transition back to open on failure', () async {
        // One successful call
        await circuitBreaker.execute(() async => 'success');
        expect(circuitBreaker.state, equals(CircuitBreakerState.halfOpen));
        expect(circuitBreaker.successCount, equals(1));

        // Then a failure should open the circuit
        try {
          await circuitBreaker.execute(() async => throw Exception('fail'));
        } catch (_) {}

        expect(circuitBreaker.state, equals(CircuitBreakerState.open));
        expect(circuitBreaker.successCount, equals(0));
      });
    });

    group('Reset functionality', () {
      test('should reset circuit breaker to initial state', () async {
        // Force circuit to open state
        for (int i = 0; i < 3; i++) {
          try {
            await circuitBreaker.execute(() async => throw Exception('fail'));
          } catch (_) {}
        }

        expect(circuitBreaker.state, equals(CircuitBreakerState.open));
        expect(circuitBreaker.failureCount, equals(3));

        // Reset should restore initial state
        circuitBreaker.reset();

        expect(circuitBreaker.state, equals(CircuitBreakerState.closed));
        expect(circuitBreaker.failureCount, equals(0));
        expect(circuitBreaker.successCount, equals(0));
      });
    });

    group('Generic type support', () {
      test('should handle different return types', () async {
        // String type
        final stringResult = await circuitBreaker.execute<String>(
          () async => 'text',
        );
        expect(stringResult, equals('text'));

        // Integer type
        final intResult = await circuitBreaker.execute<int>(() async => 42);
        expect(intResult, equals(42));

        // Map type
        final mapResult = await circuitBreaker.execute<Map<String, dynamic>>(
          () async => {'key': 'value'},
        );
        expect(mapResult, equals({'key': 'value'}));

        // List type
        final listResult = await circuitBreaker.execute<List<String>>(
          () async => ['a', 'b', 'c'],
        );
        expect(listResult, equals(['a', 'b', 'c']));
      });
    });

    group('toString method', () {
      test('should provide meaningful string representation', () {
        final description = circuitBreaker.toString();

        expect(description, contains('CircuitBreaker'));
        expect(description, contains('state: ${circuitBreaker.state}'));
        expect(
          description,
          contains('failures: ${circuitBreaker.failureCount}'),
        );
        expect(
          description,
          contains('successes: ${circuitBreaker.successCount}'),
        );
        expect(description, contains('threshold: ${circuitBreaker.threshold}'));
        expect(
          description,
          contains('halfOpenThreshold: ${circuitBreaker.halfOpenThreshold}'),
        );
      });
    });
  });

  group('CircuitOpenException', () {
    test('should create exception with message', () {
      const exception = CircuitOpenException('test message');

      expect(exception.message, equals('test message'));
      expect(exception.toString(), contains('CircuitOpenException'));
      expect(exception.toString(), contains('test message'));
    });
  });

  group('CircuitBreakerState enum', () {
    test('should have all expected values', () {
      expect(CircuitBreakerState.values, hasLength(3));
      expect(CircuitBreakerState.values, contains(CircuitBreakerState.closed));
      expect(CircuitBreakerState.values, contains(CircuitBreakerState.open));
      expect(
        CircuitBreakerState.values,
        contains(CircuitBreakerState.halfOpen),
      );
    });
  });

  group('Edge cases and stress tests', () {
    late CircuitBreaker testCircuitBreaker;

    setUp(() {
      testCircuitBreaker = CircuitBreaker(
        threshold: 3,
        timeout: const Duration(milliseconds: 100),
        halfOpenThreshold: 2,
      );
    });

    test('should handle rapid successive calls', () async {
      final futures = <Future<String>>[];

      // Create 10 concurrent calls
      for (int i = 0; i < 10; i++) {
        futures.add(
          testCircuitBreaker.execute(() async {
            await Future.delayed(const Duration(milliseconds: 10));
            return 'result $i';
          }),
        );
      }

      final results = await Future.wait(futures);
      expect(results, hasLength(10));
      expect(testCircuitBreaker.state, equals(CircuitBreakerState.closed));
    });

    test('should handle mixed success and failure patterns', () async {
      // Pattern: success, fail, success, fail, fail, fail (should open after 3rd fail)
      await testCircuitBreaker.execute(() async => 'success'); // success
      expect(testCircuitBreaker.failureCount, equals(0));

      try {
        await testCircuitBreaker.execute(() async => throw Exception('fail'));
      } catch (_) {} // fail 1
      expect(testCircuitBreaker.failureCount, equals(1));

      await testCircuitBreaker.execute(
        () async => 'success',
      ); // success (resets)
      expect(testCircuitBreaker.failureCount, equals(0));

      try {
        await testCircuitBreaker.execute(() async => throw Exception('fail'));
      } catch (_) {} // fail 1
      try {
        await testCircuitBreaker.execute(() async => throw Exception('fail'));
      } catch (_) {} // fail 2
      try {
        await testCircuitBreaker.execute(() async => throw Exception('fail'));
      } catch (_) {} // fail 3 - should open

      expect(testCircuitBreaker.state, equals(CircuitBreakerState.open));
    });

    test('should handle very short timeout periods', () async {
      final shortTimeoutCB = CircuitBreaker(
        threshold: 1,
        timeout: const Duration(milliseconds: 1),
        halfOpenThreshold: 1,
      );

      // Force open
      try {
        await shortTimeoutCB.execute(() async => throw Exception('fail'));
      } catch (_) {}

      expect(shortTimeoutCB.state, equals(CircuitBreakerState.open));

      // Wait for very short timeout
      await Future.delayed(const Duration(milliseconds: 5));

      // Should transition to half-open
      await shortTimeoutCB.execute(() async => 'success');
      expect(shortTimeoutCB.state, equals(CircuitBreakerState.closed));
    });
  });
}
