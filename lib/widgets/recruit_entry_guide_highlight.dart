import 'dart:math';

import 'package:flutter/material.dart';

class RecruitEntryGuideHighlight extends StatefulWidget {
  final Widget child;
  final bool visible;
  final String title;
  final String description;
  final String skipLabel;
  final String actionLabel;
  final VoidCallback? onAction;

  const RecruitEntryGuideHighlight({
    super.key,
    required this.child,
    required this.visible,
    required this.title,
    required this.description,
    required this.skipLabel,
    required this.actionLabel,
    this.onAction,
  });

  @override
  State<RecruitEntryGuideHighlight> createState() =>
      _RecruitEntryGuideHighlightState();
}

class _RecruitEntryGuideHighlightState
    extends State<RecruitEntryGuideHighlight> {
  static const double _guideBubbleWidth = 280;
  static const double _guideBubbleHeight = 176;
  static const double _guideHighlightPadding = 10;
  static const double _guideScreenPadding = 16;

  final GlobalKey _targetKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncOverlayVisibility();
    });
  }

  @override
  void didUpdateWidget(covariant RecruitEntryGuideHighlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      _dismissed = false;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncOverlayVisibility();
    });
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncOverlayVisibility();
    });
    return KeyedSubtree(
      key: _targetKey,
      child: widget.child,
    );
  }

  void _syncOverlayVisibility() {
    if (!mounted) return;

    final shouldShow = widget.visible && !_dismissed;
    if (!shouldShow) {
      _removeOverlay();
      return;
    }

    if (_overlayEntry == null) {
      final overlay = Overlay.of(context, rootOverlay: true);
      _overlayEntry = OverlayEntry(builder: _buildOverlayEntry);
      overlay.insert(_overlayEntry!);
      return;
    }

    _overlayEntry!.markNeedsBuild();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _dismissOverlay() {
    if (_dismissed) return;
    setState(() {
      _dismissed = true;
    });
    _removeOverlay();
  }

  void _handleAction() {
    _dismissOverlay();
    widget.onAction?.call();
  }

  Widget _buildOverlayEntry(BuildContext context) {
    final overlayState = Overlay.of(context, rootOverlay: true);
    final overlayBox = overlayState.context.findRenderObject();
    final targetContext = _targetKey.currentContext;
    final targetBox = targetContext?.findRenderObject();
    if (overlayBox is! RenderBox ||
        targetBox is! RenderBox ||
        !overlayBox.attached ||
        !targetBox.attached) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _overlayEntry?.markNeedsBuild();
      });
      return const SizedBox.shrink();
    }

    final targetOrigin = targetBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    final targetRect = targetOrigin & targetBox.size;
    final highlightRect = targetRect.inflate(_guideHighlightPadding);
    final overlaySize = overlayBox.size;
    final bubbleLayout = _buildGuideBubbleLayout(overlaySize, highlightRect);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _RecruitGuideScrimPainter(
                  highlightRect: highlightRect,
                  color: Colors.black.withValues(alpha: 0.72),
                ),
              ),
            ),
          ),
          ..._buildDismissRegions(overlaySize, highlightRect),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _RecruitGuideConnectorPainter(
                  start: bubbleLayout.connectorStart,
                  end: bubbleLayout.connectorEnd,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
            ),
          ),
          Positioned(
            left: highlightRect.left,
            top: highlightRect.top,
            width: highlightRect.width,
            height: highlightRect.height,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _handleAction,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.18),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: bubbleLayout.left,
            top: bubbleLayout.top,
            width: _guideBubbleWidth,
            height: _guideBubbleHeight,
            child: _buildGuideBubble(),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDismissRegions(Size size, Rect highlightRect) {
    return [
      Positioned(
        left: 0,
        top: 0,
        right: 0,
        height: max(0, highlightRect.top),
        child: _buildDismissRegion(),
      ),
      Positioned(
        left: 0,
        top: highlightRect.top,
        width: max(0, highlightRect.left),
        height: max(0, highlightRect.height),
        child: _buildDismissRegion(),
      ),
      Positioned(
        left: highlightRect.right,
        top: highlightRect.top,
        width: max(0, size.width - highlightRect.right),
        height: max(0, highlightRect.height),
        child: _buildDismissRegion(),
      ),
      Positioned(
        left: 0,
        top: highlightRect.bottom,
        right: 0,
        height: max(0, size.height - highlightRect.bottom),
        child: _buildDismissRegion(),
      ),
    ];
  }

  Widget _buildDismissRegion() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _dismissOverlay,
      child: const SizedBox.expand(),
    );
  }

  _RecruitGuideBubbleLayout _buildGuideBubbleLayout(
    Size size,
    Rect highlightRect,
  ) {
    final showAbove = highlightRect.center.dy > size.height * 0.55;
    final maxLeft = max(
      _guideScreenPadding,
      size.width - _guideBubbleWidth - _guideScreenPadding,
    );
    final left = (highlightRect.center.dx - (_guideBubbleWidth / 2))
        .clamp(_guideScreenPadding, maxLeft)
        .toDouble();
    final top = showAbove
        ? max(
            _guideScreenPadding,
            highlightRect.top - _guideBubbleHeight - 36,
          ).toDouble()
        : min(
            size.height - _guideBubbleHeight - _guideScreenPadding,
            highlightRect.bottom + 36,
          ).toDouble();
    final connectorX = highlightRect.center.dx
        .clamp(left + 28, left + _guideBubbleWidth - 28)
        .toDouble();

    return _RecruitGuideBubbleLayout(
      left: left,
      top: top,
      connectorStart: Offset(
        connectorX,
        showAbove ? top + _guideBubbleHeight : top,
      ),
      connectorEnd: Offset(
        highlightRect.center.dx,
        showAbove ? highlightRect.top : highlightRect.bottom,
      ),
    );
  }

  Widget _buildGuideBubble() {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              widget.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF374151),
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                TextButton(
                  onPressed: _dismissOverlay,
                  child: Text(
                    widget.skipLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _handleAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                  child: Text(
                    widget.actionLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecruitGuideBubbleLayout {
  final double left;
  final double top;
  final Offset connectorStart;
  final Offset connectorEnd;

  const _RecruitGuideBubbleLayout({
    required this.left,
    required this.top,
    required this.connectorStart,
    required this.connectorEnd,
  });
}

class _RecruitGuideScrimPainter extends CustomPainter {
  final Rect highlightRect;
  final Color color;

  const _RecruitGuideScrimPainter({
    required this.highlightRect,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final highlightPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          highlightRect,
          const Radius.circular(18),
        ),
      );
    final overlayPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      highlightPath,
    );

    canvas.drawPath(
      overlayPath,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _RecruitGuideScrimPainter oldDelegate) =>
      oldDelegate.highlightRect != highlightRect || oldDelegate.color != color;
}

class _RecruitGuideConnectorPainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final Color color;

  const _RecruitGuideConnectorPainter({
    required this.start,
    required this.end,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    const dashWidth = 8.0;
    const dashSpace = 6.0;
    final delta = end - start;
    final distance = delta.distance;
    if (distance == 0) return;

    final direction = delta / distance;
    double currentDistance = 0;
    while (currentDistance < distance) {
      final segmentStart = start + direction * currentDistance;
      final segmentEnd =
          start + direction * min(currentDistance + dashWidth, distance);
      canvas.drawLine(segmentStart, segmentEnd, paint);
      currentDistance += dashWidth + dashSpace;
    }

    canvas.drawCircle(end, 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _RecruitGuideConnectorPainter oldDelegate) =>
      oldDelegate.start != start ||
      oldDelegate.end != end ||
      oldDelegate.color != color;
}
