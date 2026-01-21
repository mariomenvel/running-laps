import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:running_laps/config/app_theme.dart';
import '../data/template_models.dart';
import '../views/training_start_view.dart'; // Ensure AlarmMode enum is accessible or move it

// Reuse AlarmMode from TrainingStartView or move it to a shared file.
// Ideally, move AlarmMode to 'enums.dart' or 'template_models.dart', but for now assume it's available.
// To avoid circular dependency if TrainingStartView imports this, we should move AlarmMode out.
// For now, let's redefine a local enum or strict typing if not moved.
// Let's check where AlarmMode is defined. It's in TrainingStartView.
// Action: I will duplicate the enum here if needed, or import it.
// Better: Move AlarmMode to `template_models.dart` or `enums.dart` in a real refactor.
// For this step, I'll put it in `template_models.dart` (it fits well there with TemplateAlerts)
// But I can't edit `template_models.dart` right now easily without breaking stuff? 
// Actually I CAN edit `template_models.dart`.

// Let's assume I move AlarmMode to `template_models.dart` or similar. 
// For now, I will import `TrainingStartView` but that might cause circular deps if I use this widget IN `TrainingStartView`.
// Correct approach: Move AlarmMode to a shared location.
// Let's put AlarmMode in `lib/features/training/data/template_models.dart`? No, maybe `lib/features/training/data/enums.dart` (doesn't exist?).
// `lib/features/groups/data/models/enums.dart` exists but is for groups.
// Let's add it to `template_models.dart` since `TemplateAlerts` uses "mode" string which maps to this.

class AlarmConfigSheet extends StatefulWidget {
  final TemplateAlerts initialAlerts;
  
  const AlarmConfigSheet({
    Key? key,
    required this.initialAlerts,
  }) : super(key: key);

  @override
  _AlarmConfigSheetState createState() => _AlarmConfigSheetState();
}

class _AlarmConfigSheetState extends State<AlarmConfigSheet> {
  late String _mode; // 'time' | 'pace'
  late int _timeMin;
  late double _timeSec;
  late int _paceMin;
  late int _paceSec;
  late int _segmentDistance;

  final List<int> _segmentDistances = [50, 100, 200, 300, 400, 500, 1000];
  
  @override
  void initState() {
    super.initState();
    _mode = widget.initialAlerts.mode;
    _timeMin = widget.initialAlerts.timeMin;
    _timeSec = widget.initialAlerts.timeSec;
    _paceMin = widget.initialAlerts.paceMin;
    _paceSec = widget.initialAlerts.paceSec;
    _segmentDistance = widget.initialAlerts.segmentDistance;
  }

  void _save() {
    final alerts = TemplateAlerts(
      enabled: true, // If we are editing settings, we assume enabled. Or manageable outside.
      mode: _mode,
      timeMin: _timeMin,
      timeSec: _timeSec,
      paceMin: _paceMin,
      paceSec: _paceSec,
      segmentDistance: _segmentDistance,
    );
    Navigator.pop(context, alerts);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 600,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
           Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Configurar Alarma",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: _save,
                  child: const Text("Listo", style: TextStyle(color: Tema.brandPurple, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                   SizedBox(
                      width: double.infinity,
                      child: CupertinoSlidingSegmentedControl<String>(
                        groupValue: _mode,
                        thumbColor: Tema.brandPurple,
                        backgroundColor: Colors.grey.shade100,
                        children: {
                          'time': Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Text(
                              'Por Tiempo',
                              style: TextStyle(
                                color: _mode == 'time' ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          'pace': Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Text(
                              'Por Ritmo',
                              style: TextStyle(
                                color: _mode == 'pace' ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        },
                        onValueChanged: (val) {
                          if (val != null) setState(() => _mode = val);
                        },
                      ),
                    ),
                    const SizedBox(height: 30),
                    if (_mode == 'time') _buildTimeConfig() else _buildPaceConfig(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeConfig() {
    return SizedBox(
      height: 160,
      child: Row(
        children: [
          Expanded(
            child: _buildCupertinoWheel(
              label: 'min',
              itemCount: 60,
              initialItem: _timeMin,
              onChanged: (val) => setState(() => _timeMin = val),
              textBuilder: (i) => i.toString(),
            ),
          ),
          Expanded(
            child: _buildCupertinoWheel(
              label: 'sec',
              itemCount: 120,
              initialItem: (_timeSec * 2).round(),
              onChanged: (val) => setState(() => _timeSec = val * 0.5),
              textBuilder: (i) => (i * 0.5).toStringAsFixed(1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaceConfig() {
    final int paceMinIndex = (_paceMin - 2).clamp(0, 28);
    final int paceSecIndex = _paceSec ~/ 5;
    final int segmentIndex = _segmentDistances.indexOf(_segmentDistance);
    
    return Column(
      children: [
        const Text("Marca tu ritmo objetivo", style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 12),
         SizedBox(
          height: 140,
          child: Row(
            children: [
              Expanded(
                child: _buildCupertinoWheel(
                  label: 'min',
                  itemCount: 30, 
                  initialItem: paceMinIndex,
                  onChanged: (val) => setState(() => _paceMin = val + 2),
                  textBuilder: (i) => (i + 2).toString(),
                ),
              ),
              Expanded(
                child: _buildCupertinoWheel(
                  label: 'sec',
                  itemCount: 12,
                  initialItem: paceSecIndex,
                  onChanged: (val) => setState(() => _paceSec = val * 5),
                  textBuilder: (i) => (i * 5).toString().padLeft(2, '0'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text("Sonar cada:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
          child: _buildCupertinoWheel(
            label: 'metros',
            itemCount: _segmentDistances.length,
            initialItem: segmentIndex == -1 ? 3 : segmentIndex,
            onChanged: (val) => setState(() => _segmentDistance = _segmentDistances[val]),
            textBuilder: (i) => _segmentDistances[i].toString(),
          ),
        ),
      ],
    );
  }

  Widget _buildCupertinoWheel({
    required String label,
    required int itemCount,
    required int initialItem,
    required ValueChanged<int> onChanged,
    required String Function(int) textBuilder,
  }) {
     return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Expanded(
          child: CupertinoPicker(
            magnification: 1.22,
            squeeze: 1.2,
            useMagnifier: true,
            itemExtent: 32,
            onSelectedItemChanged: onChanged,
            scrollController: FixedExtentScrollController(initialItem: initialItem),
            children: List<Widget>.generate(itemCount, (int index) {
              return Center(
                child: Text(
                  textBuilder(index),
                  style: const TextStyle(fontSize: 20),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
