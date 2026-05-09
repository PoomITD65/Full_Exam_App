import 'package:flutter/material.dart';

Future<void> showInfoDialog(BuildContext context, String message,
    {String title = 'แจ้งเตือน'}) {
  return showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ตกลง')),
      ],
    ),
  );
}

Future<void> showErrorDialog(BuildContext context, String message,
    {String title = 'เกิดข้อผิดพลาด'}) {
  return showInfoDialog(context, message, title: title);
}
