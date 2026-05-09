// lib/app/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import 'dart:typed_data';

class ApiService {
  // เปลี่ยนให้ตรงกับเครื่อง backend ของคุณ
  static String get baseUrl {
    const def = String.fromEnvironment('API_BASE_URL');
    if (def.isNotEmpty) return def;
    // ค่าเริ่มต้นระหว่างพัฒนา
    // - Web: ใช้โลคัลพอร์ต 8000
    // - Android emulator: 10.0.2.2 คือ localhost ของโฮสต์
    // - อื่นๆ: 127.0.0.1
    if (identical(0, 0.0)) {
      // trick ให้ tree-shaker ไม่บ่นในบางโหมด
    }
    try {
      // kIsWeb อยู่ใน flutter/foundation แต่หลีกเลี่ยง import เพิ่มโดยใช้ Uri.base เช็คแทน
      final isWeb = Uri.base.scheme.startsWith('http');
      if (isWeb) return 'http://127.0.0.1:8000';
    } catch (_) {}
    return 'http://10.0.2.2:8000';
  }

  // ===== TOKEN =====
  static String? _token;

  static Future<void> loadToken() async {
    final sp = await SharedPreferences.getInstance();
    _token = sp.getString('auth_token');
  }

  static Future<void> setToken(String token) async {
    _token = token.isNotEmpty ? token : null;
    final sp = await SharedPreferences.getInstance();
    if (_token == null) {
      await sp.remove('auth_token');
    } else {
      await sp.setString('auth_token', _token!);
    }
  }

  static Future<void> clearToken() async {
    _token = null;
    final sp = await SharedPreferences.getInstance();
    await sp.remove('auth_token');
  }

  static bool get hasToken => _token != null && _token!.isNotEmpty;

  static Map<String, String> _jsonHeaders({
    bool auth = false,
    Map<String, String>? extra,
  }) {
    final h = <String, String>{"Content-Type": "application/json"};
    if (auth) {
      if (!hasToken) throw Exception("No token set");
      h["Authorization"] = "Bearer $_token";
    }
    if (extra != null) h.addAll(extra);
    return h;
  }

  // ===== AUTH =====
  static Future<Map<String, dynamic>> login(
      String username, String password) async {
    final res = await http.post(
      Uri.parse("$baseUrl/auth/login"),
      headers: _jsonHeaders(),
      body: jsonEncode({"username": username, "password": password}),
    );
    final body = _safeJson(res.body);
    if (res.statusCode == 200) return body;
    throw Exception(body["detail"] ?? "Login failed");
  }

  static Future<Map<String, dynamic>> me() async {
    final res = await http.get(
      Uri.parse("$baseUrl/auth/me"),
      headers: _jsonHeaders(auth: true),
    );
    final body = _safeJson(res.body);
    if (res.statusCode == 200) return body;
    throw Exception(body["detail"] ?? "Not authenticated");
  }

  // ===== EXAMS =====
  static Future<Map<String, dynamic>> examSummary() async {
    final res = await http.get(
      Uri.parse("$baseUrl/exams/summary"),
      headers: _jsonHeaders(auth: true),
    );
    final body = _safeJson(res.body);
    if (res.statusCode == 200) return body;
    throw Exception(body["detail"] ?? "Fetch summary failed");
  }

  static Future<List<Map<String, dynamic>>> latestExams({int limit = 5}) async {
    final res = await http.get(
      Uri.parse("$baseUrl/exams/latest?limit=$limit"),
      headers: _jsonHeaders(auth: true),
    );
    final body = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw Exception(body["detail"] ?? "Fetch latest failed");
    }

    final raw = (body["items"] as List?) ?? const [];

