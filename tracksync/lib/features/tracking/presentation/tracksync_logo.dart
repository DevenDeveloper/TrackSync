import 'package:material_ui/material_ui.dart';

/// Vector route mark: two stops connected by a continuous S-shaped journey.
class TrackSyncLogo extends StatelessWidget {
  const TrackSyncLogo({super.key, this.size = 42});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
      label: 'TrackSync logo',
      child: SizedBox.square(
          dimension: size, child: CustomPaint(painter: _LogoPainter())));
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 48, size.height / 48);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(0, 0, 48, 48), const Radius.circular(14)),
        Paint()..color = const Color(0xFF087F70));
    final path = Path()
      ..moveTo(33, 13)
      ..lineTo(22, 13)
      ..cubicTo(10, 13, 10, 24, 23, 24)
      ..cubicTo(37, 24, 37, 35, 25, 35)
      ..lineTo(15, 35);
    canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round);
    canvas.drawCircle(
        const Offset(33, 13), 4, Paint()..color = const Color(0xFFC9F477));
    canvas.drawCircle(
        const Offset(15, 35), 4, Paint()..color = const Color(0xFFC9F477));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
