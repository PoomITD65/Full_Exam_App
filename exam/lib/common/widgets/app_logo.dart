import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 96, // ← ปรับขนาดตรงนี้หรือส่งค่ามาเวลาสร้าง
    this.framed = false, // อยากมีกรอบมุมโค้งไหม
  });

  final double size;
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final img = Image.asset(
      'assets/images/logo.png',
      height: size,
      width: size,
      fit: BoxFit.contain, // รักษาสัดส่วน
    );

    if (!framed) return img;

    // ถ้าอยากให้มีกรอบมุมโค้งด้านหลังโลโก้
    return Container(
      height: size,
      width: size,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // พื้นหลังเข้ม
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: FittedBox(fit: BoxFit.contain, child: img),
    );
  }
}
