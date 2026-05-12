import 'package:flutter/material.dart';

import '../../../core/utils/app_transitions.dart';
import '../../../core/widgets/main_shell.dart';
import '../../athlete/data/athlete_session_model.dart';
import '../../templates/data/workout_session.dart';
import 'workout_execution_screen.dart';

class PreExecutionScreen extends StatefulWidget {
  final WorkoutSession session;
  final AthleteSession? athleteSession;

  const PreExecutionScreen({
    super.key,
    required this.session,
    this.athleteSession,
  });

  @override
  State<PreExecutionScreen> createState() => _PreExecutionScreenState();
}

class _PreExecutionScreenState extends State<PreExecutionScreen> {
  late WorkoutSession _session;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
  }

  Future<void> _onStart() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CountdownDialog(
        onComplete: _launchExecution,
      ),
    );
  }

  Future<void> _launchExecution() async {
    if (!mounted) return;
    Navigator.of(context).pop(); // cierra countdown dialog

    if (mounted) {
      Navigator.of(context).push(
        AppRoute(
          page: WorkoutExecutionScreen(
            session: _session,
            athleteSession: widget.athleteSession,
            onCompleted: () {
              // Al terminar el entrenamiento, vuelve al shell
              if (mounted) {
                MainShell.shellKey.currentState?.navigateBack();
              }
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: _onStart,
          child: const Text('Iniciar'),
        ),
      ),
    );
  }
}

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
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
