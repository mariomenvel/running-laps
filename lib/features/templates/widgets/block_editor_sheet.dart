import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:running_laps/config/app_theme.dart';
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
      builder: (_) => Container(
         height: 350,
         decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))
         ),
         child: Column(
           children: [
             const SizedBox(height: 12),
             Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
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
      builder: (_) => Container(
         height: 350,
         decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))
         ),
         child: Column(
           children: [
             const SizedBox(height: 12),
             Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
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
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          ),
          
          // Form
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text("Editar Serie", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                
                // Dials
                Row(
                  children: [
                    Expanded(
                      child: _buildInputCard(
                        label: "Distancia",
                        value: "$_distancia m",
                        icon: Icons.straighten,
                        onTap: _showDistancePicker,
                      ),
                    ),
                    const SizedBox(width: 12),
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
                     color: Colors.grey.shade50,
                     borderRadius: BorderRadius.circular(16),
                     border: Border.all(color: Colors.grey.shade200),
                   ),
                   child: Column(
                     children: [
                       ListTile(
                         leading: Icon(
                           _alertsEnabled ? Icons.notifications_active : Icons.notifications_off_outlined,
                           color: _alertsEnabled ? Tema.brandPurple : Colors.grey,
                         ),
                         title: const Text("Alertas de Ritmo"),
                         trailing: Switch(
                           value: _alertsEnabled,
                           onChanged: (v) => setState(() => _alertsEnabled = v),
                           activeColor: Tema.brandPurple,
                         ),
                       ),
                       if (_alertsEnabled)
                         ListTile(
                           title: Text(
                             _alerts.mode == 'time' 
                               ? 'Por Tiempo (${_formatMinSec((_alerts.timeMin * 60 + _alerts.timeSec).round())})'
                               : 'Por Ritmo',
                             style: const TextStyle(fontSize: 14, color: Colors.grey),
                           ),
                           trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                           onTap: _openAlarmConfig,
                         ),
                     ],
                   ),
                ),
                
                const SizedBox(height: 32),
                
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Tema.brandPurple,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Guardar Serie", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const SizedBox(height: 24),
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
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 16, color: Colors.grey), const SizedBox(width: 4), Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))]),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Tema.brandPurple)),
          ],
        ),
      ),
    );
  }
}
