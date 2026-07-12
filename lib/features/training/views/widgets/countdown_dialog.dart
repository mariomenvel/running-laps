import 'package:flutter/material.dart';

class CountdownDialog extends StatefulWidget {
  final VoidCallback onComplete;

  const CountdownDialog({super.key, required this.onComplete});

  @override
  State<CountdownDialog> createState() => _CountdownDialogState();
}

class _CountdownDialogState extends State<CountdownDialog> {
  int _count = 3;

  @override
  void initState() {
    super.initState();
    _tick();
  }

  void _tick() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      if (_count <= 1) {
        widget.onComplete();
      } else {
        setState(() => _count--);
        _tick();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Center(
        child: Text(
          '$_count',
          style: const TextStyle(
            fontSize: 96,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
