import 'dart:async';
import 'package:flutter/material.dart';

class CountdownDialog extends StatefulWidget {
  final VoidCallback onComplete;

  const CountdownDialog({super.key, required this.onComplete});

  @override
  State<CountdownDialog> createState() => _CountdownDialogState();
}

class _CountdownDialogState extends State<CountdownDialog>
    with SingleTickerProviderStateMixin {
  int _count = 3;
  late Timer _timer;
  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnim = Tween<double>(begin: 1.4, end: 0.8).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_count <= 1) {
        _timer.cancel();
        widget.onComplete();
      } else {
        setState(() => _count--);
        _animController.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Text(
            '$_count',
            style: const TextStyle(
              fontSize: 120,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
