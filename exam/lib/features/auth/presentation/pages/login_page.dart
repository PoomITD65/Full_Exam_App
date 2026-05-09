import 'package:flutter/material.dart';
import 'package:demo/app/services/api_service.dart';
import '../../../../app/dialogs.dart';
import '../../../../app/app_theme.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: kField,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        prefixIconColor: kSubtle,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final h = c.maxHeight;

            const double sidePad = 20;
            const double topGap = 100;
            final double logoSize = (w * 0.44).clamp(130, 170).toDouble();
            const double linkToForm = 10;
            const double fieldGap = 10;
            const double forgotToBtn = 14;
            final double bottomGap = (h * 0.03).clamp(20, 32).toDouble();

            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: sidePad),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: h - 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: topGap),

                      // โลโก้
                      Image.asset(
                        'assets/images/logo.png',
                        height: logoSize,
                        fit: BoxFit.contain,
                      ),

                      const Text(
                        'ลงชื่อเข้าใช้บัญชี',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 28, fontWeight: FontWeight.w900),
                      ),

                      const SizedBox(height: linkToForm),
                      Form(
                        key: _form,
                        child: Column(
                          children: [
                            // ชื่อผู้ใช้
                            Material(
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                              child: TextFormField(
                                controller: _username,
                                style: const TextStyle(color: kText),
                                keyboardType: TextInputType.emailAddress,
                                decoration: _fieldDecoration('ชื่อผู้ใช้')
                                    .copyWith(
                                        prefixIcon:
                                            const Icon(Icons.mail_outline)),
                              ),
                            ),
                            const SizedBox(height: fieldGap),

                            // รหัสผ่าน
                            Material(
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                              child: TextFormField(
                                controller: _password,
                                style: const TextStyle(color: kText),
                                obscureText: _obscure,
                                decoration:
                                    _fieldDecoration('รหัสผ่าน').copyWith(
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: kSubtle,
                                    ),
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: forgotToBtn),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          onPressed: () async {
                            FocusScope.of(context).unfocus();
                            try {
                              final data = await ApiService.login(
                                  _username.text.trim(), _password.text);
                              final token =
                                  (data['access_token'] as String?) ?? '';
                              if (token.isEmpty) {
                                throw Exception('No access token from server');
                              }
                              ApiService.setToken(token);

                              // ไปหน้า Home พร้อม token
                              if (!mounted) return;
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                    builder: (_) => HomePage(token: token)),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              await showErrorDialog(
                                  context, 'Login failed: $e');
                            }
                          },
                          child: const Text('เข้าสู่ระบบ'),
                        ),
                      ),

                      SizedBox(height: bottomGap),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
