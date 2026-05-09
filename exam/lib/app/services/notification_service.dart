import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'report_daily_channel';
  static const String _channelName = 'Daily Report';
  static const String _channelDesc = 'Daily report reminder notifications';

  static Future<void> initialize() async {
    // Timezone init
    tzdata.initializeTimeZones();
    // ตั้งค่าโซนเวลาให้ Asia/Bangkok เป็นค่าเริ่มต้น
    tz.setLocalLocation(tz.getLocation('Asia/Bangkok'));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    await _plugin.initialize(initSettings);

    // ขอสิทธิ์แจ้งเตือน (iOS + Android 13+)
    // Android 13+: หากต้องการขอสิทธิ์การแจ้งเตือนแบบ native
    // ให้ผู้ใช้เปิดสิทธิ์จากระบบหรือจัดการภายนอกแอป (ปล่อยผ่านเพื่อความเข้ากันได้ของเวอร์ชัน)
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static Future<void> cancelAll() => _plugin.cancelAll();

  static Future<void> scheduleDailyTimes(List<TimeOfDay> times) async {
    await cancelAll();

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    final details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    int id = 1000;
    for (final t in times) {
      final next = _nextInstanceOf(t.hour, t.minute);
      await _plugin.zonedSchedule(
        id++,
        'สรุปรายงานประจำวัน',
        'แตะเพื่อดูสรุปรายวันของวันนี้',
        next,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents:
            DateTimeComponents.time, // ซ้ำทุกวันเวลาเดียวกัน
      );
    }
  }

  static tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
