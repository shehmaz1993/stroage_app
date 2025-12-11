

class NetworkFailureException implements Exception {
  final String message;
  final dynamic originalError;

  NetworkFailureException({
    required this.message,
    this.originalError
  });

  @override
  String toString() => 'NetworkFailureException: $message';
}