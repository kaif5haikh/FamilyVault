enum FailureCode {
  validation,
  locked,
  unauthorized,
  conflict,
  storage,
  network,
  integrity,
  configuration,
}

/// Safe boundary errors contain curated messages, never raw SQL, tokens or input.
final class AppFailure implements Exception {
  const AppFailure(this.code, this.message);
  final FailureCode code;
  final String message;

  @override
  String toString() => 'AppFailure(${code.name})';
}
