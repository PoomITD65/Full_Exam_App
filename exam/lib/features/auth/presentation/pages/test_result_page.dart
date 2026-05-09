import 'package:demo/features/auth/presentation/pages/calendar_page.dart';
import 'package:demo/features/auth/presentation/pages/home_page.dart';
import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../app/dialogs.dart';
import '../../../../app/services/api_service.dart';
import 'package:demo/features/auth/presentation/pages/test_page.dart';
import 'package:demo/features/auth/presentation/pages/scan_page.dart';
import '../../presentation/pages/edit_profile_page.dart';
import '../../presentation/pages/test_detail_page.dart';

class TestResultPage extends StatefulWidget {
  const TestResultPage({
    super.key,
    this.quizId = 3,
    this.term = 2,
    this.year = 2566,
  });

  final int quizId;
  final int term;
  final int year;

  @override
  State<TestResultPage> createState() => _TestResultPageState();
}

class _TestResultPageState extends State<TestResultPage> {
  // bottom bar config
  static const double _kBarHeight = 64;
  static const double _kScanSize = 48;
  int _tab = 1;

  static const _red = kAccent;

  bool _loading = true;
  String? _error;

  // header summary
  String _subjectHeader = '';
  int _passScore = 0;
  int _totalQuestions = 0;
  double _passPercent = 0.0;

  // rows
  List<_ScoreRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      if (!mounted) return;
      setState(() {
        _loading = true;
        _error = null;
      });

      final data = await ApiService.examResults(
        quizId: widget.quizId,
        term: widget.term,
        year: widget.year,
      );

      final quiz = data['quiz'] as Map<String, dynamic>? ?? const {};
      final items = (data['items'] as List?) ?? const [];

      final rows = items.map<_ScoreRow>((e) {
        final studentId = (e['stdNo'] ??
                e['studentId'] ??
                e['StudentID'] ??
                e['student_no'] ??
                e['StudentCode'] ??
                '')
            .toString();
        final name =
            (e['name'] ?? e['studentName'] ?? e['Name'] ?? e['FullName'] ?? '')
                .toString();
        final score = (e['score'] as num?)?.toInt() ??
            int.tryParse('${e['Score'] ?? ''}') ??
            0;
        final checked = (e['checked'] as bool?) ?? (e['Checked'] == 1) ?? false;
        final rYear = (e['rYear'] as num?)?.toInt() ??
            int.tryParse('${e['rYear'] ?? ''}');
        final room = (e['room'] as num?)?.toInt() ??
            (e['Room'] as num?)?.toInt() ??
            int.tryParse('${e['room'] ?? e['Room'] ?? ''}');
        return _ScoreRow(
          studentId: studentId,
          name: name,
          score: score,
          checked: checked,
          rYear: rYear,
          room: room,
        );
      }).toList();

      rows.sort((a, b) => a.studentId.compareTo(b.studentId));

