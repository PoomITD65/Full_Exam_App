// lib/features/auth/presentation/pages/edit_profile_page.dart
import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../app/services/api_service.dart';
import '../../../../app/dialogs.dart';
import '../../presentation/pages/settings_page.dart';

import '../../presentation/pages/calendar_page.dart';
import '../../presentation/pages/scan_page.dart';
import '../../presentation/pages/test_page.dart';
import '../../presentation/pages/home_page.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  static const double _kBarHeight = 64;
  static const double _kScanSize  = 48;
  final int _tab = 3;

  // Controllers
  final _name      = TextEditingController();      // เนเธชเธ”เธเธเธทเนเธญเธฃเธงเธก
  final _firstName = TextEditingController();
  final _lastName  = TextEditingController();
  final _phone     = TextEditingController();
  final _email     = TextEditingController();
  final _addr      = TextEditingController();

  bool _noti = true;
  bool _loading = true;
  bool _saving  = false;

  @override
  void initState() {
    super.initState();
    _loadPerson();
  }

  @override
  void dispose() {
    _name.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _email.dispose();
    _addr.dispose();
    super.dispose();
  }

  Future<void> _loadPerson() async {
    try {
      setState(() => _loading = true);
      final p = await ApiService.getPersonProfile();
      final fn = (p["FName"] ?? "").toString();
      final ln = (p["LName"] ?? "").toString();
      _firstName.text = fn;
      _lastName.text  = ln;
      _name.text      = "$fn $ln".trim();
      _phone.text     = (p["Mobile"] ?? "").toString();
      _email.text     = (p["Email"]  ?? "").toString();
      _addr.text      = (p["Address"] ?? "").toString();
    } catch (e) {
      if (!mounted) return;
      await showErrorDialog(context, "$e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static const _red    = Color(0xFFE01C1C);
  static const _green  = Color(0xFF2ECC71);
  static const _fieldBg = Colors.black;
  static const _fieldFg = Colors.white;

  InputDecoration _field(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: _fieldBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
            },
          ),
        ],
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                children: [
                  // เธเธฒเธฃเนเธ”เนเธ”เธ + Avatar
                  Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 48),
                        padding: const EdgeInsets.fromLTRB(18, 70, 18, 18),
                        decoration: BoxDecoration(
                          color: _red,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('ตั้งค่าบัญชีผู้ใช้',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                            const SizedBox(height: 10),

                            const Text('ชื่อ (ไทย)',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            TextField(controller: _firstName, style: const TextStyle(color: _fieldFg), decoration: _field('ชื่อจริง')),
                            const SizedBox(height: 10),

                            const Text('นามสกุล (ไทย)',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            TextField(controller: _lastName, style: const TextStyle(color: _fieldFg), decoration: _field('นามสกุล')),
                            const SizedBox(height: 14),

                            const Text('โทรศัพท์',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            TextField(controller: _phone, keyboardType: TextInputType.phone,
                                style: const TextStyle(color: _fieldFg), decoration: _field('XXX-XXX-XXXX')),
                            const SizedBox(height: 14),

                            const Text('ที่อยู่อีเมล',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            TextField(controller: _email, keyboardType: TextInputType.emailAddress,
                                style: const TextStyle(color: _fieldFg), decoration: _field('example@example.com')),
                            const SizedBox(height: 14),

                            const Text('ที่อยู่',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            TextField(controller: _addr,
                                style: const TextStyle(color: _fieldFg),
                                decoration: _field('บ้านเลขที่/ซอย/ถนน/แขวง/อำเภอ/จังหวัด')),
                            const SizedBox(height: 14),

                            const SizedBox(height: 14),

                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                                onPressed: _saving ? null : () async {
                                  try {
                                    setState(() => _saving = true);
                                    final person = await ApiService.updatePersonProfile(
                                      fName: _firstName.text.trim().isEmpty ? null : _firstName.text.trim(),
                                      lName: _lastName.text.trim().isEmpty ? null : _lastName.text.trim(),
                                      mobile: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
                                      email: _email.text.trim().isEmpty ? null : _email.text.trim(),
                                      address: _addr.text.trim().isEmpty ? null : _addr.text.trim(),
                                    );
                                    if (!mounted) return;
                                    _name.text = "${person["FName"] ?? ""} ${person["LName"] ?? ""}".trim();
                                    await showInfoDialog(context, 'อัปเดตโปรไฟล์สำเร็จ');
                                  } catch (e) {
                                    if (!mounted) return;
                                    await showErrorDialog(context, "$e");
                                  } finally {
                                    if (mounted) setState(() => _saving = false);
                                  }
                                },
                                child: _saving
                                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Text('อัปเดตโปรไฟล์'),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),

                      const SizedBox(
                        height: 96,
                        width: 96,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              radius: 48,
                              backgroundColor: Colors.white,
                              child: CircleAvatar(
                                radius: 44,
                                backgroundColor: Colors.black26,
                                child: Icon(Icons.person, size: 48, color: Colors.white),
                              ),
                            ),
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: _CameraDot(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

      bottomNavigationBar: keyboardOpen
          ? const SizedBox.shrink()
          : SafeArea(
              top: false,
              child: Container(
                height: _kBarHeight,
                decoration: const BoxDecoration(
                  color: Color(0xFF0E1320),
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, -4))],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _BarItem(
                        icon: Icons.home_rounded,
                        label: 'Home',
                        active: _tab == 0,
                        onTap: () {
                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage(token: '')));
                        },
                      ),
                    ),
                    Expanded(
                      child: _BarItem(
                        icon: Icons.assignment_rounded,
                        label: 'Test',
                        active: _tab == 1,
                        onTap: () {
                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const TestPage()));
                        },
                      ),
                    ),
                    SizedBox(
                      width: _kScanSize + 24,
                      child: Center(
                        child: InkResponse(
                          radius: _kScanSize,
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScanPage())),
                          child: Container(
                            width: _kScanSize, height: _kScanSize,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle, color: Colors.white,
                              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
                            ),
                            child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF0E1320), size: 26),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _BarItem(
                        icon: Icons.calendar_month_rounded,
                        label: 'Calendar',
                        active: _tab == 2,
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalendarPage()));
                        },
                      ),
                    ),
                    Expanded(
                      child: _BarItem(
                        icon: Icons.person_rounded,
                        label: 'Profile',
                        active: _tab == 3,
                        onTap: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _CameraDot extends StatelessWidget {
  const _CameraDot({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28, width: 28,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: const Icon(Icons.photo_camera, size: 16, color: Colors.black87),
    );
  }
}

class _BarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _BarItem({super.key, required this.icon, required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final color  = active ? Colors.white : Colors.white70;
    final weight = active ? FontWeight.w700 : FontWeight.w500;
    return InkWell(
      onTap: onTap,
      child: SizedBox.expand(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontSize: 12, fontWeight: weight)),
          ],
        ),
      ),
    );
  }
}


