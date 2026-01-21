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
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(
          widget.isMomentary 
              ? 'Plantilla Rápida' 
              : (widget.template == null ? 'Nueva Plantilla' : 'Editar Plantilla'),
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving 
               ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
               : Text(
                   (widget.isMomentary || widget.isSelectionMode) ? "Usar" : "Guardar", 
                   style: const TextStyle(color: Tema.brandPurple, fontWeight: FontWeight.bold)
                 ),
          )
        ],
      ),
      body: Column(
        children: [
          // Name Input
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Nombre de la plantilla',
                hintText: 'Ej. Series 400m',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ),
          
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text("Series", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
            ),
          ),
          
          Expanded(
            child: _blocks.isEmpty
                ? Center(
                    child: Text(
                      "No hay series añadidas",
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addBlock,
        backgroundColor: Tema.brandPurple,
        icon: const Icon(Icons.add),
        label: const Text("Añadir Serie"),
      ),
    );
  }

  Widget _buildBlockItem(TemplateBlock block, int index) {
    return Container(
      key: ValueKey(block.id), // Important for reorderable list
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
           BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
        ]
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 32, height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Tema.brandPurple.withOpacity(0.1), shape: BoxShape.circle),
          child: Text("${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold, color: Tema.brandPurple)),
        ),
        title: Text(
          "${block.value} metros",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          "Descanso: ${block.restSeconds}s" + (block.alerts.enabled ? " • Alerta Activa" : ""),
          style: TextStyle(color: Colors.grey.shade600),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
             IconButton(
               icon: const Icon(Icons.copy, size: 20, color: Colors.blueGrey), 
               onPressed: () => _duplicateBlock(index),
               tooltip: "Duplicar",
             ),
             IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _editBlock(index)),
             IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red), onPressed: () => _deleteBlock(index)),
             const  Icon(Icons.drag_handle, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
