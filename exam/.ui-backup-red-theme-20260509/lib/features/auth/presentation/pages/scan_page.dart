// lib/features/auth/presentation/pages/scan_page.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../app/app_theme.dart';
import '../../../../app/services/api_service.dart';
import '../../../../app/dialogs.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

/// เนเธเธฃเธเธชเธฃเนเธฒเธเธเธธเธ”เธเนเธญเธชเธญเธเธ—เธตเนเธเธนเนเนเธเนเธฃเธฑเธเธเธดเธ”เธเธญเธ
class _QuizSet {
  final int quizId;
  final String title;
  final int term;
  final int year;
  final String? subjectNo;

  const _QuizSet({
    required this.quizId,
    required this.title,
    required this.term,
    required this.year,
    this.subjectNo,
  });

  String get label => '$title (T$term/$year)';
}

class _ScanPageState extends State<ScanPage> {
  List<_QuizSet> _sets = const [];
  int _selectedIndex = 0;
  bool _loadingSets = true;
  String? _setsError;

  _QuizSet? get _selectedSet =>
      (_sets.isEmpty || _selectedIndex < 0 || _selectedIndex >= _sets.length)
          ? null
          : _sets[_selectedIndex];

  CameraController? _camera;
  Future<void>? _initCam;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _initCamera();
    }
    _loadMyExamSets();
  }

