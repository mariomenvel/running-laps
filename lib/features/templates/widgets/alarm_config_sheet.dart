import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/widgets/ios_picker.dart';
import '../data/template_models.dart';


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
    super.key,
    required this.initialAlerts,
  });

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
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.iconMuted,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Configurar Alarma",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                TextButton(
                  onPressed: _save,
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    "ACEPTAR",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                )
              ],
            ),
          ),
          const Divider(height: 1),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                children: [
                   Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.iconMuted,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: CupertinoSlidingSegmentedControl<String>(
                        groupValue: _mode,
                        thumbColor: Colors.white,
                        backgroundColor: Colors.transparent,
                        children: {
                          'time': _buildSegmentItem('Por Tiempo', _mode == 'time'),
                          'pace': _buildSegmentItem('Por Ritmo', _mode == 'pace'),
                        },
                        onValueChanged: (val) {
                          if (val != null) setState(() => _mode = val);
                        },
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _mode == 'time' 
                          ? _buildTimeConfig(key: const ValueKey('time')) 
                          : _buildPaceConfig(key: const ValueKey('pace')),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentItem(String text, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Text(
        text,
        style: TextStyle(
          color: isSelected ? (Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand) : Colors.black54,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildTimeConfig({Key? key}) {
    return Column(
      key: key,
      children: [
        const Text(
          "Elige la frecuencia del aviso",
          style: TextStyle(fontSize: 14, color: AppColors.iconMuted, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 24),
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.iconMuted),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildCupertinoWheel(
                  label: 'MINUTOS',
                  itemCount: 60,
                  initialItem: _timeMin,
                  onChanged: (val) => setState(() => _timeMin = val),
                  textBuilder: (i) => i.toString(),
                ),
              ),
              VerticalDivider(width: 1, indent: 40, endIndent: 40, color: AppColors.iconMuted),
              Expanded(
                child: _buildCupertinoWheel(
                  label: 'SEGUNDOS',
                  itemCount: 120,
                  initialItem: (_timeSec * 2).round(),
                  onChanged: (val) => setState(() => _timeSec = val * 0.5),
                  textBuilder: (i) => (i * 0.5).toStringAsFixed(1),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaceConfig({Key? key}) {
    final int paceMinIndex = (_paceMin - 2).clamp(0, 28);
    final int paceSecIndex = _paceSec ~/ 5;
    final int segmentIndex = _segmentDistances.indexOf(_segmentDistance);
    
    return Column(
      key: key,
      children: [
        const Text(
          "Marca tu ritmo objetivo",
          style: TextStyle(fontSize: 14, color: AppColors.iconMuted, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 20),
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.iconMuted),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildCupertinoWheel(
                  label: 'MINUTOS',
                  itemCount: 30, 
                  initialItem: paceMinIndex,
                  onChanged: (val) => setState(() => _paceMin = val + 2),
                  textBuilder: (i) => (i + 2).toString(),
                ),
              ),
              VerticalDivider(width: 1, indent: 40, endIndent: 40, color: AppColors.iconMuted),
              Expanded(
                child: _buildCupertinoWheel(
                  label: 'SEGUNDOS',
                  itemCount: 12,
                  initialItem: paceSecIndex,
                  onChanged: (val) => setState(() => _paceSec = val * 5),
                  textBuilder: (i) => (i * 5).toString().padLeft(2, '0'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          "¿Cada cuántos metros debe sonar?",
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black87),
        ),
        const SizedBox(height: 16),
        Container(
          height: 160,
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.iconMuted),
          ),
          child: _buildCupertinoWheel(
            label: 'METROS',
            itemCount: _segmentDistances.length,
            initialItem: segmentIndex == -1 ? 3 : segmentIndex,
            onChanged: (val) => setState(() => _segmentDistance = _segmentDistances[val]),
            textBuilder: (i) => "${_segmentDistances[i]}m",
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
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.iconMuted,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
        Expanded(
          child: Center(
            child: IosPicker(
              itemCount: itemCount,
              initialItem: initialItem,
              onChanged: onChanged,
              textBuilder: textBuilder,
              itemExtent: 36,
              width: 90,
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
