// lib/features/auth/presentation/pages/settings_page.dart
import 'package:flutter/material.dart';
import '../../../../app/app_theme.dart';
import '../../../../app/dialogs.dart';
import '../../../../app/services/api_service.dart';
import 'login_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // ชื่อผู้ใช้ (ดึงจาก /auth/me ถ้ามี)
  String _displayName = 'ผู้ใช้งาน';
  String _displayEmail = '';

  bool _loadingMe = true;

  @override
  void initState() {
    super.initState();
    _loadMe();
  }

  Future<void> _loadMe() async {
    try {
      String name = _displayName;
      String email = _displayEmail;

      // 1) ดึงจาก /auth/me
      try {
        final me = await ApiService.me();
        name = (me['name'] ?? me['username'] ?? name).toString();
        email = (me['email'] ?? email).toString();
      } catch (_) {}

      // 2) ถ้ายังว่าง ลองดึงจาก /profile แล้วประกอบชื่อ-นามสกุล
      if (name.trim().isEmpty || name == 'ผู้ใช้งาน') {
        try {
          final p = await ApiService.getPersonProfile();
          final fn = (p['FName'] ?? '').toString();
          final ln = (p['LName'] ?? '').toString();
          final em = (p['Email'] ?? '').toString();
          final full = ('$fn $ln').trim();
          if (full.isNotEmpty) name = full;
          if (email.isEmpty && em.isNotEmpty) email = em;
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _displayName = name.isEmpty ? 'ผู้ใช้งาน' : name;
          _displayEmail = email;
        });
      }
    } finally {
      if (mounted) setState(() => _loadingMe = false);
    }
  }

  Future<void> _confirmSignOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'ออกจากระบบ',
        message: 'คุณต้องการออกจากระบบหรือไม่?',
        confirmText: 'ออกจากระบบ',
        confirmDanger: false,
      ),
    );
    if (ok == true) {
      // เคลียร์ token เผื่อไว้ และกลับหน้า Login
      try {
        await ApiService.clearToken();
      } catch (_) {}
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    }
  }

  Future<void> _confirmDelete() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'ยืนยันการลบบัญชี',
        message:
            'คุณต้องการลบบัญชีของคุณใช่หรือไม่?',
        confirmText: 'ขอลบบัญชี',
        confirmDanger: true,
      ),
    );
    if (ok == true) {
      // แสดงสถานะกำลังส่ง (จำลอง)
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      try {
        await ApiService.requestDeleteAccount(reason: 'user-initiated');
      } catch (_) {
        // เงียบไว้ (เดโม่)
      } finally {
        if (context.mounted) Navigator.of(context).pop(); // ปิด loading
      }
      if (!context.mounted) return;
      await showInfoDialog(context, 'ส่งคำขอลบบัญชีแล้ว');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: kBg,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadMe,
        color: Colors.white,
        backgroundColor: const Color(0xFF111827),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _ProfileHeader(
              loading: _loadingMe,
              name: _displayName,
              email: _displayEmail,
            ),
            const SizedBox(height: 16),

            // หมวด: บัญชี
            _SectionTitle('บัญชี'),
            _CardBlock(children: [
              _PlainTile(
                icon: Icons.logout_rounded,
                title: 'ออกจากระบบ',
                subtitle: 'กลับไปหน้าเข้าสู่ระบบ',
                iconColor: Colors.black87,
                onTap: _confirmSignOut,
              ),
            ]),
            const SizedBox(height: 16),

            const SizedBox(height: 16),

            // หมวด: เกี่ยวกับระบบ
            _SectionTitle('เกี่ยวกับระบบ'),
            _CardBlock(children: const [
              _ReadOnlyTile(
                icon: Icons.info_outline_rounded,
                title: 'เวอร์ชันแอป',
                value: '1.0.0',
              ),
              Divider(height: 1, color: Color(0xFFECECEC)),
              _ReadOnlyTile(
                icon: Icons.shield_outlined,
                title: 'นโยบายความเป็นส่วนตัว',
                value: 'ดูรายละเอียด',
                showChevron: true,
              ),
            ]),
            const SizedBox(height: 20),
            
            const SizedBox(height: 20),
            // ปุ่มอันตราย (แยกชัดเจน)
            _DangerCard(
              title: 'ขอลบบัญชี',
              subtitle: 'ส่งคำขอไปยังผู้ดูแลระบบเพื่อลบบัญชีของคุณ ',
              buttonText: 'ขอลบบัญชี',
              onPressed: _confirmDelete,
            ),
          ],
        ),
      ),
    );
  }
}

/* ======================= Widgets ======================= */

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.loading,
    required this.name,
    required this.email,
  });

  final bool loading;
  final String name;
  final String email;

  String _initials(String s) {
    final parts = s.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) {
      return parts.first.isEmpty ? 'U' : parts.first.characters.first.toUpperCase();
    }
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white24,
            child: loading
                ? const SizedBox(
                    height: 22, width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                  )
                : Text(
                    _initials(name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loading ? 'กำลังโหลด...' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email.isEmpty ? '—' : email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              tooltip: 'รีเฟรชข้อมูล',
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: () {
                final st = context.findAncestorStateOfType<_SettingsPageState>();
                st?._loadMe();
              },
            ),
          )
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: Colors.white70,
        fontWeight: FontWeight.w800,
        letterSpacing: .6,
      ),
    );
  }
}

class _CardBlock extends StatelessWidget {
  const _CardBlock({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(top: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(children: children),
    );
  }
}

class _PlainTile extends StatelessWidget {
  const _PlainTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.iconColor, this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? Colors.black87),
      title: Text(title,
          style: const TextStyle(
              color: Colors.black, fontWeight: FontWeight.w800)),
      subtitle:
          subtitle == null ? null : Text(subtitle!, style: const TextStyle(color: Colors.black54)),
      trailing: trailing,
      onTap: onTap,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
    );
  }
}

// (ลบส่วนการใช้งานออกแล้ว)

class _ReadOnlyTile extends StatelessWidget {
  const _ReadOnlyTile({
    required this.icon,
    required this.title,
    required this.value,
    this.showChevron = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.black87),
      title: Text(title,
          style: const TextStyle(
              color: Colors.black, fontWeight: FontWeight.w800)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: const TextStyle(color: Colors.black54)),
          if (showChevron)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.chevron_right_rounded, color: Colors.black45),
            ),
        ],
      ),
    );
  }
}

class _DangerCard extends StatelessWidget {
  const _DangerCard({
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kField,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 42),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
            onPressed: onPressed,
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmText,
    this.confirmDanger = false,
  });

  final String title;
  final String message;
  final String confirmText;
  final bool confirmDanger;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: kField,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
            const SizedBox(height: 8),
            Text(message, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white30),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 46),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('ยกเลิก'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          confirmDanger ? Colors.redAccent : kAccent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 46),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(confirmText),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