// โหลดชุดข้อสอบที่ผู้ใช้นี้รับผิดชอบ
  Future<void> _loadMyExamSets() async {
    setState(() {
      _loadingSets = true;
      _setsError = null;
    });
    try {
      final items = await ApiService.myExams(limit: 100);
      Object? g(Map m, String k) =>
          m[k] ?? m[k.toLowerCase()] ?? m[k.toUpperCase()];
      final parsed = <_QuizSet>[];
      for (final it in items) {
        final qid = int.tryParse('${g(it, "QuizID") ?? g(it, "quizId") ?? g(it, "id")}') ?? -1;
        if (qid <= 0) continue;
        final title = '${g(it, "Title") ?? g(it, "name") ?? "Untitled"}';
        final term = int.tryParse('${g(it, "Term") ?? 0}') ?? 0;
        final year = int.tryParse('${g(it, "Year") ?? 0}') ?? 0;
        final subjectNo = g(it, "SubjectNo")?.toString();
        parsed.add(_QuizSet(
          quizId: qid,
          title: title,
          term: term,
          year: year,
          subjectNo: subjectNo,
        ));
      }

      setState(() {
        _sets = parsed;
        _selectedIndex = _sets.isNotEmpty ? 0 : -1;
        _loadingSets = false;
        if (_sets.isEmpty) {
          _setsError = 'ยังไม่พบชุดข้อสอบที่คุณรับผิดชอบ';
        }
      });
    } catch (e) {
      setState(() {
        _loadingSets = false;
        _setsError = 'ดึงชุดข้อสอบไม่สำเร็จ: $e';
      });
    }
  }

  Future<void> _initCamera() async {
    try {
      if (kIsWeb) return; // เนเธกเนเน€เธเธดเธ”เธเธฅเนเธญเธ live เธเธเน€เธงเนเธ เนเธซเนเนเธเนเธเธธเนเธกเธ–เนเธฒเธข/เธญเธฑเธเนเธซเธฅเธ”เนเธ—เธ
      final cams = await availableCameras();
      final back = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      final controller = CameraController(back, ResolutionPreset.medium, enableAudio: false);
      _camera = controller;
      _initCam = controller.initialize();
      await _initCam;
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Camera init error: $e');
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _camera?.dispose();
    super.dispose();
  }

  // ====== ACTIONS ======
  Future<void> _takePhoto() async {
    if (kIsWeb || _camera == null || !_camera!.value.isInitialized) {
        // เว็บ/อุปกรณ์ที่กล้อง live ใช้ไม่ได้: เปิดกล้องผ่าน ImagePicker
      try {
        final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 90);
        if (x != null) {
          await _uploadXFile(x);
        } else {
          _showSnack('ไม่ได้ถ่ายภาพ');
        }
      } catch (e) {
        _showSnack('เปิดกล้องไม่สำเร็จ: $e');
      }
      return;
    }
    if (_selectedSet == null) {
      _showSnack('ยังไม่มีชุดข้อสอบที่เลือก');
      return;
    }

    try {
      final shot = await _camera!.takePicture();
      await _uploadXFile(shot);
    } catch (e) {
      _showSnack('ถ่ายไม่สำเร็จ: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    if (_selectedSet == null) {
      _showSnack('ยังไม่มีชุดข้อสอบที่เลือก');
      return;
    }
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 92);
      if (x != null) await _uploadXFile(x);
    } catch (e) {
      _showSnack('เเปิดแกลเลอรีไม่สำเร็จ: $e');
    }
  }

  Future<void> _uploadXFile(XFile xfile) async {
    if (_uploading) return;
    final set = _selectedSet!;
    setState(() => _uploading = true);
    // show blocking loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1F2430),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('แจ้งเตือน', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: Row(
          children: const [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 10),
            Expanded(child: Text('กำลังอัปโหลดภาพและตรวจ...', style: TextStyle(color: Colors.white70))),
          ],
        ),
      ),
    );

    try {
      Map<String, dynamic> res;
      if (kIsWeb) {
        final bytes = await xfile.readAsBytes();
        res = await ApiService.uploadOmr(
          quizId: set.quizId,
          term: set.term,
          year: set.year,
          bytes: bytes,
          filename: xfile.name,
        );
      } else {
        res = await ApiService.uploadOmr(
          quizId: set.quizId,
          term: set.term,
          year: set.year,
          filePath: xfile.path,
        );
      }

      final std = res['student_id'] ?? res['studentId'] ?? '-';
      final cls = res['classNo'] ?? res['class_no'] ?? '-';
      final score = res['score'] ?? 'ยังไม่คำนวณ';
      final total = res['total'];
      final answered = res['answered_count'];
      final correct = res['correct_count'];
      final idValid = res['student_id_valid'] != false;
      final scoreText = total == null ? '$score' : '$score/$total';
      final detailText = (answered == null && correct == null)
          ? ''
          : ' อ่านได้ ${answered ?? '-'} ข้อ ถูก ${correct ?? '-'} ข้อ';
      final idWarning = idValid ? '' : ' (เลขประจำตัวฝนซ้อน/ไม่ชัด)';
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      await showInfoDialog(
        context,
        'ตรวจสำเร็จ: รหัสนักเรียน $std$idWarning ห้อง $cls คะแนน $scoreText$detailText',
      );

    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      await showErrorDialog(context, 'เกิดข้อผิดพลาด: $e');
    } finally {
      setState(() => _uploading = false);
    }
  }

  Future<void> _showSnack(String text) async {
    await showInfoDialog(context, text);
  }

  void _chooseSet() async {
    if (_loadingSets) return;
    if (_setsError != null) {
      _showSnack(_setsError!);
      return;
    }
    final chosen = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              const Text('เลือกชุดข้อสอบ',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
              const SizedBox(height: 8),
              for (int i = 0; i < _sets.length; i++)
                RadioListTile<int>(
                  value: i,
                  groupValue: _selectedIndex,
                  onChanged: (v) => Navigator.pop(context, v),
                  title: Text(_sets[i].label,
                      style: const TextStyle(color: Colors.white)),
                  subtitle: (_sets[i].subjectNo == null)
                      ? null
                      : Text('รหัสวิชา: ${_sets[i].subjectNo}',
                          style: const TextStyle(color: Colors.white54)),
                  activeColor: Colors.redAccent,
                ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
    if (chosen != null && chosen != _selectedIndex) {
      setState(() => _selectedIndex = chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: kBg,
          appBar: AppBar(
            backgroundColor: kBg,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
            centerTitle: true,
            title: const Text('ตรวจข้อสอบ',
                style: TextStyle(
                    color: Color(0xFFE01C1C), fontWeight: FontWeight.w900)),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(46),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: (_loadingSets)
                          ? const Text('กำลังโหลดชุดข้อสอบ...',
                              style: TextStyle(color: Colors.white70))
                          : (_selectedSet != null)
                              ? Text('ชุดที่เลือก: ${_selectedSet!.label}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white70))
                              : const Text('ยังไม่พบชุดข้อสอบของคุณ',
                                  style: TextStyle(color: Colors.white70)),
                    ),
                    Material(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: _chooseSet,
                        borderRadius: BorderRadius.circular(10),
                        child: const SizedBox(
                          height: 32,
                          width: 36,
                          child: Icon(Icons.list_alt_rounded,
                              color: Colors.white70, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: _loadMyExamSets,
                        borderRadius: BorderRadius.circular(10),
                        child: const SizedBox(
                          height: 32,
                          width: 36,
                          child: Icon(Icons.refresh,
                              color: Colors.white70, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 3 / 4,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _buildPreview(),
                            const _CornerGuides(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Container(
              height: 110,
              decoration: const BoxDecoration(
                color: Color(0xFF1C2028),
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
              child: Stack(
                alignment: Alignment.center,
                children: [
                  GestureDetector(
                    onTap: _takePhoto,
                    child: Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: Center(
                        child: Container(
                          width: 54,
                          height: 54,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 16,
                    child: GestureDetector(
                      onTap: _pickFromGallery,
                      child: Container(
                        width: 50,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                        child: const Icon(
                          Icons.photo_library_rounded,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_uploading)
          Container(
            color: Colors.black38,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(color: Colors.white),
          ),
      ],
    );
  }

  Widget _buildPreview() {
    final cam = _camera;
    if (!kIsWeb && cam != null) {
      return FutureBuilder(
        future: _initCam,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.done &&
              cam.value.isInitialized) {
            return CameraPreview(cam);
          }
          return const Center(
              child: Icon(Icons.center_focus_weak,
                  size: 64, color: Colors.black45));
        },
      );
    }
    // บนเว็บแสดง placeholder
    return const Center(
      child: Icon(Icons.camera_alt_rounded, size: 64, color: Colors.black45),
    );
  }
}


/// วาด “มุมไกด์” 4 มุมแบบ L
/// วาด “มุมไกด์” 4 มุมแบบ L
class _CornerGuides extends StatelessWidget {
  const _CornerGuides();

  @override
  Widget build(BuildContext context) {
    const len = 56.0;
    const thick = 3.0;
    const color = Color(0xFFCDCDCD);

      // --- มุมบนซ้าย ---
    Widget cornerTL() => Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: SizedBox(
              width: len,
              height: len,
              child: Stack(children: [
                Positioned(
                    left: 0,
                    top: 0,
                    child:
                        Container(width: len, height: thick, color: color)),
                Positioned(
                    left: 0,
                    top: 0,
                    child:
                        Container(width: thick, height: len, color: color)),
              ]),
            ),
          ),
        );

    // --- มุมบนขวา ---
    Widget cornerTR() => Align(
          alignment: Alignment.topRight,
          child: Transform.rotate(
            angle: 1.5708, // 90 เธญเธเธจเธฒ
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: SizedBox(
                width: len,
                height: len,
                child: Stack(children: [
                  Positioned(
                      left: 0,
                      top: 0,
                      child:
                          Container(width: len, height: thick, color: color)),
                  Positioned(
                      left: 0,
                      top: 0,
                      child:
                          Container(width: thick, height: len, color: color)),
                ]),
              ),
            ),
          ),
        );

    // --- มุมล่างขวา ---
    Widget cornerBR() => Align(
          alignment: Alignment.bottomRight,
          child: Transform.rotate(
            angle: 3.14159, // 180 เธญเธเธจเธฒ
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: SizedBox(
                width: len,
                height: len,
                child: Stack(children: [
                  Positioned(
                      left: 0,
                      top: 0,
                      child:
                          Container(width: len, height: thick, color: color)),
                  Positioned(
                      left: 0,
                      top: 0,
                      child:
                          Container(width: thick, height: len, color: color)),
                ]),
              ),
            ),
          ),
        );

    // --- มุมล่างซ้าย ---
    Widget cornerBL() => Align(
          alignment: Alignment.bottomLeft,
          child: Transform.rotate(
            angle: -1.5708, // -90 เธญเธเธจเธฒ
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: SizedBox(
                width: len,
                height: len,
                child: Stack(children: [
                  Positioned(
                      left: 0,
                      top: 0,
                      child:
                          Container(width: len, height: thick, color: color)),
                  Positioned(
                      left: 0,
                      top: 0,
                      child:
                          Container(width: thick, height: len, color: color)),
                ]),
              ),
            ),
          ),
        );

    return Stack(
      children: [cornerTL(), cornerTR(), cornerBR(), cornerBL()],
    );
  }
}
