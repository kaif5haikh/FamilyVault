import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Online identity never implies a locally unlocked or authorized vault.
enum AuthBoundary { unconfigured, signedOut, signedInLocked }

/// The shell remains disconnected until backend and local-unlock review passes.
/// A future composition root will supply a session controller here.
final authBoundaryProvider = Provider<AuthBoundary>(
  (ref) => AuthBoundary.unconfigured,
);
