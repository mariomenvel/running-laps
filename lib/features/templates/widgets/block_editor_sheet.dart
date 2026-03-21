import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import '../data/template_models.dart';
import 'alarm_config_sheet.dart';

class BlockEditorSheet extends StatefulWidget {
  final TemplateBlock? initialBlock;

  const BlockEditorSheet({Key? key, this.initialBlock}) : super(key: key);

  @override
  _BlockEditorSheetState createState() => _BlockEditorSheetState();
}

class _BlockEditorSheetState extends State<BlockEditorSheet> {
  int _distancia = 400;
  int _descanso = 60;
  
  // Alerts
  bool _alertsEnabled = false;
  TemplateAlerts _alerts = TemplateAlerts(enabled: false);

  @override
  void initState() {
    super.initState();
    if (widget.initialBlock != null) {
      _distancia = widget.initialBlock!.value;
      _descanso = widget.initialBlock!.restSeconds;
      _alerts = widget.initialBlock!.alerts;
      _alertsEnabled = _alerts.enabled;
    }
  }

  void _save() {
    final block = TemplateBlock(
      id: widget.initialBlock?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      order: widget.initialBlock?.order ?? 0,
      type: TemplateBlockType.distance,
      value: _distancia,
      restSeconds: _descanso,
      alerts: TemplateAlerts(
        enabled: _alertsEnabled,
        mode: _alerts.mode,
        timeMin: _alerts.timeMin,
        timeSec: _alerts.timeSec,
        paceMin: _alerts.paceMin,
        paceSec: _alerts.paceSec,
        segmentDistance: _alerts.segmentDistance,
      ),
    );
    Navigator.pop(context, block);
  }

  void _showDistancePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
         height: 350,
         decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24))
         ),
         child: Column(
           children: [
             const SizedBox(height: 12),
             Container(width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.2), borderRadius: BorderRadius.circular(2))),
             const Padding(padding: EdgeInsets.all(16), child: Text("Distancia (m)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
             Expanded(
               child: CupertinoPicker(
                 itemExtent: 32,
                 scrollController: FixedExtentScrollController(initialItem: (_distancia ~/ 50) - 1),
                 onSelectedItemChanged: (idx) {
                   setState(() {
                     _distancia = (idx + 1) * 50;
                   });
                 },
                 children: List.generate(100, (i) => Center(child: Text("${(i + 1) * 50}m"))),
               ),
             ),
             Padding(padding: const EdgeInsets.all(16), child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: Tema.brandPurple, minimumSize: const Size(double.infinity, 48)), child: const Text("Listo", style: TextStyle(color: Colors.white))))
           ],
         ),
      ),
    );
  }

  void _showRestPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
         height: 350,
         decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24))
         ),
         child: Column(
           children: [
             const SizedBox(height: 12),
             Container(width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.2), borderRadius: BorderRadius.circular(2))),
             const Padding(padding: EdgeInsets.all(16), child: Text("Descanso", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
             Expanded(
               child: CupertinoPicker(
                 itemExtent: 32,
                 scrollController: FixedExtentScrollController(initialItem: _descanso ~/ 5),
                 onSelectedItemChanged: (idx) {
                   setState(() {
                     _descanso = idx * 5;
                   });
                 },
                 children: List.generate(61, (i) => Center(child: Text(_formatMinSec(i * 5)))),
               ),
             ),
             Padding(padding: const EdgeInsets.all(16), child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: Tema.brandPurple, minimumSize: const Size(double.infinity, 48)), child: const Text("Listo", style: TextStyle(color: Colors.white))))
           ],
         ),
      ),
    );
  }

  String _formatMinSec(int totalSeconds) {
    if (totalSeconds < 60) return '${totalSeconds}s';
    final int m = totalSeconds ~/ 60;
    final int s = totalSeconds % 60;
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }
  
  void _openAlarmConfig() async {
    final result = await showModalBottomSheet<TemplateAlerts>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AlarmConfigSheet(initialAlerts: _alerts),
    );
    
    if (result != null) {
      setState(() {
        _alerts = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.transparent : Colors.black12,
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: cs.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          
          // Form
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.initialBlock == null ? "Nueva Serie" : "Editar Serie",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                
                // Dials
                Row(
                  children: [
                    Expanded(
                      child: _buildInputCard(
                        label: "Distancia",
                        value: "$_distancia m",
                        icon: Icons.straighten_rounded,
                        onTap: _showDistancePicker,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildInputCard(
                        label: "Descanso",
                        value: _formatMinSec(_descanso),
                        icon: Icons.timer_outlined,
                        onTap: _showRestPicker,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Alarm Toggle & Config
                Container(
                  decoration: BoxDecoration(
                    color: cs.onSurface.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cs.outline.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _alertsEnabled,
                        onChanged: (v) => setState(() => _alertsEnabled = v),
                        activeColor: Tema.brandPurple,
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _alertsEnabled ? Tema.brandPurple.withOpacity(0.1) : cs.onSurface.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _alertsEnabled ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                            color: _alertsEnabled ? (Theme.of(context).brightness == Brightness.dark ? AppColors.brandPurpleLight : Tema.brandPurple) : cs.onSurface.withOpacity(0.4),
                            size: 20,
                          ),
                        ),
                        title: const Text(
                          "Alertas de Ritmo",
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                      ),
                      if (_alertsEnabled) ...[
                        const Divider(height: 1, indent: 60),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          title: Padding(
                            padding: const EdgeInsets.only(left: 44),
                            child: Text(
                              _alerts.mode == 'time' 
                                ? 'Frecuencia: Cada ${_formatMinSec((_alerts.timeMin * 60 + _alerts.timeSec).round())}'
                                : 'Basado en Ritmo de Carrera',
                              style: TextStyle(fontSize: 14, color: cs.onSurface.withOpacity(0.6), fontWeight: FontWeight.w500),
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Tema.brandPurple.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.settings_suggest_rounded, size: 20, color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandPurpleLight : Tema.brandPurple),
                          ),
                          onTap: _openAlarmConfig,
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Tema.brandPurple, Color(0xFF6A1B9A)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Tema.brandPurple.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text(
                      "LISTO",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard({required String label, required String value, required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.transparent
                  : Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                const SizedBox(width: 6),
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
