/// A Dart implementation of the Circuit Breaker pattern for fault tolerance.
///
/// The Circuit Breaker pattern is a design pattern used to detect failures
/// and encapsulates the logic of preventing a failure from constantly recurring,
/// during maintenance, temporary external system failure or unexpected system difficulties.
///
/// This library provides:
/// - `CircuitBreaker` class for wrapping potentially failing operations
/// - `CircuitBreakerState` enum representing the three states (Closed, Open, Half-Open)
/// - `CircuitOpenException` thrown when calls are rejected in the Open state
///
/// ## Usage
///
/// ```dart
/// import 'package:dart_circuit_breaker/dart_circuit_breaker.dart';
///
/// final circuitBreaker = CircuitBreaker(
///   threshold: 3,                              // Failures before opening
///   timeout: const Duration(seconds: 30),     // Time to stay open
///   halfOpenThreshold: 2,                     // Successes to close from half-open
/// );
///
/// try {
///   final result = await circuitBreaker.execute(() async {
///     // Your potentially failing operation here
///     return await someAsyncOperation();
///   });
///   print('Success: $result');
/// } on CircuitOpenException catch (e) {
///   print('Circuit is open: ${e.message}');
/// } catch (e) {
///   print('Operation failed: $e');
/// }
/// ```
library;

export 'src/circuit_breaker_base.dart';
