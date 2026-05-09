// lib/features/auth/presentation/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:demo/app/services/api_service.dart';

import '../../../../app/app_theme.dart';
import 'calendar_page.dart';
import 'edit_profile_page.dart';
import 'scan_page.dart';
import 'test_page.dart';
import 'test_result_page.dart';
import 'notification_page.dart';

class HomePage extends StatefulWidget {
  /// ส่ง JWT token มาจากหน้า Login
  const HomePage({super.key, required String token});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const double _kBarHeight = 64;
  static const double _kScanSize = 48;

  int _tab = 0;

  bool _loading = true;
  String? _error;

  String _displayName = "—";
  int _examSets = 0;
  int _totalQuestions = 0;
  List<Map<String, dynamic>> _latest = const [];
  // monthly summary
  int _mUpdates = 0;
  int _mScored = 0;
  int _mActiveDays = 0;
  String _mLabel = '';

  String _monthName(int m) {
    const names = [
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
    return (m >= 1 && m <= 12) ? names[m] : '';
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      if (!mounted) return;
      setState(() {
        _loading = true;
        _error = null;
      });

      final me = await ApiService.me();
      final Map<String, dynamic> user = (me["user"] is Map<String, dynamic>)
          ? me["user"]
          : <String, dynamic>{};
      _displayName = (user["Name"] ?? user["name"] ?? "-").toString();

      final summary = await ApiService.examSummary();
      _examSets = (summary["sets"] ?? 0) as int;
      _totalQuestions = (summary["total_questions"] ?? 0) as int;

      final latest = await ApiService.latestExams(limit: 5);
      _latest = latest;

      // monthly summary using dailySummary endpoint
      final now = DateTime.now();
      final first = DateTime(now.year, now.month, 1);
      final last = DateTime(now.year, now.month + 1, 0);
      final daily = await ApiService.dailySummary(start: first, end: last);
      int sumUpd = 0, sumScored = 0, days = 0;
      for (final m in daily) {
        final upd = (m['updates'] as num?)?.toInt() ?? 0;
        final sc = (m['scored'] as num?)?.toInt() ?? 0;
        sumUpd += upd;
        sumScored += sc;
        if (upd > 0) days++;
      }
      _mUpdates = sumUpd;
      _mScored = sumScored;
      _mActiveDays = days;
      _mLabel = _monthName(now.month) + ' ${now.year}';

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "$e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorBox(message: _error!, onRetry: _loadAll)
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 15),
                        _HeaderCard(
                          name: _displayName,
                          onBellTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const NotificationPage()),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        const _HeroBanner(),
                        const SizedBox(height: 12),
                        _StatsRow(
                          examSets: _examSets,
                          totalQuestions: _totalQuestions,
                          onLeftTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const TestPage()),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        _MonthlySummaryPanel(
                          label: _mLabel,
                          totalUpdates: _mUpdates,
                          totalScored: _mScored,
                          activeDays: _mActiveDays,
                        ),
                        const SizedBox(height: 20),
                        _LatestUsagePanel(items: _latest),
                        const SizedBox(height: 20),
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
                        onTap: () => setState(() => _tab = 0),
                      ),
                    ),
                    Expanded(
                      child: _BarItem(
                        icon: Icons.assignment_rounded,
                        label: 'Test',
                        active: _tab == 1,
                        onTap: () {
                          Navigator.of(context).push(
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
                              MaterialPageRoute(
                                  builder: (_) => const ScanPage()),
                            );
                          },
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
                                builder: (_) => const CalendarPage()),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: _BarItem(
                        icon: Icons.person_rounded,
                        label: 'Profile',
                        active: _tab == 3,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const EditProfilePage()),
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
}

/// -------------------- Error Box --------------------
class _ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBox({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("เกิดข้อผิดพลาด:\n$message",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: kSubtle)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: onRetry, child: const Text("ลองใหม่")),
            ],
          ),
        ),
      );
}

