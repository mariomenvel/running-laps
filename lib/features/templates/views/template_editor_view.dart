import 'package:flutter/material.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';
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

  @override
  void initState() {
    super.initState();
    if (widget.template != null) {
      _nameController.text = widget.template!.name;
      _blocks = List.from(widget.template!.blocks);
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
         
         // Ask user
         final result = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Confirmar cambios"),
              content: const Text("Has modificado la plantilla. ¿Cómo quieres usarla?"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'temp'),
                  child: const Text("Solo esta vez"),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'update'),
                  child: const Text("Actualizar original", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3F7), // Subtle purple tint
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, const Color(0xFFFAF9FB)],
            ),
            boxShadow: [
              BoxShadow(
                color: Tema.brandPurple.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.black87, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              widget.isMomentary 
                  ? 'Plantilla Rápida' 
                  : (widget.template == null ? 'Nueva Plantilla' : 'Editar Plantilla'),
              style: const TextStyle(
                color: Colors.black87, 
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Tema.brandPurple,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: Tema.brandPurple.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: _isSaving 
                      ? const SizedBox(
                          width: 16, 
                          height: 16, 
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          (widget.isMomentary || widget.isSelectionMode) ? "Usar" : "Guardar",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Premium Name Input Card
          Container(
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Tema.brandPurple.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Tema.brandPurple.withOpacity(0.2), Tema.brandPurple.withOpacity(0.1)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.edit_note_rounded, color: Tema.brandPurple, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        labelText: 'Nombre de la plantilla',
                        labelStyle: TextStyle(color: Colors.grey.shade600),
                        hintText: 'Ej. Series 400m',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Section Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Tema.brandPurple, Color(0xFFBA68C8)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  "Series",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                if (_blocks.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Tema.brandPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${_blocks.length} ${_blocks.length == 1 ? 'serie' : 'series'}",
                      style: const TextStyle(
                        color: Tema.brandPurple,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Series List
          Expanded(
            child: _blocks.isEmpty
                ? _buildEmptyState()
                : ReorderableListView.builder(
                    buildDefaultDragHandles: false, // Fix overlapping handles
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
                  ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Tema.brandPurple, Color(0xFF6A1B9A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Tema.brandPurple.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _addBlock,
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.add_rounded, size: 24),
          label: const Text(
            "Añadir Serie",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
          const Text(
            "No hay series añadidas",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Pulsa el botón para crear tu primera serie",
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockItem(TemplateBlock block, int index) {
    return Container(
      key: ValueKey(block.id),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.white,
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
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.timer_outlined, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              "Descanso: ${block.restSeconds}s",
                              style: TextStyle(
                                color: Colors.grey.shade600,
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
                      _buildActionCircle(
                        icon: Icons.delete_outline_rounded,
                        color: Colors.red.shade400,
                        onTap: () => _deleteBlock(index),
                      ),
                      const SizedBox(width: 8),
                      ReorderableDragStartListener(
                        index: index,
                        child: const Icon(Icons.drag_indicator_rounded, color: Colors.black26),
                      ),
                    ],
                  ),
                ],
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
}
