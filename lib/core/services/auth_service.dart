import 'package:firebase_auth/firebase_auth.dart';

import 'connectivity_service.dart';
import '../utils/app_result.dart';

class AuthService {
  AuthService({
    required FirebaseAuth firebaseAuth,
    required ConnectivityService connectivityService,
  })  : _firebaseAuth = firebaseAuth,
        _connectivityService = connectivityService;

  final FirebaseAuth _firebaseAuth;
  final ConnectivityService _connectivityService;

  User? get currentUser => _firebaseAuth.currentUser;

  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();

  Future<AppResult<void>> login({
    required String email,
    required String password,
  }) async {
    try {
      if (!await _connectivityService.isOnline()) {
        return AppResult.failure<void>(
          const AppError(
            message: 'No internet connection',
            type: AppErrorType.network,
          ),
        );
      }

      await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return AppResult.success<void>(null);
    } on FirebaseAuthException catch (e) {
      return AppResult.failure<void>(
        AppError(
          message: _mapAuthError(e.code),
          type: AppErrorType.authentication,
        ),
      );
    } catch (_) {
      return AppResult.failure<void>(
        const AppError(
          message: 'Unexpected login error.',
          type: AppErrorType.authentication,
        ),
      );
    }
  }

  Future<AppResult<void>> register({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      if (!await _connectivityService.isOnline()) {
        return AppResult.failure<void>(
          const AppError(
            message: 'No internet connection',
            type: AppErrorType.network,
          ),
        );
      }

      final UserCredential credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      await credential.user?.updateDisplayName(username.trim());
      await credential.user?.reload();

      return AppResult.success<void>(null);
    } on FirebaseAuthException catch (e) {
      return AppResult.failure<void>(
        AppError(
          message: _mapAuthError(e.code),
          type: AppErrorType.authentication,
        ),
      );
    } catch (_) {
      return AppResult.failure<void>(
        const AppError(
          message: 'Unexpected registration error.',
          type: AppErrorType.authentication,
        ),
      );
    }
  }

  Future<void> logout() async {
    await _firebaseAuth.signOut();
  }

  String _mapAuthError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Invalid email format.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'This email is already in use.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'network-request-failed':
        return 'No internet connection.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}
