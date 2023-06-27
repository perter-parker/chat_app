import 'package:flutter/material.dart';

class FixedHeader extends StatefulWidget {
  const FixedHeader({
    super.key,
    required GlobalKey<State<StatefulWidget>>? groupHeaderKey,
    required this.context,
    required this.dateList,
    required this.index,
  }) : _groupHeaderKey = groupHeaderKey;

  final GlobalKey<State<StatefulWidget>>? _groupHeaderKey;
  final BuildContext context;
  final List<String> dateList;
  final int index;

  @override
  State<FixedHeader> createState() => _FixedHeaderState();
}

class _FixedHeaderState extends State<FixedHeader> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  void restartAnimation() {
    _animationController.reset();
    _animationController.forward();
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = Tween<double>(begin: 1.0, end: 0.0).animate(_animationController);
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Opacity(
            opacity: _animation.value,
            child: Container(
              key: widget._groupHeaderKey,
              color: Colors.transparent,
              width: MediaQuery.of(context).size.width,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  widget.dateList.isEmpty ? '' : widget.dateList[widget.index],
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          );
        });
  }
}
