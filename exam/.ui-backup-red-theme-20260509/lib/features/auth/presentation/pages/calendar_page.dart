// lib/features/auth/presentation/pages/calendar_page.dart
import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../app/services/api_service.dart';
import 'home_page.dart';
import 'scan_page.dart';
import 'test_page.dart';
import 'notification_page.dart';
import 'edit_profile_page.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, this.initialSelected});
  final DateTime? initialSelected;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  static const double _kBarHeight = 64;
  static const double _kScanSize = 48;
  int _tab = 2;

  late DateTime _selected;
  Map<DateTime, int> _dailyUpdates = {};
  bool _loadingSummary = false;
  String? _summaryError;

  List<Map<String, dynamic>> _breakdown = const [];
  bool _loadingBreakdown = false;
  String? _breakdownError;

  @override
  void initState() {
    super.initState();
    _selected = DateUtils.dateOnly(widget.initialSelected ?? DateTime.now());
    _loadDailySummaryForMonth(_selected);
    _loadBreakdownForDay(_selected);
  }

  String _formatDate(DateTime d) => '${d.day} ${_monthNames[d.month]} ${d.year}';
  static const _monthNames = [
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];

  Future<void> _loadDailySummaryForMonth(DateTime anyDay) async {
    final first = DateTime(anyDay.year, anyDay.month, 1);
    final last = DateTime(anyDay.year, anyDay.month + 1, 0);
    setState(() {
      _loadingSummary = true;
      _summaryError = null;
    });
    try {
      final items = await ApiService.dailySummary(start: first, end: last);
      final map = <DateTime, int>{};
      for (final it in items) {
        final s = (it['day'] ?? '').toString(); // expect YYYY-MM-DD
        final parts = s.split('-');
        if (parts.length >= 3) {
          final d = DateTime(
            int.tryParse(parts[0]) ?? first.year,
            int.tryParse(parts[1]) ?? first.month,
            int.tryParse(parts[2]) ?? 1,
          );
          map[DateUtils.dateOnly(d)] = (it['updates'] as num?)?.toInt() ?? 0;
        }
      }
      setState(() => _dailyUpdates = map);
    } catch (e) {
      setState(() => _summaryError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingSummary = false);
    }
  }

  Future<void> _loadBreakdownForDay(DateTime day) async {
    setState(() {
      _loadingBreakdown = true;
      _breakdownError = null;
    });
    try {
      final items = await ApiService.dailyBreakdown(day: DateUtils.dateOnly(day));
      setState(() => _breakdown = items);
    } catch (e) {
      setState(() => _breakdownError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingBreakdown = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF111827)),
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.redAccent,
              brightness: Brightness.dark,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final d = DateUtils.dateOnly(picked);
      setState(() => _selected = d);
      await _loadBreakdownForDay(d);
      // ถ้าเปลี่ยนเดือน ให้ดึงสรุปใหม่ของเดือนนั้น
      if (d.month != DateTime.now().month || d.year != DateTime.now().year) {
        await _loadDailySummaryForMonth(d);
      }
    }
  }

  InputDecoration _fieldDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: const Color(0xFF0E1320),
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
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 15),
              _HeaderCard(
                name: 'Test System',
                onBellTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NotificationPage()),
                  );
                },
              ),
              const SizedBox(height: 12),

              // แถววันที่ + ปุ่มเลื่อน
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          _formatDate(_selected),
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _roundIconBtn(Icons.chevron_left_rounded, onTap: () async {
                    final d = DateUtils.dateOnly(_selected.subtract(const Duration(days: 1)));
                    setState(() => _selected = d);
                    await _loadBreakdownForDay(d);
                  }),
                  const SizedBox(width: 8),
                  _roundIconBtn(Icons.chevron_right_rounded, onTap: () async {
                    final d = DateUtils.dateOnly(_selected.add(const Duration(days: 1)));
                    setState(() => _selected = d);
                    await _loadBreakdownForDay(d);
                  }),
                ],
              ),

              const SizedBox(height: 10),

              // สรุปต่อวันของเดือน (นับจำนวนอัปเดตของวันที่เลือก)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.insights_rounded, color: Colors.white70, size: 18),
                    const SizedBox(width: 8),
                    if (_summaryError != null)
                      Expanded(
                        child: Text(
                          'สรุปไม่สำเร็จ: $_summaryError',
                          style: const TextStyle(color: Colors.amberAccent),
                        ),
                      )
                    else ...[
                      Expanded(
                        child: Text(
                          'อัปเดตวันนี้: ' +
                              ((_dailyUpdates[DateUtils.dateOnly(_selected)] ?? 0)).toString() +
                              ' ครั้ง',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      if (_loadingSummary)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                        ),
                      IconButton(
                        tooltip: 'รีเฟรชสรุปเดือนนี้',
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                        onPressed: () => _loadDailySummaryForMonth(_selected),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // รายงานรายวัน (Breakdown ต่อชุดข้อสอบ)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'รายงานรายวัน',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    if (_breakdownError != null)
                      Text(
                        'โหลดข้อมูลไม่สำเร็จ: $_breakdownError',
                        style: const TextStyle(color: Colors.amberAccent),
                      )
                    else if (_loadingBreakdown)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(12.0),
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      )
                    else if (_breakdown.isEmpty)
                      const Text('ไม่มีรายการอัปเดต', style: TextStyle(color: Colors.white70))
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _breakdown.length,
                        separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 12),
                        itemBuilder: (context, i) {
                          final m = _breakdown[i];
                          final title = (m['title'] ?? '—').toString();
                          final updates = (m['updates'] as num?)?.toInt() ?? 0;
                          final scored = (m['scored'] as num?)?.toInt() ?? 0;
                          final pending = (m['pending'] as num?)?.toInt() ?? (updates - scored);
                          final ratio = updates == 0 ? 0.0 : (scored / updates);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text('อัปเดต $updates', style: const TextStyle(color: Colors.white70)),
                                  const SizedBox(width: 10),
                                  Text('คะแนนล่าสุด $scored', style: const TextStyle(color: Colors.greenAccent)),
                                  const SizedBox(width: 10),
                                  Text('ค้าง $pending', style: const TextStyle(color: Colors.amberAccent)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: ratio,
                                  minHeight: 6,
                                  backgroundColor: Colors.white24,
                                  valueColor: const AlwaysStoppedAnimation(Colors.redAccent),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      // Bottom bar
      bottomNavigationBar: keyboardOpen
          ? const SizedBox.shrink()
          : SafeArea(
              top: false,
              child: Container(
                height: _kBarHeight,
                decoration: const BoxDecoration(
                  color: Color(0xFF0E1320),
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
                          setState(() => _tab = 0);
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const HomePage(token: '')),
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
                          setState(() => _tab = 1);
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
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const ScanPage()),
                            );
                          },
                          child: Container(
                            width: _kScanSize,
                            height: _kScanSize,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
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
                              color: Color(0xFF0E1320),
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
                        onTap: () => setState(() => _tab = 2),
                      ),
                    ),
                    Expanded(
                      child: _BarItem(
                        icon: Icons.person_rounded,
                        label: 'Profile',
                        active: _tab == 3,
                        onTap: () {
                          setState(() => _tab = 3);
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const EditProfilePage()),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _roundIconBtn(IconData icon, {VoidCallback? onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, color: const Color(0xFF111827)),
        ),
      ),
    );
  }
}

/* ==================== Widgets ==================== */

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({this.onBellTap, required this.name});
  final VoidCallback? onBellTap;
  final String name;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Colors.redAccent,
          fontWeight: FontWeight.w900,
          height: 1.0,
        );
    final nameStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          height: 1.0,
        );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white24,
            child: Icon(Icons.person, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ยินดีต้อนรับ', style: titleStyle),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: nameStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onBellTap,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.notifications_active_rounded,
                color: Colors.redAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* -------- Bottom bar item -------- */
class _BarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _BarItem({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.white : Colors.white70;
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
