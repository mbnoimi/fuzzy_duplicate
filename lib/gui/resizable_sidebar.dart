import 'package:flutter/material.dart';

class ResizableSidebar extends StatefulWidget {
  final Widget child;
  final double initialWidth;
  final double minWidth;
  final double maxWidth;

  const ResizableSidebar({
    super.key,
    required this.child,
    this.initialWidth = 320,
    this.minWidth = 250,
    this.maxWidth = 500,
  });

  @override
  State<ResizableSidebar> createState() => _ResizableSidebarState();
}

class _ResizableSidebarState extends State<ResizableSidebar> {
  late double _width;

  @override
  void initState() {
    super.initState();
    _width = widget.initialWidth;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: _width,
          curve: Curves.easeOut,
          child: widget.child,
        ),
        _buildResizeHandle(),
      ],
    );
  }

  Widget _buildResizeHandle() {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _width += details.delta.dx;
            _width = _width.clamp(widget.minWidth, widget.maxWidth);
          });
        },
        child: AnimatedBuilder(
          animation: Listenable.merge([
            ValueNotifier(_width),
          ]),
          builder: (context, child) {
            return Container(
              width: 6,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.grey.shade400,
                    Colors.grey.shade300,
                    Colors.grey.shade400,
                  ],
                ),
              ),
              child: Center(
                child: Container(
                  width: 2,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade600,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