/// -------------------- Header --------------------
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({this.onBellTap, required this.name});
  final VoidCallback? onBellTap;
  final String name;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: kAccent,
          fontWeight: FontWeight.w900,
          height: 1.0,
        );
    final nameStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: kText,
          fontWeight: FontWeight.w700,
          height: 1.0,
        );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
        boxShadow: kSoftShadow,
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 22,
            backgroundColor: kAccentSoft,
            child: Icon(Icons.person, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ยินดีต้อนรับ', style: titleStyle),
                const SizedBox(height: 2),
                Text(name,
                    style: nameStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onBellTap,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kAccentSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.notifications_active_rounded,
                color: kAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// -------------------- Banner --------------------
class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CalendarPage(initialSelected: DateTime.now()),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: SizedBox(
              height: 108,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 14,
                    child: Image.asset(
                      'assets/images/cover_placeholder.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child:
                            Icon(Icons.image_rounded, color: kSubtle, size: 40),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 11,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: kField,
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(28),
                          bottomRight: Radius.circular(28),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('ตรวจสอบสถิติ',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: kText,
                                      fontWeight: FontWeight.w900,
                                    )),
                            const SizedBox(height: 4),
                            Text('การใช้งานของคุณ',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                        color: kText,
                                        fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

/// -------------------- Helper --------------------
int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  return int.tryParse('$v') ?? 0;
}

int? _toNullableInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  return int.tryParse('$v');
}

/// -------------------- สถิติ --------------------
class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.examSets,
    required this.totalQuestions,
    this.onLeftTap,
  });

  final int examSets;
  final int totalQuestions;
  final VoidCallback? onLeftTap;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: _StatCard(
              title: 'จำนวนชุดข้อสอบ',
              value: '$examSets',
              unit: 'ชุด',
              onTap: onLeftTap,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: _IconNavCard(
              title: 'คลังข้อสอบ',
              icon: Icons.description_rounded,
            ),
          ),
        ],
      );
}

class _IconNavCard extends StatelessWidget {
  const _IconNavCard({
    super.key,
    required this.title,
    required this.icon,
  });

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const TestPage()));
          },
          child: Container(
            height: 82,
            decoration: BoxDecoration(
              color: kCard,
              border: Border.all(color: kBorder),
              boxShadow: kSoftShadow,
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 32, color: kAccent),
                const SizedBox(height: 6),
                Text(title,
                    style: const TextStyle(
                        color: kText,
                        fontWeight: FontWeight.w700,
                        height: 1.0)),
              ],
            ),
          ),
        ),
      );
}

class _StatCard extends StatelessWidget {
  final String title, value, unit;
  final VoidCallback? onTap;
  const _StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final valueStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
          color: kAccent,
          fontWeight: FontWeight.w900,
        );

    final labelStyle = const TextStyle(
        color: kText, fontWeight: FontWeight.w700, fontSize: 13);

    final child = Container(
      height: 82,
      decoration: BoxDecoration(
        color: kCard,
        border: Border.all(color: kBorder),
        boxShadow: kSoftShadow,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(title, style: labelStyle, textAlign: TextAlign.center),
          const Spacer(),
          Text('$value $unit', style: valueStyle),
        ],
      ),
    );

    return onTap == null
        ? child
        : Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: child,
            ),
          );
  }
}

