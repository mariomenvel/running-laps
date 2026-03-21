import 'package:flutter/material.dart';
import 'package:running_laps/features/home/viewmodels/home_config_controller.dart';
import 'package:running_laps/features/analytics/data/home_layout_config.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/core/theme/app_colors.dart';

class EditHomeView extends StatefulWidget {
  final HomeConfigController controller;

  const EditHomeView({
    super.key,
    required this.controller,
  });

  @override
  State<EditHomeView> createState() => _EditHomeViewState();
}

class _EditHomeViewState extends State<EditHomeView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Personalizar Inicio',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
        ),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandPurpleLight : Tema.brandPurple),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () => _confirmReset(context),
            child: Text('Reset', style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandPurpleLight : Tema.brandPurple)),
          ),
        ],
      ),
      body: ValueListenableBuilder<HomeLayoutConfig?>(
        valueListenable: widget.controller.config,
        builder: (context, config, child) {
          if (config == null) {
            return const Center(child: CircularProgressIndicator(color: Tema.brandPurple));
          }

          final widgets = List<HomeWidget>.from(config.widgets)
            ..sort((a, b) => a.order.compareTo(b.order));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Text(
                  "ORDEN Y VISIBILIDAD",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  buildDefaultDragHandles: false, // We use custom drag handle
                  padding: const EdgeInsets.only(bottom: 40),
                  itemCount: widgets.length,
                  onReorder: (oldIndex, newIndex) {
                     widget.controller.reorderWidgets(oldIndex, newIndex);
                  },
                  proxyDecorator: (child, index, animation) {
                     return Material(
                       elevation: 10,
                       color: Colors.transparent,
                       shadowColor: Theme.of(context).brightness == Brightness.dark ? Colors.transparent : Colors.black26,
                       child: child,
                     );
                  },
                  itemBuilder: (context, index) {
                    final widgetItem = widgets[index];
                    final isLast = index == widgets.length - 1;
                    return _buildRowItem(context, widgetItem, index, isLast);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRowItem(BuildContext context, HomeWidget widgetItem, int index, bool isLast) {
    return Container(
      key: ValueKey(widgetItem.id),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Visibility Toggle (Leading)
                GestureDetector(
                  onTap: () => widget.controller.toggleWidgetVisibility(widgetItem.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widgetItem.visible ? Tema.brandPurple : Colors.transparent,
                      border: Border.all(
                        color: widgetItem.visible ? Tema.brandPurple : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: widgetItem.visible
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Icon Preview
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widgetItem.type.icon, 
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                const SizedBox(width: 16),

                // Title
                Expanded(
                  child: Text(
                    widgetItem.config['title'] ?? widgetItem.type.displayName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: widgetItem.visible ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                      decoration: widgetItem.visible ? null : TextDecoration.lineThrough,
                    ),
                  ),
                ),

                // Drag Handle
                ReorderableDragStartListener(
                  index: index,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.drag_handle_rounded, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                  ),
                ),
              ],
            ),
          ),
          if (!isLast)
             Divider(height: 1, indent: 56, color: Theme.of(context).colorScheme.outline),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Restablecer diseño?'),
        content: const Text('Esto volverá a la configuración original.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
             onPressed: () => Navigator.pop(context, true),
             child: const Text('Sí, restablecer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.controller.resetToDefault();
    }
  }
}

