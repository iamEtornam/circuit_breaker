# Circuit Breaker

A Dart implementation of the Circuit Breaker pattern for building resilient applications that can handle failures gracefully.

## Overview

The Circuit Breaker pattern is a design pattern used in software development to detect failures and encapsulate the logic of preventing a failure from constantly recurring during maintenance, temporary external system failure, or unexpected system difficulties.

## Features

- **Three States**: Closed, Open, and Half-Open states with automatic transitions
- **Configurable Thresholds**: Set failure thresholds and recovery requirements
- **Generic Type Support**: Works with any return type `T`
- **Comprehensive Error Handling**: Custom exceptions and proper error propagation
- **Thread-Safe**: Safe for concurrent usage
- **Well Tested**: Comprehensive test coverage including edge cases

## States

### Closed State
- **Normal Operation**: All calls pass through to the wrapped operation
- **Failure Tracking**: Counts consecutive failures
- **Transition**: Opens when failure count reaches the threshold

### Open State
- **Fail Fast**: All calls are immediately rejected with `CircuitOpenException`
- **No Execution**: The wrapped operation is not executed
- **Transition**: Automatically transitions to Half-Open after the timeout period

### Half-Open State
- **Limited Testing**: Allows calls through to test if the service has recovered
- **Success Tracking**: Counts successful calls
- **Transitions**:
  - To Closed: After enough successful calls (halfOpenThreshold)
  - To Open: Immediately on any failure

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  dart_circuit_breaker: ^0.0.1
```

## Usage

### Basic Usage

```dart
import 'package:dart_circuit_breaker/dart_circuit_breaker.dart';

// Create a circuit breaker
final circuitBreaker = CircuitBreaker(
  threshold: 3,                              // Open after 3 failures
  timeout: const Duration(seconds: 30),     // Stay open for 30 seconds
  halfOpenThreshold: 2,                     // Close after 2 successes in half-open
);

// Use the circuit breaker
try {
  final result = await circuitBreaker.execute(() async {
    // Your potentially failing operation here
    return await httpClient.get('https://api.example.com/data');
  });
  print('Success: $result');
} on CircuitOpenException catch (e) {
  print('Circuit is open: ${e.message}');
  // Handle the circuit being open (maybe use cached data)
} catch (e) {
  print('Operation failed: $e');
  // Handle other errors
}
```

### Advanced Usage

```dart
// HTTP Client with Circuit Breaker
class ResilientHttpClient {
  final CircuitBreaker _circuitBreaker;
  final HttpClient _httpClient;

  ResilientHttpClient({
    int threshold = 5,
    Duration timeout = const Duration(minutes: 1),
    int halfOpenThreshold = 3,
  }) : _circuitBreaker = CircuitBreaker(
         threshold: threshold,
         timeout: timeout,
         halfOpenThreshold: halfOpenThreshold,
       ),
       _httpClient = HttpClient();

  Future<String> get(String url) async {
    return await _circuitBreaker.execute(() async {
      final request = await _httpClient.getUrl(Uri.parse(url));
      final response = await request.close();
      
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      
      return await response.transform(utf8.decoder).join();
    });
  }

  void dispose() {
    _httpClient.close();
  }
}
```

### Database Operations

```dart
class DatabaseService {
  final CircuitBreaker _circuitBreaker = CircuitBreaker(
    threshold: 3,
    timeout: const Duration(seconds: 10),
    halfOpenThreshold: 2,
  );

  Future<List<User>> getUsers() async {
    return await _circuitBreaker.execute(() async {
      // Simulate database operation
      final connection = await Database.connect();
      try {
        return await connection.query('SELECT * FROM users');
      } finally {
        await connection.close();
      }
    });
  }
}
```

## Configuration

### Constructor Parameters

- **`threshold`** (required): Number of consecutive failures before opening the circuit
- **`timeout`** (required): Duration to keep the circuit open before transitioning to half-open
- **`halfOpenThreshold`** (required): Number of successful calls in half-open state needed to close the circuit

### State Monitoring

```dart
print('Current state: ${circuitBreaker.state}');
print('Failure count: ${circuitBreaker.failureCount}');
print('Success count: ${circuitBreaker.successCount}');
print('Circuit breaker info: $circuitBreaker');
```

### Manual Reset

```dart
// Manually reset the circuit breaker to closed state
circuitBreaker.reset();
```

## Error Handling

The circuit breaker provides specific error handling:

```dart
try {
  final result = await circuitBreaker.execute(yourOperation);
  // Handle success
} on CircuitOpenException catch (e) {
  // Circuit is open - implement fallback logic
  // e.g., return cached data, show cached content, etc.
} on TimeoutException catch (e) {
  // Operation timed out
} on NetworkException catch (e) {
  // Network-related errors
} catch (e) {
  // Other errors from your operation
}
```

## Best Practices

1. **Choose Appropriate Thresholds**: Set thresholds based on your service's characteristics and requirements
2. **Implement Fallbacks**: Always have a fallback strategy when the circuit is open
3. **Monitor Circuit State**: Log state transitions for debugging and monitoring
4. **Use Different Circuits**: Use separate circuit breakers for different external services
5. **Consider Timeout Values**: Set timeout values that allow sufficient time for service recovery

## Testing

The library includes comprehensive tests. Run them with:

```bash
dart test
```

## Example

Run the included example:

```bash
dart run example/circuit_breaker_example.dart
```

This example demonstrates:
- Normal operation in closed state
- Circuit opening due to failures
- Rejection of calls in open state
- Recovery process through half-open state
- Transition back to closed state

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