/// -------------------- การใช้งานล่าสุด (Dynamic + Progress) --------------------
class _LatestUsagePanel extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const _LatestUsagePanel({super.key, required this.items});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          border: Border.all(color: kBorder),
          boxShadow: kSoftShadow,
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          children: [
            Row(
              children: [
                const Text('การใช้งานล่าสุด',
                    style: TextStyle(
                        color: kText,
                        fontWeight: FontWeight.w900,
                        fontSize: 16)),
                const Spacer(),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TestPage()));
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Text('ดูทั้งหมด',
                        style: TextStyle(
                            color: kSubtle, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child:
                    Text('ยังไม่มีการใช้งาน', style: TextStyle(color: kSubtle)),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(
                  height: 1,
                  thickness: 1,
                  color: kBorder,
                ),
                itemBuilder: (context, i) {
                  final e = items[i];

                  final title = (e["title"] ?? "—").toString();
                  final termInt = _toInt(e["term"]);
                  final yearInt = _toInt(e["year"]);
                  final tag = [
                    if (termInt != 0) "เทอม $termInt",
                    if (yearInt != 0) "$yearInt",
                  ].join(" / ");

                  final dateText = (e["createdAt"] ?? "").toString();
                  final quizId = _toInt(e["quizId"] ?? e["id"] ?? 0);

                  // ---- ใช้ฟิลด์จาก backend ใหม่: totalCandidates / checkedCount / pendingCount ----
                  // ถ้า totalCandidates เป็น null => ไม่รู้จำนวนทั้งหมด ให้โชว์ "ตรวจแล้ว X คน"
                  final int? totalCandidates =
                      _toNullableInt(e["totalCandidates"]);
                  final int checked = _toInt(e["checkedCount"]);
                  final int? pending = _toNullableInt(e["pendingCount"]);

                  final int total = totalCandidates ?? 0;
                  final int graded = checked;
                  final int remain = pending ??
                      ((totalCandidates != null) ? (total - graded) : 0);
                  final double prog = (totalCandidates != null && total > 0)
                      ? (graded / total)
                      : 0.0;

                  return _UsageTile(
                    title: title,
                    tag: tag,
                    date: dateText,
                    total: totalCandidates, // อนุญาต null
                    graded: graded,
                    remaining: (totalCandidates != null) ? remain : null,
                    progress: (totalCandidates != null) ? prog : null,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TestResultPage(
                            quizId: quizId,
                            term: termInt,
                            year: yearInt,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
          ],
        ),
      );
}

class _UsageTile extends StatelessWidget {
  final String title, tag, date;
  final int? total; // อนุญาต null
  final int graded;
  final int? remaining; // อนุญาต null
  final double? progress; // อนุญาต null
  final VoidCallback? onTap;

  const _UsageTile({
    super.key,
    required this.title,
    required this.tag,
    required this.date,
    required this.total,
    required this.graded,
    required this.remaining,
    required this.progress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasTotal = total != null && total! > 0;
    final int showRemaining = remaining ?? 0;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 40,
                decoration: BoxDecoration(
                  color: kAccent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // บรรทัดชื่อ + ชิป "เหลือ X" (ถ้าไม่มี total จะโชว์เป็น "ตรวจแล้ว X คน")
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: kText,
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        hasTotal
                            ? _RemainChip(remaining: showRemaining)
                            : _CheckedOnlyChip(checked: graded),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // บรรทัดรายละเอียด: วิชา/เทอม/ปี + วันที่
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tag,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(color: kSubtle, fontSize: 12.5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          date,
                          style: const TextStyle(
                              color: kSubtle,
                              fontWeight: FontWeight.w600,
                              fontSize: 11.5),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Progress bar + ตัวเลข (มีเฉพาะกรณีทราบ total)
                    if (hasTotal)
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (progress ?? 0).clamp(0.0, 1.0),
                                minHeight: 6,
                                backgroundColor: kBorder,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "$graded/$total",
                            style: const TextStyle(
                              color: kText,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      )
                    else
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "ตรวจแล้ว $graded คน",
                          style: const TextStyle(
                            color: kText,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RemainChip extends StatelessWidget {
  final int remaining;
  const _RemainChip({super.key, required this.remaining});

  @override
  Widget build(BuildContext context) {
    final bg = remaining > 0 ? kAccentSoft : const Color(0xFF103222);
    final fg = remaining > 0 ? kAccent : kSuccess;
    final label = remaining > 0 ? "เหลือ $remaining" : "ครบแล้ว";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w800,
          fontSize: 11.5,
        ),
      ),
    );
  }
}

class _CheckedOnlyChip extends StatelessWidget {
  final int checked;
  const _CheckedOnlyChip({super.key, required this.checked});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: kAccentSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kAccent.withOpacity(0.25)),
      ),
      child: Text(
        "ตรวจแล้ว $checked",
        style: const TextStyle(
          color: kAccent,
          fontWeight: FontWeight.w800,
          fontSize: 11.5,
        ),
      ),
    );
  }
}

/// -------------------- Monthly Summary Panel --------------------
class _MonthlySummaryPanel extends StatelessWidget {
  final String label;
  final int totalUpdates;
  final int totalScored;
  final int activeDays;
  const _MonthlySummaryPanel({
    super.key,
    required this.label,
    required this.totalUpdates,
    required this.totalScored,
    required this.activeDays,
  });

  @override
  Widget build(BuildContext context) {
    final pending = (totalUpdates - totalScored).clamp(0, totalUpdates);
    final ratio = totalUpdates == 0 ? 0.0 : (totalScored / totalUpdates);
    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: kBorder),
        boxShadow: kSoftShadow,
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month_rounded, color: kSubtle),
              const SizedBox(width: 6),
              Text('สรุปรายเดือน ($label)',
                  style: const TextStyle(
                      color: kText, fontWeight: FontWeight.w900, fontSize: 16)),
              const Spacer(),
              Text('$activeDays วันทำการ',
                  style: const TextStyle(
                      color: kSubtle, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _MiniStat(title: 'อัปเดตรวม', value: '$totalUpdates')),
              const SizedBox(width: 10),
              const SizedBox(width: 10),
              Expanded(child: _MiniStat(title: 'ค้าง', value: '$pending')),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: kBorder,
              valueColor: const AlwaysStoppedAnimation(kAccent),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String title;
  final String value;
  const _MiniStat({super.key, required this.title, required this.value});

  @override
  Widget build(BuildContext context) => Container(
        height: 64,
        decoration: BoxDecoration(
          color: kField,
          border: Border.all(color: kBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: kSubtle, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text(value,
                style: const TextStyle(
                    color: kAccent, fontWeight: FontWeight.w900, fontSize: 18)),
          ],
        ),
      );
}

/// -------------------- Bottom bar --------------------
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
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    TextStyle(color: color, fontSize: 12, fontWeight: weight)),
          ],
        ),
      ),
    );
  }
}
