import 'dart:math' as math;
import 'dart:ui' show BlurStyle, MaskFilter;

import 'package:flutter/material.dart';

/// A small book-shaped scene. Every face shares the same perspective transform,
/// so the cover, spine and paper edges stay connected while the book turns.
class Book3DCover extends StatefulWidget {
  final ImageProvider? cover;
  final String title;
  final bool loading;
  final bool animate;
  final double height;

  const Book3DCover({
    super.key,
    required this.cover,
    required this.title,
    required this.loading,
    required this.animate,
    required this.height,
  });

  @override
  State<Book3DCover> createState() => _Book3DCoverState();
}

class _Book3DCoverState extends State<Book3DCover>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  );

  double _rotationX = 0;
  double _rotationY = 0;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    if (widget.animate) _motion.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant Book3DCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate == oldWidget.animate) return;
    if (widget.animate) {
      _motion.repeat(reverse: true);
    } else {
      _motion.stop();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookHeight = widget.height;
    final bookWidth = bookHeight / 1.46;
    final depth = (bookWidth * 0.09).clamp(16.0, 24.0);
    final pageColor = const Color(0xFFF5F0E2);
    final pageLineColor = const Color(0xFFC9BFAD);

    return SizedBox(
      width: bookWidth + 64,
      height: bookHeight + 34,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) => setState(() => _dragging = true),
            onPanUpdate: (details) {
              setState(() {
                _rotationY = (_rotationY + details.delta.dx * 0.35).clamp(
                  -42.0,
                  30.0,
                );
                _rotationX = (_rotationX - details.delta.dy * 0.25).clamp(
                  -20.0,
                  16.0,
                );
              });
            },
            onPanEnd: (_) => setState(() => _dragging = false),
            onPanCancel: () => setState(() => _dragging = false),
            onDoubleTap: () => setState(() {
              _rotationX = 0;
              _rotationY = 0;
            }),
            child: AnimatedBuilder(
              animation: _motion,
              child: _bookFaces(
                bookWidth,
                bookHeight,
                depth,
                pageColor,
                pageLineColor,
              ),
              builder: (context, child) {
                final phase = _motion.value * math.pi * 2;
                final idleY = widget.animate && !_dragging
                    ? math.sin(phase) * 1.2
                    : 0.0;
                final idleX = widget.animate && !_dragging
                    ? math.cos(phase) * 0.5
                    : 0.0;
                final angleX = (_rotationX + idleX) * math.pi / 180;
                final angleY = (_rotationY + idleY) * math.pi / 180;
                final shadowWidth =
                    bookWidth * (0.72 + 0.13 * math.cos(angleY).abs());
                final shadowOffset = math.sin(angleY) * bookWidth * 0.14;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: (bookWidth - shadowWidth) / 2 + shadowOffset,
                      bottom: -18 + math.sin(angleX) * 8,
                      width: shadowWidth,
                      height: 40,
                      child: CustomPaint(
                        painter: _SoftBookShadowPainter(
                          opacity: 0.15 + 0.06 * math.sin(angleY).abs(),
                        ),
                      ),
                    ),
                    Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0011)
                        ..rotateX(angleX)
                        ..rotateY(angleY),
                      child: child,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _bookFaces(
    double width,
    double height,
    double depth,
    Color pageColor,
    Color pageLineColor,
  ) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..translate(0.0, 0.0, -depth / 2)
                ..rotateY(math.pi),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF29465C), Color(0xFF111F31)],
                  ),
                ),
              ),
            ),
          ),
          // A slim paper rim remains visible when the cover faces the reader.
          Positioned(
            left: width - 1,
            top: 8,
            width: depth * 0.42,
            height: height - 16,
            child: CustomPaint(
              painter: _BookPagesPainter(
                pageColor: pageColor,
                lineColor: pageLineColor,
                verticalLines: true,
              ),
            ),
          ),
          Positioned(
            left: 7,
            top: height - 1,
            width: width - 14,
            height: depth * 0.30,
            child: CustomPaint(
              painter: _BookPagesPainter(
                pageColor: pageColor,
                lineColor: pageLineColor,
                verticalLines: false,
              ),
            ),
          ),
          Positioned(
            left: -depth / 2,
            top: 2,
            width: depth,
            height: height - 4,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..rotateY(-math.pi / 2),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(4),
                  ),
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF0C1724),
                      Color(0xFF35536A),
                      Color(0xFF152637),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: -depth / 2,
            top: 8,
            width: depth,
            height: height - 16,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..rotateY(math.pi / 2),
              child: CustomPaint(
                painter: _BookPagesPainter(
                  pageColor: pageColor,
                  lineColor: pageLineColor,
                  verticalLines: true,
                ),
              ),
            ),
          ),
          Positioned(
            left: 7,
            right: 7,
            bottom: -depth / 2,
            height: depth,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..rotateX(-math.pi / 2),
              child: CustomPaint(
                painter: _BookPagesPainter(
                  pageColor: pageColor,
                  lineColor: pageLineColor,
                  verticalLines: false,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.translationValues(0, 0, depth / 2),
              child: ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(7),
                  right: Radius.circular(12),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: const Color(0xFF304A62),
                      child: widget.cover != null
                          ? Image(
                              image: widget.cover!,
                              fit: BoxFit.contain,
                              semanticLabel: widget.title,
                            )
                          : Center(
                              child: widget.loading
                                  ? const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white70,
                                    )
                                  : const Icon(
                                      Icons.menu_book_rounded,
                                      size: 42,
                                      color: Colors.white70,
                                    ),
                            ),
                    ),
                    const IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment(-0.55, -0.55),
                            radius: 1.15,
                            colors: [
                              Color(0x33FFFFFF),
                              Color(0x0EBDD4FF),
                              Colors.transparent,
                            ],
                            stops: [0, 0.28, 0.7],
                          ),
                        ),
                      ),
                    ),
                    const IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment(-1, -1),
                            end: Alignment(1, 1),
                            colors: [
                              Colors.transparent,
                              Color(0x18FFFFFF),
                              Colors.transparent,
                            ],
                            stops: [0.25, 0.46, 0.64],
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 14,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withValues(alpha: 0.45),
                                Colors.white.withValues(alpha: 0.12),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftBookShadowPainter extends CustomPainter {
  final double opacity;

  const _SoftBookShadowPainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawOval(
      Rect.fromLTWH(5, 14, size.width - 10, 12),
      Paint()
        ..color = Colors.black.withValues(alpha: opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 13),
    );
  }

  @override
  bool shouldRepaint(covariant _SoftBookShadowPainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}

class _BookPagesPainter extends CustomPainter {
  final Color pageColor;
  final Color lineColor;
  final bool verticalLines;

  const _BookPagesPainter({
    required this.pageColor,
    required this.lineColor,
    required this.verticalLines,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [lineColor, pageColor, pageColor, lineColor],
        stops: const [0, 0.15, 0.78, 1],
      ).createShader(bounds);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds, const Radius.circular(2)),
      paint,
    );

    final linePaint = Paint()
      ..color = lineColor.withValues(alpha: 0.7)
      ..strokeWidth = 0.7;
    if (verticalLines) {
      for (double x = 3; x < size.width - 1; x += 3) {
        canvas.drawLine(Offset(x, 1), Offset(x, size.height - 1), linePaint);
      }
    } else {
      for (double y = 3; y < size.height - 1; y += 3) {
        canvas.drawLine(Offset(1, y), Offset(size.width - 1, y), linePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BookPagesPainter oldDelegate) =>
      oldDelegate.pageColor != pageColor ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.verticalLines != verticalLines;
}
