import 'package:flutter/material.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';
import 'package:running_laps/core/widgets/app_header.dart';
import 'package:running_laps/core/widgets/gradient_banner.dart';
import '../data/template_models.dart';
import '../data/templates_repository.dart';
import '../widgets/block_editor_sheet.dart';

class TemplateEditorView extends StatefulWidget {
  final TrainingTemplate? template; // null = new
  final bool isMomentary;
  final bool isSelectionMode;

  const TemplateEditorView({
    Key? key, 
    this.template,
    this.isMomentary = false,
    this.isSelectionMode = false,
  }) : super(key: key);

  @override
  _TemplateEditorViewState createState() => _TemplateEditorViewState();
}

class _TemplateEditorViewState extends State<TemplateEditorView> {
  final TextEditingController _nameController = TextEditingController();
  final TrainingTemplatesRepository _repository = TrainingTemplatesRepository();
  
  List<TemplateBlock> _blocks = [];
  bool _isSaving = false;
  bool _hasChanges = false;
  int _selectedColor = 0xFF9C27B0; // Default Tema.brandPurple

  final List<int> _availableColors = [
    0xFF9C27B0, // Purple
    0xFFE91E63, // Pink
    0xFFF44336, // Red
    0xFFFF9800, // Orange
    0xFFFFEB3B, // Yellow
    0xFF4CAF50, // Green
    0xFF00BCD4, // Cyan
    0xFF2196F3, // Blue
    0xFF3F51B5, // Indigo
    0xFF607D8B, // Blue Grey
  ];

  @override
  void initState() {
    super.initState();
    if (widget.template != null) {
      _nameController.text = widget.template!.name;
      _blocks = List.from(widget.template!.blocks);
      _selectedColor = widget.template!.colorValue;
      // Sort just in case order is not sequential
      _blocks.sort((a, b) => a.order.compareTo(b.order));
    }
  }
  
  // Re-assign order based on list index
  void _reorderBlocks() {
    for (int i = 0; i < _blocks.length; i++) {
      // Create new instance with updated order, keep ID
      _blocks[i] = TemplateBlock(
        id: _blocks[i].id,
        order: i, 
        type: _blocks[i].type,
        value: _blocks[i].value,
        restSeconds: _blocks[i].restSeconds,
        alerts: _blocks[i].alerts,
      );
    }
  }

  void _addBlock() async {
    final newBlock = await showModalBottomSheet<TemplateBlock>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const BlockEditorSheet(),
    );

