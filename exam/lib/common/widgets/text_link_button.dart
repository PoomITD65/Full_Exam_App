import 'package:flutter/material.dart';
import '../../app/app_theme.dart';

class TextLinkButton extends StatelessWidget {
  const TextLinkButton(
    this.text, {
    super.key,
    this.onTap,
    this.style,
    this.color, // ⬅️ ระบุสีลิงก์ (ถ้าไม่ระบุจะใช้ kAccent)
    this.underline = true, // ⬅️ เปิด/ปิดเส้นใต้
    this.padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
    this.textAlign,
  });

  final String text;
  final VoidCallback? onTap;
  final TextStyle? style;
  final Color? color;
  final bool underline;
  final EdgeInsetsGeometry padding;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final baseColor = (onTap == null)
        // ignore: deprecated_member_use
        ? (color ?? kAccent)
            .withOpacity(.5) // ถ้า onTap เป็น null ให้ดูจางลงเหมือน disabled
        : (color ?? kAccent);

    final baseStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: baseColor,
          fontWeight: FontWeight.w700,
          decoration:
              underline ? TextDecoration.underline : TextDecoration.none,
          decorationColor: baseColor,
        );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: padding,
        child: Text(
          text,
          textAlign: textAlign,
          style: baseStyle?.merge(style),
        ),
      ),
    );
  }
}