    // ✅ Normalize ชนิดข้อมูลสำคัญ + ฟิลด์นับ pending/checked/totalCandidates
    return raw.map<Map<String, dynamic>>((e) {
      final m = Map<String, dynamic>.from(e as Map);

      int? _toInt(dynamic v) {
        if (v == null) return null;
        if (v is int) return v;
        if (v is double) return v.toInt();
        final s = "$v".trim();
        return int.tryParse(s);
      }

      m["quizId"] = _toInt(m["quizId"]) ?? _toInt(m["id"]) ?? 0;
      m["term"] = _toInt(m["term"]) ?? m["term"];
      m["year"] = _toInt(m["year"]) ?? m["year"];

      // ฟิลด์ใหม่จาก backend (มีได้ หรือไม่มี)
      final totalCandidates = _toInt(m["totalCandidates"]);
      final checkedCount = _toInt(m["checkedCount"]);
      final pendingCount = _toInt(m["pendingCount"]);

      m["totalCandidates"] =
          totalCandidates; // อาจเป็น null ถ้าไม่มี ForClassRoom
      m["checkedCount"] = checkedCount ?? 0; // อย่างน้อย 0
      m["pendingCount"] = pendingCount; // อาจเป็น null ถ้า total ไม่ทราบ

      // คีย์เดิมเพื่อความเข้ากันได้
      m["scoreId"] = m["quizId"];
      m["title"] = (m["title"] ?? "—").toString();

      // createdAt ควรเป็น string อยู่แล้ว (ไม่แก้)
      m["createdAt"] = (m["createdAt"] ?? "").toString();

      return m;
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> myExams({int limit = 100}) async {
    final res = await http.get(
      Uri.parse("$baseUrl/exams/mine?limit=$limit"),
      headers: _jsonHeaders(auth: true),
    );
    final data = _safeJson(res.body);
    if (res.statusCode == 200) {
      final List list = data["items"] ?? [];
      return list.cast<Map<String, dynamic>>();
    }
    throw Exception(data["detail"] ?? "Fetch exams failed");
  }

  // สร้าง/อัปเดตชุดข้อสอบ
  static Future<Map<String, dynamic>> createExam({
    required String title,
    required int total,
    required String term,
    required int year,
    required String subjectNo,
    double? ppercent,
    String? typSubject, // เช่น "Subject"
    String? quizKind, // เช่น "Pretest", "Posttest", "Midterm", "Final", "Other"
  }) async {
    final bodyData = {
      "title": title,
      "total": total,
      "term": term,
      "year": year,
      "subjectNo": subjectNo,
      if (ppercent != null) "ppercent": ppercent,
      if (typSubject != null) "typSubject": typSubject,
      if (quizKind != null) "quizKind": quizKind,
    };

    final res = await http.post(
      Uri.parse("$baseUrl/exams"),
      headers: _jsonHeaders(auth: true),
      body: jsonEncode(bodyData),
    );

    final body = _safeJson(res.body);
    if (res.statusCode == 200) return body["item"] ?? {};
    throw Exception(body["detail"] ?? "Create exam failed");
  }

  // ===== EXAM RESULTS =====
  static Map<String, String> authHeaders() => _jsonHeaders(auth: true);

  static Future<Map<String, dynamic>> examResults({
    required int quizId,
    required int term,
    required int year,
  }) async {
    final uri = Uri.parse(
      "$baseUrl/exams/results?quizId=$quizId&term=$term&year=$year",
    );
    final res = await http.get(uri, headers: _jsonHeaders(auth: true));
    final body = _safeJson(res.body);
    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(body);
    }
    throw Exception(
        body["detail"] ?? "Fetch results failed (${res.statusCode})");
  }

  // ===== DAILY SUMMARY =====
  static Future<List<Map<String, dynamic>>> dailySummary({
    required DateTime start,
    required DateTime end,
    int? quizId,
  }) async {
    String fmt(DateTime d) =>
        "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
    final s = fmt(start);
    final e = fmt(end);
    final q = quizId != null ? "&quizId=$quizId" : "";
    final uri = Uri.parse("$baseUrl/exams/daily_summary?start=$s&end=$e$q");
    final res = await http.get(uri, headers: _jsonHeaders(auth: true));
    final body = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw Exception(body["detail"] ?? "Fetch daily summary failed");
    }
    final list = (body["items"] as List?) ?? const [];
    return list.cast<Map<String, dynamic>>();
  }

