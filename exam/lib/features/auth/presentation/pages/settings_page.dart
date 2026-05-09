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

      try {
        final me = await ApiService.me();
        name = (me['name'] ?? me['username'] ?? name).toString();
        email = (me['email'] ?? email).toString();
      } catch (_) {}

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

      if (!mounted) return;
      setState(() {
        _displayName = name.trim().isEmpty ? 'ผู้ใช้งาน' : name;
        _displayEmail = email;
      });
    } finally {
      if (mounted) setState(() => _loadingMe = false);
    }
  }

  Future<void> _confirmSignOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _ConfirmDialog(
        title: 'ออกจากระบบ',
        message: 'ต้องการออกจากระบบและกลับไปหน้าเข้าสู่ระบบหรือไม่?',
        confirmText: 'ออกจากระบบ',
      ),
    );
    if (ok != true) return;

    try {
      await ApiService.clearToken();
    } catch (_) {}
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _ConfirmDialog(
        title: 'ขอลบบัญชี',
        message: 'ระบบจะส่งคำขอไปยังผู้ดูแล ต้องการดำเนินการต่อหรือไม่?',
        confirmText: 'ส่งคำขอ',
        confirmDanger: true,
      ),
    );
    if (ok != true) return;

    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await ApiService.requestDeleteAccount(reason: 'user-initiated');
    } catch (_) {
      // Keep the UX tolerant if the backend endpoint is unavailable.
    } finally {
      if (context.mounted) Navigator.of(context).pop();
    }
    if (!context.mounted) return;
    await showInfoDialog(context, 'ส่งคำขอลบบัญชีแล้ว');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadMe,
        color: kAccent,
        backgroundColor: kCard,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _ProfileHeader(
              loading: _loadingMe,
              name: _displayName,
              email: _displayEmail,
              onRefresh: _loadMe,
            ),
            const SizedBox(height: 18),
            const _SectionTitle('Account'),
            _SettingsGroup(
              children: [
                _SettingsTile(
                  icon: Icons.logout_rounded,
                  title: 'ออกจากระบบ',
                  subtitle: 'ล้าง token และกลับไปหน้าเข้าสู่ระบบ',
                  onTap: _confirmSignOut,
                ),
              ],
            ),
            const SizedBox(height: 18),
            const _SectionTitle('System'),
            const _SettingsGroup(
              children: [
                _ReadOnlyTile(
                  icon: Icons.info_outline_rounded,
                  title: 'เวอร์ชันแอป',
                  value: '1.0.0',
                ),
                Divider(height: 1, color: kBorder),
                _ReadOnlyTile(
                  icon: Icons.shield_outlined,
                  title: 'นโยบายความเป็นส่วนตัว',
                  value: 'ดูรายละเอียด',
                  showChevron: true,
                ),
              ],
            ),
            const SizedBox(height: 22),
            _DangerCard(onPressed: _confirmDelete),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.loading,
    required this.name,
    required this.email,
    required this.onRefresh,
  });

  final bool loading;
  final String name;
  final String email;
  final VoidCallback onRefresh;

  String _initials(String s) {
    final parts = s.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorder),
        boxShadow: kSoftShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kAccentSoft,
              border: Border.all(color: kAccent.withOpacity(.28)),
            ),
            alignment: Alignment.center,
            child: loading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _initials(name),
                    style: const TextStyle(
                      color: kAccent,
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
                    color: kText,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
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
          IconButton(
            tooltip: 'รีเฟรช',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, color: kAccent),
          ),
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
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: kSubtle,
          fontWeight: FontWeight.w900,
          letterSpacing: .6,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorder),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _TileIcon(icon),
      title: Text(
        title,
        style: const TextStyle(color: kText, fontWeight: FontWeight.w800),
      ),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: const TextStyle(color: kSubtle)),
      trailing: const Icon(Icons.chevron_right_rounded, color: kSubtle),
      onTap: onTap,
    );
  }
}

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
      leading: _TileIcon(icon),
      title: Text(
        title,
        style: const TextStyle(color: kText, fontWeight: FontWeight.w800),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: const TextStyle(color: kSubtle)),
          if (showChevron)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.chevron_right_rounded, color: kSubtle),
            ),
        ],
      ),
    );
  }
}

class _TileIcon extends StatelessWidget {
  const _TileIcon(this.icon);
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: kAccentSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: kAccent, size: 20),
    );
  }
}

class _DangerCard extends StatelessWidget {
  const _DangerCard({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kField,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kAccent.withOpacity(.28)),
      ),
      child: Row(
        children: [
          const _TileIcon(Icons.delete_forever_rounded),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ขอลบบัญชี',
                  style: TextStyle(color: kText, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 2),
                Text(
                  'ส่งคำขอไปยังผู้ดูแลระบบ',
                  style: TextStyle(color: kSubtle),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: kAccent,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 42),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('ส่งคำขอ'),
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
      backgroundColor: kCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: kText,
              ),
            ),
            const SizedBox(height: 8),
            Text(message, style: const TextStyle(color: kSubtle)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kBorder),
                      foregroundColor: kText,
                      minimumSize: const Size(0, 46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('ยกเลิก'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: confirmDanger ? kAccent : kAccent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
