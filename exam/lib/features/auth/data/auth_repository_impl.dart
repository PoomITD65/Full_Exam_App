import '../domain/repositories/auth_repository.dart';
import '../domain/models/user.dart';
import 'sources/auth_api.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this.api);
  final AuthApi api;
  @override
  Future<User> login({required String email, required String password}) async {
    final dto = await api.postLogin(email,password);
    return User(id: dto['id'], name: dto['name'], email: dto['email']);
  }
  @override
  Future<void> signUp({required String name, required String email, required String phone, required String password}) =>
    api.postSignUp(name,email,phone,password);
  @override
  Future<void> sendResetEmail(String email)=> api.postForgot(email);
  @override
  Future<User?> currentUser() async { final me = await api.getMe(); return me==null?null:User(id: me['id'], name: me['name'], email: me['email']); }
  @override
  Future<void> logout()=> api.postLogout();
}