    if (newBlock != null) {
      setState(() {
        _blocks.add(newBlock);
        _reorderBlocks();
        _hasChanges = true;
      });
    }
  }

  void _editBlock(int index) async {
    final updatedBlock = await showModalBottomSheet<TemplateBlock>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => BlockEditorSheet(initialBlock: _blocks[index]),
    );

    if (updatedBlock != null) {
      setState(() {
        _blocks[index] = updatedBlock;
        _hasChanges = true;
        // Ensure ID is kept if passed back correctly, or new one generated if replaced?
        // editor generates ID if null, but here we replace. 
        // ID should be consistent if possible but for templates it's not strictly relational yet.
      });
    }
  }

  void _deleteBlock(int index) {
    setState(() {
      _blocks.removeAt(index);
      _reorderBlocks();
      _hasChanges = true;
    });
  }

  void _duplicateBlock(int index) {
    setState(() {
      final original = _blocks[index];
      // Create copy with new ID but same values
      final copy = TemplateBlock(
        id: DateTime.now().millisecondsSinceEpoch.toString() + index.toString(), // Unique ID
        order: original.order, // Will be fixed by reorder
        type: original.type,
        value: original.value,
        restSeconds: original.restSeconds,
        alerts: original.alerts, // Reference is fine as alerts is immutable-ish or we construct new
      );
      
      // Insert after the original
      _blocks.insert(index + 1, copy);
      _reorderBlocks();
      _hasChanges = true;
    });
  }
  
  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty && !widget.isMomentary) {
      ModernSnackBar.showError(context, "Asigna un nombre a la plantilla");
      return;
    }
    if (_blocks.isEmpty) {
      ModernSnackBar.showError(context, "Añade al menos una serie");
      return;
    }

    setState(() => _isSaving = true);

    try {
      final template = TrainingTemplate(
        id: widget.template?.id ?? (widget.isMomentary ? 'temp' : ''),
        name: _nameController.text.trim().isEmpty ? 'Sesión Rápida' : _nameController.text.trim(),
        blocks: _blocks,
        createdAt: widget.template?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        colorValue: _selectedColor,
      );

      // --- LOGIC FOR MOMENTARY / SELECTION ---
      
      if (widget.isMomentary) {
         Navigator.pop(context, template);
         return;
      }

      if (widget.isSelectionMode) {
         final nameChanged = _nameController.text.trim() != (widget.template?.name ?? '');
         
         if (!_hasChanges && !nameChanged) {
            // No changes, just return original
            Navigator.pop(context, widget.template);
            return;
         }
         
         // Ask user with Premium Bottom Sheet
         final result = await showModalBottomSheet<String>(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (ctx) => Container(
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Tema.brandPurple.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.info_outline_rounded, color: Theme.of(ctx).brightness == Brightness.dark ? AppColors.brandPurpleLight : Tema.brandPurple, size: 40),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Confirmar cambios",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Theme.of(ctx).colorScheme.onSurface),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Has modificado la plantilla. ¿Quieres actualizar la original o usar estos cambios solo para este entrenamiento?",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.6)),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx, 'temp'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text(
                            'Solo esta vez',
                            style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.6), fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Tema.brandPurple, Color(0xFFBA68C8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Tema.brandPurple.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, 'update'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text('Actualizar original', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
         );
         
         if (result == 'temp') {
           Navigator.pop(context, template);
           return;
         } 
         else if (result == 'update') {
           // Proceed to save
         } else {
           // Cancelled - do nothing, stop saving loader
            if (mounted) setState(() => _isSaving = false);
           return;
         }
      }

      // --- END LOGIC ---

      if (widget.template == null) {
        await _repository.createTemplate(template);
      } else {
        await _repository.updateTemplate(template);
      }

      if (mounted) {
        ModernSnackBar.showSuccess(context, "Plantilla guardada");
        Navigator.pop(context, widget.isSelectionMode ? template : true); 
      }
    } catch (e) {
      if (mounted) {
        ModernSnackBar.showError(context, "Error al guardar: $e");
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showDiscardDialog() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              "¿Descartar cambios?",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Theme.of(ctx).colorScheme.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              "Tienes cambios sin guardar en esta plantilla. Si sales ahora, se perderán para siempre.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.6)),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      'Seguir editando',
                      style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.6), fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.red.shade400, Colors.red.shade700],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.shade400.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Sí, descartar', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final templateColor = Color(_selectedColor);
    
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 1. Fixed Branding Header (No divider)
            const AppHeader(showBottomDivider: false),

            // 2. Hero Banner Standardized (Matching Mis Plantillas)
            GradientBanner(
              title: '',
              icon: Icons.description_rounded, // Matching Templates List View
              height: 85, // Standardized height
              gradientColors: [
                templateColor,
                templateColor.withOpacity(0.8),
              ],
              titleWidget: TextField(
                controller: _nameController,
                style: const TextStyle(
                  fontSize: 18, // Standardized font size
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
                decoration: InputDecoration(
                  hintText: widget.isMomentary ? 'Plantilla Rápida' : 'Nombre de plantilla',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
                onChanged: (_) => setState(() => _hasChanges = true),
              ),
              trailing: _isSaving 
                ? const SizedBox(
                    width: 24, 
                    height: 24, 
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : IconButton(
                    icon: const Icon(Icons.save_rounded, color: Colors.white, size: 28),
                    onPressed: _save,
                    tooltip: 'Guardar plantilla',
                  ),
              onTapIcon: _showColorPicker,
            ),

            // 3. Animated Back Button (Ergonomics)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  _AnimatedBackButton(
                    color: templateColor,
                    onTap: () {
                      if (_hasChanges) {
                        _showDiscardDialog();
                      } else {
                        Navigator.pop(context);
                      }
                    },
                  ),
                ],
              ),
            ),

            // 4. Series List Header & Indicator
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [templateColor, templateColor.withOpacity(0.5)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Series del Entrenamiento",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  if (_blocks.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: templateColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "${_blocks.length} ${_blocks.length == 1 ? 'serie' : 'series'}",
                        style: TextStyle(
                          color: templateColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // 5. Series List
            Expanded(
              child: _blocks.isEmpty
                  ? _buildEmptyState()
                  : ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      itemCount: _blocks.length,
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                           if (oldIndex < newIndex) {
                             newIndex -= 1;
                           }
                           final item = _blocks.removeAt(oldIndex);
                           _blocks.insert(newIndex, item);
                           _reorderBlocks();
                           _hasChanges = true;
                        });
                      },
                      itemBuilder: (context, index) {
                        final block = _blocks[index];
                        return _buildBlockItem(block, index);
                      },
                      proxyDecorator: (Widget child, int index, Animation<double> animation) {
                        return AnimatedBuilder(
                          animation: animation,
                          builder: (BuildContext context, Widget? child) {
                            return Material(
                              elevation: 8,
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(20),
                              shadowColor: Colors.black.withOpacity(0.3),
                              child: child,
                            );
                          },
                          child: child,
                        );
                      },
                      footer: _buildAddBlockCard(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Tema.brandPurple.withOpacity(0.1), Tema.brandPurple.withOpacity(0.05)],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.fitness_center_rounded,
                size: 80,
                color: Tema.brandPurple.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "No hay series añadidas",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Crea tu primera serie para empezar a configurar tu entrenamiento",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 32),
            _buildAddBlockCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockItem(TemplateBlock block, int index) {
    return Dismissible(
      key: ValueKey(block.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.only(right: 24),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
      ),
      onDismissed: (direction) => _deleteBlock(index),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).colorScheme.surface, width: 0),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.transparent
                  : Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            child: InkWell(
              onTap: () => _editBlock(index),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Order / Index Indicator
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Tema.brandPurple, const Color(0xFFBA68C8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Tema.brandPurple.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          "${index + 1}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Info Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${block.value} metros",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.timer_outlined, size: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                              const SizedBox(width: 4),
                              Text(
                                "Descanso: ${block.restSeconds}s",
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (block.alerts.enabled) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.orange.shade100),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.notifications_active_rounded, size: 10, color: Colors.orange.shade700),
                                      const SizedBox(width: 2),
                                      Text(
                                        "ALERTA",
                                        style: TextStyle(
                                          color: Colors.orange.shade700,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Actions Tray (Simplified/Premium)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildActionCircle(
                          icon: Icons.copy_rounded,
                          color: Colors.blue.shade600,
                          onTap: () => _duplicateBlock(index),
                        ),
                        const SizedBox(width: 8),
                        ReorderableDragStartListener(
                          index: index,
                          child: Icon(Icons.drag_indicator_rounded, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.25)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionCircle({required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  void _showColorPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Color de la Plantilla",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Elige un color para identificar rápidamente este entrenamiento en tu historial.",
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 14),
            ),
            const SizedBox(height: 24),
            Center(
              child: Wrap(
                spacing: 20,
                runSpacing: 20,
                children: _availableColors.map((color) {
                  final isSelected = _selectedColor == color;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedColor = color;
                        _hasChanges = true;
                      });
                      Navigator.pop(context);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(color).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: isSelected 
                          ? const Icon(Icons.check, color: Colors.white, size: 22) 
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildAddBlockCard() {
    return Padding(
      key: const ValueKey('add_block_button_footer'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: _addBlock,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade400, Colors.green.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.green.shade600.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.add_rounded, color: Colors.white, size: 32),
              SizedBox(width: 8),
              Text(
                "Añadir Serie",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botón de volver con animación (Adaptado de GroupScreen)
class _AnimatedBackButton extends StatefulWidget {
  final VoidCallback onTap;
  final Color color;
  const _AnimatedBackButton({required this.onTap, this.color = Tema.brandPurple});

  @override
  State<_AnimatedBackButton> createState() => _AnimatedBackButtonState();
}

class _AnimatedBackButtonState extends State<_AnimatedBackButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _isPressed
              ? Theme.of(context).colorScheme.onSurface.withOpacity(0.08)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.transparent
                  : Colors.black.withOpacity(_isPressed ? 0.03 : 0.06),
              blurRadius: _isPressed ? 4 : 12,
              offset: Offset(0, _isPressed ? 2 : 4),
            ),
          ],
          border: Border.all(color: widget.color.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 16,
              color: widget.color,
            ),
            const SizedBox(width: 6),
            Text(
              "Volver",
              style: TextStyle(
                color: widget.color,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
