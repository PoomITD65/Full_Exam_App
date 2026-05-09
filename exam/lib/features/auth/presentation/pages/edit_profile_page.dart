// lib/features/auth/presentation/pages/edit_profile_page.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../app/dialogs.dart';
import '../../../../app/services/api_service.dart';
import 'calendar_page.dart';
import 'home_page.dart';
import 'scan_page.dart';
import 'settings_page.dart';
import 'test_page.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  static const double _kBarHeight = 64;
  static const double _kScanSize = 48;
  final int _tab = 3;

  final _name = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _addr = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _photo;

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
      _lastName.text = ln;
      _name.text = "$fn $ln".trim();
      _phone.text = (p["Mobile"] ?? "").toString();
      _email.text = (p["Email"] ?? "").toString();
      _addr.text = (p["Address"] ?? "").toString();
      _photo = (p["Photo"] ?? p["photo"] ?? "").toString().trim();
    } catch (e) {
      if (!mounted) return;
      await showErrorDialog(context, "$e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
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
  }

  InputDecoration _field(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: kField,
      hintStyle: const TextStyle(color: kSubtle),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kAccent, width: 1.3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('My Profile'),
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                children: [
                  _ProfileHero(
                    name: _name.text.isEmpty ? 'ผู้ใช้งาน' : _name.text,
                    email: _email.text,
                    photo: _photo,
                  ),
                  const SizedBox(height: 16),
                  _FormCard(
                    title: 'ข้อมูลส่วนตัว',
                    children: [
                      TextField(
                        controller: _firstName,
                        style: const TextStyle(color: kText),
                        decoration: _field('ชื่อจริง', Icons.person_rounded),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _lastName,
                        style: const TextStyle(color: kText),
                        decoration: _field('นามสกุล', Icons.badge_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _FormCard(
                    title: 'ช่องทางติดต่อ',
                    children: [
                      TextField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: kText),
                        decoration: _field('XXX-XXX-XXXX', Icons.phone_rounded),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: kText),
                        decoration: _field(
                          'example@example.com',
                          Icons.alternate_email_rounded,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _addr,
                        minLines: 2,
                        maxLines: 4,
                        style: const TextStyle(color: kText),
                        decoration: _field(
                          'บ้านเลขที่/ซอย/ถนน/แขวง/อำเภอ/จังหวัด',
                          Icons.location_on_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _saveProfile,
                      icon: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(_saving ? 'กำลังบันทึก...' : 'บันทึกโปรไฟล์'),
                    ),
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
                  color: kField,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 12,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _BarItem(
                        icon: Icons.home_rounded,
                        label: 'Home',
                        active: _tab == 0,
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HomePage(token: ''),
                            ),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: _BarItem(
                        icon: Icons.assignment_rounded,
                        label: 'Test',
                        active: _tab == 1,
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const TestPage()),
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      width: _kScanSize + 24,
                      child: Center(
                        child: InkResponse(
                          radius: _kScanSize,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ScanPage()),
                          ),
                          child: Container(
                            width: _kScanSize,
                            height: _kScanSize,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: kAccent,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.qr_code_scanner_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
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
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const CalendarPage(),
                            ),
                          );
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

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.name,
    required this.email,
    required this.photo,
  });

  final String name;
  final String email;
  final String? photo;

  String _initials(String s) {
    final parts = s.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  String? _photoUrl() {
    final value = photo?.trim();
    if (value == null || value.isEmpty) return null;
    if (value.startsWith('data:image/')) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('/')) return '${ApiService.baseUrl}$value';
    if (value.contains('/') || value.contains('.')) {
      return '${ApiService.baseUrl}/$value';
    }
    return null;
  }

  Uint8List? _photoBytes() {
    final value = photo?.trim();
    if (value == null || value.isEmpty) return null;
    final base64Part = value.startsWith('data:image/')
        ? value.substring(value.indexOf(',') + 1)
        : value;
    try {
      return base64Decode(base64Part.replaceAll(RegExp(r'\s+'), ''));
    } catch (_) {
      return null;
    }
  }

  Widget _fallbackAvatar() {
    return Container(
      height: 72,
      width: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: kAccentSoft,
        border: Border.all(color: kAccentSoft),
      ),
      alignment: Alignment.center,
      child: Text(
        _initials(name),
        style: const TextStyle(
          color: kAccent,
          fontWeight: FontWeight.w900,
          fontSize: 22,
        ),
      ),
    );
  }

  Widget _avatar() {
    final url = _photoUrl();
    final bytes = _photoBytes();

    Widget image;
    if (url != null) {
      image = Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackAvatar(),
      );
    } else if (bytes != null) {
      image = Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackAvatar(),
      );
    } else {
      return _fallbackAvatar();
    }

    return Container(
      height: 72,
      width: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: kAccentSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: image,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kBorder),
        boxShadow: kSoftShadow,
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _avatar(),
              const Positioned(
                right: -2,
                bottom: -2,
                child: _CameraDot(),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'บัญชีผู้ใช้',
                  style: TextStyle(
                    color: kAccent,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kText,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email.isEmpty ? 'ยังไม่มีอีเมล' : email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kSubtle),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: kText,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _CameraDot extends StatelessWidget {
  const _CameraDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      width: 26,
      decoration: const BoxDecoration(color: kAccent, shape: BoxShape.circle),
      child: const Icon(Icons.photo_camera, size: 15, color: Colors.white),
    );
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? kAccent : kSubtle;
    final weight = active ? FontWeight.w700 : FontWeight.w500;
    return InkWell(
      onTap: onTap,
      child: SizedBox.expand(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 12, fontWeight: weight),
            ),
          ],
        ),
      ),
    );
  }
}
