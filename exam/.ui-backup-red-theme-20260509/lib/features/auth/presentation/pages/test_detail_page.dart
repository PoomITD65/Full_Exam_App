import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../app/app_theme.dart';
import '../../../../app/services/api_service.dart';

class TestDetailPage extends StatefulWidget {
  const TestDetailPage({
    super.key,
    required this.studentName,
    required this.score,
    required this.total,
    required this.passScore,
  });

  final String studentName;
  final int score;
  final int total;
  final int passScore;

  static const _red = Color(0xFFE01C1C);
  static const _card = Color(0xFF5F6368);

  @override
  State<TestDetailPage> createState() => _TestDetailPageState();
}

class _TestDetailPageState extends State<TestDetailPage> {
  // ค่าที่เคยรับผ่าน constructor จะมาจาก Route arguments แทน
  late String _subject; // default
  late String _studentId; // default
  int? _quizId;
  String _proofImageAsset = '';
  String? _imageBase64; // จาก args หรือ API
  bool _loading = false;
  String? _error;
  bool _argsInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsInitialized) return;
    _argsInitialized = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    final map = (args is Map)
        ? Map<String, dynamic>.from(args as Map)
        : <String, dynamic>{};

    _subject = (map['subject'] as String?)?.toString() ?? 'ผลคะแนนจากข้อสอบ';
    _studentId = (map['studentId'] as String?)?.toString() ?? 'XXXX';
    final qraw = map['quizId'];
    _quizId = qraw is int ? qraw : int.tryParse('${qraw ?? ''}');
    _proofImageAsset = (map['proofImageAsset'] as String?) ?? _proofImageAsset;
    _imageBase64 = (map['proofBase64'] as String?) ?? _imageBase64;

    if (_imageBase64 == null && _quizId != null && _studentId.isNotEmpty) {
      _fetchImage();
    }
  }

  Future<void> _fetchImage() async {
    if (_quizId == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.examResultDetail(
        quizId: _quizId!,
        stdNo: _studentId,
        includeImage: true,
      );
      final img = (data['imageBase64'] ?? '') as String;
      if (mounted) setState(() { _imageBase64 = img.isNotEmpty ? img : null; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Uint8List? _decodeBase64(String? b64) {
    if (b64 == null || b64.isEmpty) return null;
    try {
      final s = b64.contains(',') && b64.contains('base64')
          ? b64.split(',').last
          : b64;
      return base64Decode(s.trim());
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final int score = widget.score;
    final int total = widget.total;
    final int passScore = widget.passScore;
    final bool pass = score >= passScore;
    final String proofFileName = _imageBase64 != null ? 'จากฐานข้อมูล' : '-';
    final double ratio = (total == 0) ? 0 : (score / total).clamp(0, 1).toDouble();

    final bytes = _decodeBase64(_imageBase64);

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: const Text(
          'รายละเอียด',
          style: TextStyle(
            color: TestDetailPage._red,
            fontWeight: FontWeight.w900,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Center(
              child: Text(
                _subject,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          children: [
            // ---------- ข้อมูลผู้เข้าสอบ ----------
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(icon: Icons.person_rounded, title: 'ชื่อ-นามสกุล', value: widget.studentName),
                  const SizedBox(height: 8),
                  _InfoRow(icon: Icons.badge_rounded, title: 'รหัสนักเรียน', value: _studentId),
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.insert_drive_file_rounded,
                    title: 'หลักฐานการตรวจ',
                    value: proofFileName,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text('ดึงรูปไม่สำเร็จ: $_error', style: const TextStyle(color: Colors.amberAccent, fontSize: 12)),
                  ]
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ---------- ภาพหลักฐาน (แตะเพื่อซูม) ----------
            _SectionCard(
              padding: const EdgeInsets.all(10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      GestureDetector(
                        onTap: () => _openFullImage(context, bytes),
                        child: _buildImage(bytes),
                      ),
                      if (_loading) const Center(child: CircularProgressIndicator(color: Colors.white)),
                      // ไอคอนบอกใบ้ว่า “แตะเพื่อซูม”
                      if (bytes != null)
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(.55),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.zoom_in_rounded, size: 16, color: Colors.white),
                                SizedBox(width: 6),
                                Text('แตะเพื่อซูม', style: TextStyle(color: Colors.white, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ---------- สรุปผล ----------
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // แถวตัวเลขใหญ่ + ชิปสถานะ
                  Row(
                    children: [
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            children: [
                              const TextSpan(text: 'คะแนนที่ได้ ', style: TextStyle(color: Colors.white)),
                              TextSpan(
                                text: '$score',
                                style: TextStyle(color: pass ? const Color(0xFF1DB954) : TestDetailPage._red, fontWeight: FontWeight.w900, fontSize: 18),
                              ),
                              const TextSpan(text: ' / ', style: TextStyle(color: Colors.white)),
                              TextSpan(
                                text: '$total',
                                style: TextStyle(color: pass ? const Color(0xFF1DB954) : TestDetailPage._red, fontWeight: FontWeight.w900, fontSize: 18),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _ResultChip(pass: pass),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // แถบความคืบหน้าเปอร์เซ็นต์
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 8,
                      backgroundColor: Colors.white24,
                      valueColor: AlwaysStoppedAnimation<Color>(pass ? const Color(0xFF1DB954) : TestDetailPage._red),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // เกณฑ์/เปอร์เซ็นต์ย่อย
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'สัดส่วน ${(ratio * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        'เกณฑ์ผ่าน ${((passScore / (total == 0 ? 1 : total)) * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('ผลสอบอยู่ในเกณฑ์ : ', style: TextStyle(color: Colors.white)),
                      Text(
                        pass ? 'ผ่าน' : 'ไม่ผ่าน',
                        style: TextStyle(
                          color: pass ? const Color(0xFF1DB954) : TestDetailPage._red,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(Uint8List? bytes) {
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => _imageErrorBox(),
      );
    }
    // ไม่มีรูปจาก DB และไม่ต้องการ fallback เป็น asset -> แสดงกล่องว่างพร้อมสัญลักษณ์
    return Container(
      color: Colors.white,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_not_supported_outlined, size: 48, color: Colors.black45),
            SizedBox(height: 6),
            Text('ไม่มีรูปหลักฐาน', style: TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _imageErrorBox() => Container(
        color: Colors.white,
        child: const Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            size: 48,
            color: Colors.black45,
          ),
        ),
      );

  /// ดูภาพเต็มจอแบบซูมได้
  void _openFullImage(BuildContext context, Uint8List? bytes) {
    if (bytes == null) return; // ไม่มีรูป ไม่ต้องเปิด
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(.9),
      builder: (_) {
        return GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  maxScale: 5,
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.image_not_supported_outlined,
                      color: Colors.white54,
                      size: 80,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/* ===================== Reusable Widgets ===================== */

/// การ์ดส่วนต่าง ๆ ให้สไตล์เดียวกัน
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child, this.padding, this.color});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color ?? TestDetailPage._card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }
}

/// แถวข้อมูลหัวเรื่อง : ค่า + ไอคอนนำหน้า
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.title, required this.value});

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.white),
              children: [
                TextSpan(
                  text: '$title :  ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// ชิปสถานะผลสอบ
class _ResultChip extends StatelessWidget {
  const _ResultChip({required this.pass});
  final bool pass;

  @override
  Widget build(BuildContext context) {
    final bg = pass ? const Color(0xFF1DB954) : TestDetailPage._red;
    final text = pass ? 'ผ่าน' : 'ไม่ผ่าน';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
    );
  }
}