      if (!mounted) return;
      setState(() {
        _subjectHeader = '${quiz['title'] ?? 'ไม่ระบุชื่อชุดข้อสอบ'} '
            '(${quiz['subjectNo'] ?? '-'}) ';
        _passScore = (quiz['passScore'] as num?)?.toInt() ?? 0;
        _totalQuestions = (quiz['scoreTotal'] as num?)?.toInt() ?? 0;
        _passPercent = (quiz['passPercent'] as num?)?.toDouble() ?? 0.0;
        _rows = rows;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _openAnswerSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnswerSettingsPage(
          quizId: widget.quizId,
          term: widget.term,
          year: widget.year,
          subjectHeader: _subjectHeader,
          totalQuestions: _totalQuestions,
          passScore: _passScore,
          passPercent: _passPercent,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    if (_loading) {
      return const Scaffold(
        backgroundColor: kBg,
        body: Center(child: CircularProgressIndicator(color: kAccent)),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(
          backgroundColor: kBg,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kText),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('ผลคะแนน',
              style: TextStyle(color: _red, fontWeight: FontWeight.w900)),
          actions: [
            IconButton(
              tooltip: 'ตั้งค่าเฉลย',
              icon: const Icon(Icons.manage_search_rounded, color: kAccent),
              onPressed: _openAnswerSettings,
            ),
          ],
        ),
        body: Center(
          child: Text('? $_error', style: const TextStyle(color: kAccent)),
        ),
      );
    }

    final totalStudents = _rows.length;
    final passedCount = _rows.where((r) => r.score >= _passScore).length;
    final passedPercent =
        totalStudents == 0 ? 0 : (passedCount / totalStudents * 100);

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('ผลคะแนน',
            style: TextStyle(color: _red, fontWeight: FontWeight.w900)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(34),
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _subjectHeader,
                    style: const TextStyle(color: kSubtle),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'ผ่าน ${passedPercent.toStringAsFixed(1)}% จาก $totalStudents คน',
                  style: const TextStyle(color: kSubtle, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'ตั้งค่าเฉลย',
            icon: const Icon(Icons.manage_search_rounded, color: kAccent),
            onPressed: _openAnswerSettings,
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            children: [
              Expanded(
                child: _ScoreTable(
                  subject: _subjectHeader,
                  rows: _rows,
                  passScore: _passScore,
                  total: _totalQuestions,
                  quizId: widget.quizId,
                ),
              ),
            ],
          ),
        ),
      ),

      // ==== Bottom Navigation ====
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
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const HomePage(
                                    token:
                                        '')), // Replace empty string with actual token
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
                          Navigator.push(
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
                            Navigator.push(
                              context,
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
                            ),
                            child: const Icon(Icons.qr_code_scanner_rounded,
                                color: Colors.white, size: 26),
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
                          Navigator.push(
                            context,
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
                          Navigator.push(
                            context,
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

/* ---------------- Table Section ---------------- */

class _ScoreTable extends StatelessWidget {
  const _ScoreTable({
    required this.subject,
    required this.rows,
    required this.passScore,
    required this.total,
    required this.quizId,
  });

  final String subject;
  final List<_ScoreRow> rows;
  final int passScore;
  final int total;
  final int quizId;

  static const _red = kAccent;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: kCard,
        child: Column(
          children: [
            // Header (แสดงเสมอ)
            Container(
              color: _red,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: const Row(
                children: [
                  _Cell('รหัสนักเรียน',
                      flex: 20, bold: true, color: Colors.white),
                  _Cell('รายชื่อ', flex: 32, bold: true, color: Colors.white),
                  _Cell('คะแนนที่ได้',
                      flex: 16, bold: true, center: true, color: Colors.white),
                  _Cell('ห้อง',
                      flex: 16, bold: true, center: true, color: Colors.white),
                  _Cell('สถานะ',
                      flex: 16, bold: true, center: true, color: Colors.white),
                ],
              ),
            ),

            // Body
            Expanded(
              child: rows.isEmpty
                  ? Container(
                      color: Colors.white,
                      alignment: Alignment.center,
                      child: const Text(
                        'ไม่พบรายชื่อ',
                        style: TextStyle(color: kSubtle, fontSize: 13),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: rows.length,
                      separatorBuilder: (_, __) =>
                          Container(height: .7, color: kBorder),
                      itemBuilder: (context, i) {
                        final r = rows[i];
                        final pass = r.score >= passScore;

                        final statusText =
                            r.checked ? 'ตรวจแล้ว' : 'ยังไม่ตรวจ';
                        final statusColor = r.checked ? kSuccess : kAccent;

                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TestDetailPage(
                                  studentName: r.name,
                                  score: r.score,
                                  total: total,
                                  passScore: passScore,
                                ),
                                settings: RouteSettings(
                                  arguments: {
                                    'subject': subject,
                                    'studentId': r.studentId,
                                    'quizId': quizId,
                                  },
                                ),
                              ),
                            );
                          },
                          child: Container(
                            color: i.isEven ? kCard : kField,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            child: Row(
                              children: [
                                _Cell(r.studentId.isEmpty ? '—' : r.studentId,
                                    flex: 20),
                                _Cell(r.name.isEmpty ? '—' : r.name, flex: 32),
                                _Cell(
                                  '${r.score}',
                                  flex: 16,
                                  center: true,
                                  color: pass ? (Colors.green[700]) : _red,
                                ),
                                _Cell(r.roomText, flex: 16, center: true),
                                _Cell(statusText,
                                    flex: 16, center: true, color: statusColor),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Footer
            Container(
              color: kCard,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Text(
                'เกณฑ์ ${total == 0 ? 0 : ((passScore / total) * 100).round()}% จากทั้งหมด $total คะแนน',
                style: const TextStyle(color: kSubtle, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(
    this.text, {
    super.key,
    required this.flex,
    this.center = false,
    this.bold = false,
    this.color,
  });

  final String text;
  final int flex;
  final bool center;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: color ?? kText,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
      fontSize: 12,
      height: 1.0,
    );
    return Expanded(
      flex: flex,
      child: Align(
        alignment: center ? Alignment.center : Alignment.centerLeft,
        child: Text(text, style: style, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _ScoreRow {
  final String studentId;
  final String name;
  final int score;
  final bool checked;
  final int? rYear;
  final int? room;

  const _ScoreRow({
    required this.studentId,
    required this.name,
    required this.score,
    required this.checked,
    this.rYear,
    this.room,
  });

  String get roomText {
    final ry = rYear;
    final rm = room;
    if (ry == null || ry <= 0 || rm == null || rm <= 0) return '—';
    return '$ry/$rm';
  }
}

/* ---------------- Bottom Bar Item ---------------- */

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

/* ---------------- Answer Settings (ก ข ค ง จ) ---------------- */

class AnswerSettingsPage extends StatefulWidget {
  const AnswerSettingsPage({
    super.key,
    required this.quizId,
    required this.term,
    required this.year,
    required this.subjectHeader,
    required this.totalQuestions,
    required this.passScore,
    required this.passPercent,
  });

  final int quizId;
  final int term;
  final int year;
  final String subjectHeader;
  final int totalQuestions;
  final int passScore;
  final double passPercent;

  @override
  State<AnswerSettingsPage> createState() => _AnswerSettingsPageState();
}

class _AnswerSettingsPageState extends State<AnswerSettingsPage> {
  static const choices = ['ก', 'ข', 'ค', 'ง', 'จ']; // A–E
  late List<int?> answers; // index (0..4) ต่อข้อ, null = ยังไม่ตั้ง
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    answers = List<int?>.filled(widget.totalQuestions, null, growable: false);
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final rows = await ApiService.getChoices(widget.quizId);

      for (final r in rows) {
        // ดึงค่า no/answer ที่เป็นตัวเลขหรือ string
        final dynamic noRaw = r['no'];
        final dynamic ansRaw = r['answer'];

        final int? no = (noRaw is num)
            ? noRaw.toInt()
            : int.tryParse(noRaw?.toString() ?? '');

        final int? ans = (ansRaw is num)
            ? ansRaw.toInt()
            : int.tryParse(ansRaw?.toString() ?? '');

        if (no != null &&
            no >= 1 &&
            no <= answers.length &&
            ans != null &&
            ans >= 1 &&
            ans <= 5) {
          answers[no - 1] = ans - 1; // 1..5 -> index 0..4
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clearAll() {
    setState(() {
      for (var i = 0; i < answers.length; i++) answers[i] = null;
    });
  }

  Future<void> _save() async {
    try {
      setState(() {
        _saving = true;
      });
      for (var i = 0; i < answers.length; i++) {
        final idx = answers[i];
        if (idx == null) continue; // ข้อที่ยังไม่ตั้ง ข้าม
        final answerNum = idx + 1; // 1..5
        await ApiService.updateChoice(
          quizId: widget.quizId,
          no: i + 1,
          answer: answerNum,
          score: 1, // ตาม requirement: คะแนน/ข้อ = 1
          isUse: true, // ใช้งาน
        );
      }
      if (!mounted) return;
      await showInfoDialog(context, 'บันทึกเฉลยเรียบร้อย');
      Navigator.pop(context); // กลับไปหน้าเดิม
    } catch (e) {
      if (!mounted) return;
      await showErrorDialog(context, 'บันทึกล้มเหลว: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        title: const Text('ตั้งค่าเฉลย', style: TextStyle(color: kAccent)),
        actions: [
          IconButton(
            tooltip: 'ล้างทั้งหมด',
            icon: const Icon(Icons.delete_sweep_rounded, color: kAccent),
            onPressed: _saving ? null : _clearAll,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kAccent))
          : _error != null
              ? Center(
                  child: Text('เกิดข้อผิดพลาด:\n$_error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: kSubtle)))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: DefaultTextStyle(
                    style: const TextStyle(color: kSubtle),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.subjectHeader,
                            style: const TextStyle(
                                color: kText, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text('ข้อสอบทั้งหมด ${widget.totalQuestions} ข้อ   '
                            'เกณฑ์ผ่าน ${widget.passScore} คะแนน (${widget.passPercent}%)'),
                        const SizedBox(height: 12),
                        Expanded(
                          child: ListView.builder(
                            itemCount: widget.totalQuestions,
                            itemBuilder: (context, i) {
                              final selected = answers[i];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: kCard,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 56,
                                      child: Text('ข้อ ${i + 1}',
                                          style: const TextStyle(
                                              color: kAccent,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: List.generate(choices.length,
                                            (idx) {
                                          final active = selected == idx;
                                          return ChoiceChip(
                                            label: Text(choices[idx]),
                                            selected: active,
                                            labelStyle: TextStyle(
                                              color:
                                                  active ? Colors.white : kText,
                                              fontWeight: active
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                            ),
                                            selectedColor: kAccent,
                                            backgroundColor: kField,
                                            onSelected: _saving
                                                ? null
                                                : (_) {
                                                    setState(
                                                        () => answers[i] = idx);
                                                  },
                                          );
                                        }),
                                      ),
                                    ),
                                    if (selected != null) ...[
                                      const SizedBox(width: 8),
                                      IconButton(
                                        tooltip: 'ล้างข้อนี้',
                                        icon: const Icon(Icons.close_rounded,
                                            color: kSubtle),
                                        onPressed: _saving
                                            ? null
                                            : () => setState(
                                                () => answers[i] = null),
                                      )
                                    ]
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        SafeArea(
                          top: false,
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _saving ? null : _save,
                              icon: const Icon(Icons.save_rounded),
                              label: Text(
                                  _saving ? 'กำลังบันทึก...' : 'บันทึกเฉลย'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kAccent,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                textStyle: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
