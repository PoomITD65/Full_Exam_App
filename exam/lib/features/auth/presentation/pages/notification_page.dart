import 'package:flutter/material.dart';
import '../../../../app/app_theme.dart';
import '../../../../app/services/notification_service.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  bool _enabled = true;
  TimeOfDay _time1 = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _time2 = const TimeOfDay(hour: 8, minute: 0);
  bool _saving = false;
  String? _msg;

  Future<void> _pick(int which) async {
    final init = which == 1 ? _time1 : _time2;
    final t = await showTimePicker(context: context, initialTime: init);
    if (t != null) setState(() => which == 1 ? _time1 = t : _time2 = t);
  }

  Future<void> _apply() async {
    setState(() {
      _saving = true;
      _msg = null;
    });
    try {
      await NotificationService.initialize();
      if (_enabled) {
        await NotificationService.scheduleDailyTimes([_time1, _time2]);
        setState(() => _msg =
            'ตั้งแจ้งเตือนแล้วทุกวันเวลา ${_fmt(_time1)} และ ${_fmt(_time2)}');
      } else {
        await NotificationService.cancelAll();
        setState(() => _msg = 'ปิดแจ้งเตือนแล้ว');
      }
    } catch (e) {
      setState(() => _msg = 'ผิดพลาด: $e');
    } finally {
      setState(() => _saving = false);
    }
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('การแจ้งเตือนรายวัน')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: const Text('เปิดแจ้งเตือนรายวัน'),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
            const SizedBox(height: 12),
            _TimeTile(
                label: 'เวลา 1', value: _fmt(_time1), onTap: () => _pick(1)),
            const SizedBox(height: 8),
            _TimeTile(
                label: 'เวลา 2', value: _fmt(_time2), onTap: () => _pick(2)),
            const Spacer(),
            if (_msg != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_msg!, style: const TextStyle(color: kSubtle)),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _apply,
                icon: const Icon(Icons.notifications_active_rounded),
                label: Text(
                    _saving ? 'กำลังบันทึก...' : 'บันทึกการตั้งค่าแจ้งเตือน'),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _TimeTile(
      {required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kCard,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kBorder),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(value),
              const SizedBox(width: 8),
              const Icon(Icons.access_time_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
