import '../models/user.dart';
abstract class AuthRepository {
  Future<User> login({required String email, required String password});
  Future<void> signUp({required String name, required String email, required String phone, required String password});
  Future<void> sendResetEmail(String email);
  Future<User?> currentUser();
  Future<void> logout();
}
