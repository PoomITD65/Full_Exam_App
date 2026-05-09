class AuthApi {
  Future<Map<String,dynamic>> postLogin(String email,String pass) async =>
    {'id':'1','name':'Demo','email':email};
  Future<void> postSignUp(String n,String e,String p,String pw) async {}
  Future<void> postForgot(String email) async {}
  Future<Map<String,dynamic>?> getMe() async => null;
  Future<void> postLogout() async {}
}
