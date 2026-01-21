import 'package:flutter/material.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/core/widgets/app_header.dart'; // Using AppHeader if appropriate, or standard AppBar
import 'package:running_laps/core/widgets/modern_snackbar.dart';
import '../data/template_models.dart';
import '../data/training_templates_repository.dart';
import 'template_editor_view.dart';

class TemplatesListView extends StatefulWidget {
  final bool isSelectionMode;
  const TemplatesListView({Key? key, this.isSelectionMode = false}) : super(key: key);

  @override
  _TemplatesListViewState createState() => _TemplatesListViewState();
}

class _TemplatesListViewState extends State<TemplatesListView> {
  final TrainingTemplatesRepository _repository = TrainingTemplatesRepository();
  late Future<List<TrainingTemplate>> _templatesFuture;

  @override
  void initState() {
    super.initState();
    _refreshTemplates();
  }

  void _refreshTemplates() {
    setState(() {
      _templatesFuture = _repository.getUserTemplates();
    });
  }


  Future<void> _deleteTemplate(TrainingTemplate template) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar plantilla'),
        content: Text('¿Seguro que quieres eliminar "${template.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _repository.deleteTemplate(template.id);
        if (mounted) {
          ModernSnackBar.showSuccess(context, 'Plantilla eliminada');
          _refreshTemplates();
        }
      } catch (e) {
        if (mounted) {
          ModernSnackBar.showError(context, 'Error al eliminar: $e');
        }
      }
    }
  }

  void _navigateToEditor({TrainingTemplate? template}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TemplateEditorView(
          template: template,
          isSelectionMode: widget.isSelectionMode, // Pass selection mode
        ),
      ),
    );
    
    // If selecting, result is the template to use
    if (widget.isSelectionMode && result != null) {
      if (!mounted) return;
      Navigator.pop(context, result);
      return;
    }

    // Normal editing: If we saved/updated, refresh
    if (result == true) {
      _refreshTemplates();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'Mis Plantillas',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      floatingActionButton: widget.isSelectionMode ? null : FloatingActionButton.extended(
        onPressed: () => _navigateToEditor(),
        backgroundColor: Tema.brandPurple,
        icon: const Icon(Icons.add),
        label: const Text('Nueva Plantilla'),
      ),
      body: FutureBuilder<List<TrainingTemplate>>(
        future: _templatesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Tema.brandPurple));
          }
          if (snapshot.hasError) {
             return Center(
               child: Padding(
                 padding: const EdgeInsets.all(24.0),
                 child: Column(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
                     const SizedBox(height: 16),
                     Text(
                       'Error al cargar plantillas:\n${snapshot.error}',
                       textAlign: TextAlign.center,
                       style: TextStyle(color: Colors.grey.shade600),
                     ),
                     const SizedBox(height: 16),
                     TextButton(
                       onPressed: _refreshTemplates,
                       child: const Text('Reintentar'),
                     ),
                   ],
                 ),
               ),
             );
          }

          final templates = snapshot.data ?? [];

          if (templates.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Container(
                     padding: const EdgeInsets.all(24),
                     decoration: BoxDecoration(
                       color: Tema.brandPurple.withOpacity(0.1),
                       shape: BoxShape.circle,
                     ),
                     child: const Icon(Icons.description_outlined, size: 48, color: Tema.brandPurple),
                   ),
                   const SizedBox(height: 24),
                   const Text(
                     'No tienes plantillas guardadas',
                     style: TextStyle(
                       fontSize: 18,
                       fontWeight: FontWeight.bold,
                       color: Colors.black87,
                     ),
                   ),
                   const SizedBox(height: 8),
                   Text(
                     'Crea tu primera plantilla para entrenar\nde forma estructurada.',
                     textAlign: TextAlign.center,
                     style: TextStyle(
                       fontSize: 14,
                       color: Colors.grey.shade600,
                     ),
                   ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: templates.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final template = templates[index];
              return _buildTemplateCard(template);
            },
          );
        },
      ),
    );
  }

  Widget _buildTemplateCard(TrainingTemplate template) {
    // Calculate summary
    final int blockCount = template.blocks.length;
    int totalDist = 0;
    for (var b in template.blocks) {
      if (b.type == TemplateBlockType.distance) totalDist += b.value;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: widget.isSelectionMode 
            ? Border.all(color: Tema.brandPurple.withOpacity(0.3)) 
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            if (widget.isSelectionMode) {
              Navigator.pop(context, template);
            } else {
              _navigateToEditor(template: template);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Tema.brandPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    widget.isSelectionMode ? Icons.check_circle_outline : Icons.fitness_center, 
                    color: Tema.brandPurple
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$blockCount series • Total: ${totalDist}m',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!widget.isSelectionMode)
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.grey.shade400),
                    onPressed: () => _deleteTemplate(template),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
