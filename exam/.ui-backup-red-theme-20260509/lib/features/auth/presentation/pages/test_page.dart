import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../app/services/api_service.dart';
import '../../../../app/dialogs.dart';

import 'calendar_page.dart';
import 'edit_profile_page.dart';
import 'home_page.dart';
import 'scan_page.dart';
import 'test_result_page.dart';

class TestPage extends StatefulWidget {
  const TestPage({super.key});
  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  static const double _kBarHeight = 64;
  static const double _kScanSize = 48;
  int _tab = 1;

  bool _loading = true;
  String? _error;

  List<_TestItem> _all = [];
  List<_TestItem> _items = [];

  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _query = '';
  String _subjectFilter = 'ทั้งหมด';
  late List<String> _subjectOptions = ['ทั้งหมด'];

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      setState(() => _query = _searchCtrl.text);
      _applyFilters();
    });
  }

  Future<void> _load() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final rows = await ApiService.myExams(limit: 200);

      _all = rows.map((e) {
        final dynamic rawPp = e["ppercent"] ?? e["passPercent"] ?? e["PPercent"];
        final double? d = (rawPp is num) ? rawPp.toDouble() : double.tryParse("$rawPp");
        final int passInt = (d ?? 60).round();

        final int id = int.tryParse("${e["id"] ?? e["quizId"] ?? 0}") ?? 0;
        final dynamic rawTerm = e["term"];
        final int term = (rawTerm is int) ? rawTerm : (int.tryParse("$rawTerm") ?? 0);
        final int year = (e["year"] is int) ? e["year"] as int : (int.tryParse("${e["year"]}") ?? 0);

        return _TestItem(
          id: id,
          code: (e["subjectNo"] ?? "").toString(),
          subject: (e["title"] ?? "โ€”").toString(),
          total: int.tryParse("${e["total"] ?? 0}") ?? 0,
          pass: passInt,
          term: term,
          year: year,
        );
      }).toList();

      final codes = <String>{};
      for (final t in _all) {
        final code = t.code.trim();
        if (code.isNotEmpty) codes.add(code);
      }
      _subjectOptions = [
        'ทั้งหมด',
        ...codes.toList()..sort((a, b) => a.compareTo(b))
      ];

      _applyFilters();
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = "$e";
      });
    }
  }

  void _applyFilters() {
    final q = _query.trim().toLowerCase();

    List<_TestItem> data = _all;

    if (_subjectFilter != 'ทั้งหมด') {
      data = data.where((t) => t.code == _subjectFilter).toList();
    }

    if (q.isNotEmpty) {
      data = data.where((t) {
        return t.code.toLowerCase().contains(q) ||
            t.subject.toLowerCase().contains(q);
      }).toList();
    }

    setState(() {
      _items = data;
    });
  }

  Future<void> _openAddExamSheet() async {
    final title = TextEditingController();
    final total = TextEditingController();
    final term = TextEditingController();
    final year = TextEditingController();
    final subj = TextEditingController();
    final ppCtrl = TextEditingController();

    final kinds = ['Pretest', 'Posttest', 'Midterm', 'Final', 'Other'];
    String? kind;
    bool submitEnabled = true;

    Future<void> submit() async {
      if (!submitEnabled) return;

      final t = title.text.trim();
      final tot = int.tryParse(total.text.trim());
      final tm = term.text.trim();
      final yr = int.tryParse(year.text.trim());
      final sj = subj.text.trim();
      final ppText = ppCtrl.text.trim();
      final pp = ppText.isEmpty ? null : double.tryParse(ppText);

      if (t.isEmpty || tot == null || tm.isEmpty || yr == null || sj.isEmpty) {
        await showInfoDialog(context, 'กรอกข้อมูลให้ครบ');
        return;
      }
      if (pp != null && (pp < 0 || pp > 100)) {
        await showInfoDialog(context, 'เกณฑ์ผ่าน (%) ต้องอยู่ระหว่าง 0–100');
        return;
      }

      try {
        submitEnabled = false;

        await ApiService.createExam(
          title: t,
          total: tot,
          term: tm,
          year: yr,
          subjectNo: sj,
          ppercent: pp,
          quizKind: kind,
        );

        if (!mounted) return;
        Navigator.pop(context);
        await showInfoDialog(context, 'เพิ่มข้อสอบแล้ว');
        await _load();
      } catch (e) {
        submitEnabled = true;
        if (!mounted) return;
        await showErrorDialog(context, '$e');
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, sbSet) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'เพิ่มข้อสอบใหม่',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _field('ชื่อข้อสอบ (Title)', controller: title),
                    const SizedBox(height: 10),
                    _field('SubjectNo', controller: subj),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _field('Term', controller: term)),
                        const SizedBox(width: 10),
                        Expanded(child: _field('Year', controller: year, number: true)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _field('จำนวนข้อ (Total)', controller: total, number: true),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E1320),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: kind,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF0E1320),
                          hint: const Text('ชนิดข้อสอบ (เลือกได้ถ้าต้องการ)',
                              style: TextStyle(color: Colors.white54)),
                          items: kinds
                              .map((k) => DropdownMenuItem(
                                    value: k,
                                    child: Text(k, style: const TextStyle(color: Colors.white)),
                                  ))
                              .toList(),
                          onChanged: (v) => sbSet(() => kind = v),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _field('เกณฑ์ผ่าน (%) - ไม่กรอกได้', controller: ppCtrl, number: true),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        onPressed: submit,
                        child: const Text('บันทึก'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _field(
    String hint, {
    required TextEditingController controller,
    bool number = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: const Color(0xFF0E1320),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: const BoxDecoration(
                color: Color(0xFF141A26),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text(
                        'ข้อสอบทั้งหมด',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'เพิ่มข้อสอบใหม่',
                        onPressed: _openAddExamSheet,
                        icon: const Icon(Icons.add, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Search + Filter
                  Row(
                    children: [
                      Expanded(
                        flex: 6,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF0E1320),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            children: [
                              const Icon(Icons.search, color: Colors.white70, size: 20),
                              const SizedBox(width: 6),
                              Expanded(
                                child: TextField(
                                  controller: _searchCtrl,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    hintText: 'ค้นหา: รหัสวิชา/ชื่อข้อสอบ',
                                    hintStyle: TextStyle(color: Colors.white54),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                              if (_query.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.white70, size: 20),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _query = '');
                                    _applyFilters();
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0E1320),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              dropdownColor: const Color(0xFF0E1320),
                              value: _subjectFilter,
                              items: _subjectOptions
                                  .map((s) => DropdownMenuItem<String>(
                                        value: s,
                                        child: Text(
                                          s,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: Colors.white),
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() => _subjectFilter = v);
                                _applyFilters();
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _ErrorBox(message: _error!, onRetry: _load)
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: _items.isEmpty
                              ? ListView(
                                  children: const [
                                    SizedBox(height: 60),
                                    Center(
                                      child: Text(
                                        'ไม่พบรายการที่ตรงเงื่อนไข',
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                                  itemCount: _items.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                                  itemBuilder: (context, i) {
                                    final t = _items[i];
                                    return _TestCard(
                                      item: t,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => TestResultPage(
                                              quizId: t.id,
                                              term: t.term,
                                              year: t.year,
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                        ),
            ),
          ],
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
                            MaterialPageRoute(
                              builder: (_) => const HomePage(token: ""),
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
                        onTap: () {},
                      ),
                    ),
                    SizedBox(
                      width: _kScanSize + 24,
                      child: Center(
                        child: InkResponse(
                          radius: _kScanSize,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ScanPage(),
                            ),
                          ),
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
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CalendarPage(),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _BarItem(
                        icon: Icons.person_rounded,
                        label: 'Profile',
                        active: _tab == 3,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EditProfilePage(),
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
              Text(
                "เกิดข้อผิดพลาด:\n$message",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: onRetry, child: const Text("ลองใหม่")),
            ],
          ),
        ),
      );
}

class _TestCard extends StatelessWidget {
  final _TestItem item;
  final VoidCallback onTap;
  const _TestCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black87, width: 2),
                ),
                child: const Center(
                  child: Icon(
                    Icons.description_outlined,
                    size: 28,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // เธเธทเนเธญเธเนเธญเธชเธญเธ
                    Text(
                      item.subject,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: Colors.black,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // เธฃเธซเธฑเธชเธงเธดเธเธฒ / เธเธณเธเธงเธเธเนเธญ / เน€เธเธ“เธ‘เน / เน€เธ—เธญเธก-เธเธต
                    Text(item.code,
                        style: const TextStyle(color: Colors.black87, fontSize: 12.5)),
                    Text('จำนวน ${item.total} ข้อ',
                        style: const TextStyle(color: Colors.black87, fontSize: 12.5)),
                    Text('จำนวน ${item.pass} %',
                        style: const TextStyle(color: Colors.black87, fontSize: 12.5)),
                    Text('จำนวน ${item.term} / ${item.year}',
                        style: const TextStyle(color: Colors.black54, fontSize: 12)),
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

class _TestItem {
  final int id;         // QuizID
  final String code;    // SubjectNo
  final String subject; // เธเธทเนเธญเธเนเธญเธชเธญเธ (title)
  final int total;
  final int pass;
  final int term;
  final int year;

  const _TestItem({
    required this.id,
    required this.code,
    required this.subject,
    required this.total,
    required this.pass,
    required this.term,
    required this.year,
  });
}

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