  static Future<List<Map<String, dynamic>>> dailyBreakdown({
    required DateTime day,
  }) async {
    String fmt(DateTime d) =>
        "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
    final d = fmt(day);
    final uri = Uri.parse("$baseUrl/exams/daily_breakdown?day=$d");
    final res = await http.get(uri, headers: _jsonHeaders(auth: true));
    final body = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw Exception(body["detail"] ?? "Fetch daily breakdown failed");
    }
    final list = (body["items"] as List?) ?? const [];
    return list.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> examResultDetail({
    required int quizId,
    required String stdNo,
    bool includeImage = true,
  }) async {
    final uri = Uri.parse(
        "$baseUrl/exams/result?quizId=$quizId&stdNo=$stdNo&includeImage=${includeImage ? 1 : 0}");
    final res = await http.get(uri, headers: _jsonHeaders(auth: true));
    final body = _safeJson(res.body);
    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(body);
    }
    throw Exception(
        body["detail"] ?? "Fetch result detail failed (${res.statusCode})");
  }

  // ===== PERSON PROFILE (tblPerson) =====
  static Future<Map<String, dynamic>> getPersonProfile() async {
    final res = await http.get(
      Uri.parse("$baseUrl/profile"),
      headers: _jsonHeaders(auth: true),
    );
    final body = _safeJson(res.body);
    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(body["person"] ?? {});
    }
    throw Exception(body["detail"] ?? "Fetch profile failed");
  }

  static Future<Map<String, dynamic>> updatePersonProfile({
    int? prefixNo,
    String? fName,
    String? lName,
    String? fNameEN,
    String? lNameEN,
    String? mobile,
    String? email,
    String? address,
    String? addressNo,
    String? addressMoo,
    String? addressRoad,
    String? addressSoi,
    String? addressDistrict,
    String? position,
    String? photo,
    int? status,
  }) async {
    final res = await http.put(
      Uri.parse("$baseUrl/profile"),
      headers: _jsonHeaders(auth: true),
      body: jsonEncode({
        if (prefixNo != null) "prefixNo": prefixNo,
        if (fName != null) "fName": fName,
        if (lName != null) "lName": lName,
        if (fNameEN != null) "fNameEN": fNameEN,
        if (lNameEN != null) "lNameEN": lNameEN,
        if (mobile != null) "mobile": mobile,
        if (email != null) "email": email,
        if (address != null) "address": address,
        if (addressNo != null) "address_no": addressNo,
        if (addressMoo != null) "address_moo": addressMoo,
        if (addressRoad != null) "address_road": addressRoad,
        if (addressSoi != null) "address_soi": addressSoi,
        if (addressDistrict != null) "address_district": addressDistrict,
        if (position != null) "position": position,
        if (photo != null) "photo": photo,
        if (status != null) "status": status,
      }),
    );
    final body = _safeJson(res.body);
    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(body["person"] ?? {});
    }
    throw Exception(body["detail"] ?? "Update profile failed");
  }

  // ===== helpers =====
  static Map<String, dynamic> _safeJson(String src) {
    try {
      final data = jsonDecode(src);
      if (data is Map<String, dynamic>) return data;
      return {"data": data};
    } catch (_) {
      return {"detail": src};
    }
  }

  static Future<List<Map<String, dynamic>>> getChoices(int quizId) async {
    final uri = Uri.parse("$baseUrl/exams/choices?quizId=$quizId");
    final res = await http.get(uri, headers: _jsonHeaders(auth: true));
    final body = _safeJson(res.body);

    if (res.statusCode != 200) {
      throw Exception(body["detail"] ?? "Fetch choices failed");
    }

    // รองรับได้ทั้ง 3 กรณี: {items:[...]}, {data:[...]}, หรือ [...] ตรงๆ
    final any = body["items"] ?? body["data"] ?? body;
    final list = (any is List) ? any : const [];

    return list.map<Map<String, dynamic>>((e) {
      final m = <String, dynamic>{};
      (e as Map).forEach(
          (k, v) => m['${k}'.toLowerCase()] = v); // ทำคีย์เป็นตัวพิมพ์เล็ก
      return m;
    }).toList();
  }

  // ===== Mock APIs =====
  // ส่งคำขอลบบัญชี (จำลอง): พยายามโพสต์ไปยัง path ปลอม แล้วหน่วงเวลาสั้นๆ
  static Future<void> requestDeleteAccount({String? reason}) async {
    try {
      final uri = Uri.parse("$baseUrl/_mock/delete-account");
      await http.post(
        uri,
        headers: _jsonHeaders(auth: true),
        body: jsonEncode({
          "reason": reason ?? "user requested",
          "timestamp": DateTime.now().toIso8601String(),
        }),
      );
    } catch (_) {
      // เงียบไว้: เป็น mock ไม่ต้องให้ error หลุดขึ้นมา
    }
    await Future.delayed(const Duration(milliseconds: 600));
  }

  // อัปเดตเฉลย/คะแนน/สถานะใช้ของข้อที่กำหนด
  static Future<void> updateChoice({
    required int quizId,
    required int no,
    int? answer, // 1..5
    int? score, // เช่น 1
    bool? isUse, // true -> 1, false -> 0
  }) async {
    final uri = Uri.parse("$baseUrl/exams/choice/$quizId/$no");
    final payload = <String, dynamic>{
      if (answer != null) "answer": answer,
      if (score != null) "score": score,
      if (isUse != null) "isUse": isUse ? 1 : 0,
    };
    final res = await http.put(
      uri,
      headers: _jsonHeaders(auth: true),
      body: jsonEncode(payload),
    );
    final body = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw Exception(body["detail"] ?? "Update choice failed");
    }
  }

  // ===== OMR UPLOAD =====
  static Future<Map<String, dynamic>> uploadOmr({
    required int quizId,
    required int term,
    required int year,
    String? grader,
    String? filePath, // มือถือ/เดสก์ท็อป
    Uint8List? bytes, // เว็บ
    String? filename,
    String? overrideMime,
  }) async {
    final uri = Uri.parse("$baseUrl/omr/grade");

    final req = http.MultipartRequest("POST", uri);

    final headers = _jsonHeaders(auth: true);
    headers.remove("Content-Type");
    req.headers.addAll(headers);

    // ฟิลด์ฟอร์มที่จำเป็น
    req.fields["quizId"] = "$quizId";
    req.fields["term"] = "$term";
    req.fields["year"] = "$year";

    // ส่งเฉพาะเมื่อมีค่า (ให้ backend ตัดสินใจ default เองถ้าจำเป็น)
    if (grader != null && grader.isNotEmpty) {
      req.fields["grader"] = grader;
    }

    if (bytes != null) {
      final mime = overrideMime ??
          lookupMimeType(filename ?? 'upload.jpg') ??
          'image/jpeg';
      final parts = mime.split('/');
      req.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename ?? 'upload.jpg',
        contentType: MediaType(parts.first, parts.last),
      ));
    } else if (filePath != null) {
      final mime = overrideMime ?? lookupMimeType(filePath) ?? 'image/jpeg';
      final parts = mime.split('/');
      req.files.add(await http.MultipartFile.fromPath(
        'file',
        filePath,
        contentType: MediaType(parts.first, parts.last),
      ));
    } else {
      throw Exception('No file provided');
    }

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    final body = _safeJson(res.body);

    if (res.statusCode == 200) {
      final map = Map<String, dynamic>.from(body);

      // ถ้าไม่พบนักเรียนในระบบ ให้ขว้าง exception พร้อมข้อความจาก backend
      if (map["saved"] == false && (map["reason"] == "student-not-found")) {
        final msg = (map["message"] ??
                "ตรวจไม่สำเร็จ: รหัสนักเรียนไม่ถูกต้องหรือไม่มีอยู่ในระบบ")
            .toString();
        throw Exception(msg);
      }

      return map;
    }
    throw Exception(body["detail"] ?? "OMR upload failed (${res.statusCode})");
  }
}
