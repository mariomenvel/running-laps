import 'package:flutter/material.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/core/widgets/app_header.dart'; // Using AppHeader if appropriate, or standard AppBar
import 'package:running_laps/core/widgets/modern_snackbar.dart';
import '../data/template_models.dart';
import '../data/templates_repository.dart';
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
      backgroundColor: const Color(0xFFF5F3F7),
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
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 18),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              'Mis Plantillas',
              style: TextStyle(
                color: Colors.black87, 
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: widget.isSelectionMode 
          ? null 
          : Container(
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
                onPressed: () => _navigateToEditor(),
                backgroundColor: Colors.transparent,
                elevation: 0,
                icon: const Icon(Icons.add_rounded, size: 24),
                label: const Text(
                  'Nueva Plantilla',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
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
                     Icon(Icons.error_outline_rounded, size: 64, color: Colors.red.shade300),
                     const SizedBox(height: 16),
                     Text(
                       'Error al cargar plantillas',
                       style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                     ),
                     const SizedBox(height: 8),
                     Text(
                       '${snapshot.error}',
                       textAlign: TextAlign.center,
                       style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                     ),
                     const SizedBox(height: 24),
                     ElevatedButton(
                       onPressed: _refreshTemplates,
                       style: ElevatedButton.styleFrom(
                         backgroundColor: Tema.brandPurple,
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                       ),
                       child: const Text("Reintentar"),
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Container(
                     padding: const EdgeInsets.all(40),
                     decoration: BoxDecoration(
                       color: Tema.brandPurple.withOpacity(0.05),
                       shape: BoxShape.circle,
                     ),
                     child: Icon(Icons.description_outlined, size: 80, color: Tema.brandPurple.withOpacity(0.4)),
                   ),
                   const SizedBox(height: 32),
                   const Text(
                     'No tienes plantillas guardadas',
                     style: TextStyle(
                       fontSize: 20,
                       fontWeight: FontWeight.bold,
                       color: Colors.black87,
                     ),
                   ),
                   const SizedBox(height: 12),
                   Text(
                     'Crea tu primera plantilla para entrenar\nde forma estructurada.',
                     textAlign: TextAlign.center,
                     style: TextStyle(
                       fontSize: 15,
                       color: Colors.grey.shade600,
                       height: 1.4,
                     ),
                   ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            itemCount: templates.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
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
    final int blockCount = template.blocks.length;
    int totalDist = 0;
    for (var b in template.blocks) {
      if (b.type == TemplateBlockType.distance) totalDist += b.value;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: widget.isSelectionMode 
            ? Border.all(color: Tema.brandPurple.withOpacity(0.4), width: 1.5) 
            : Border.all(color: Colors.white, width: 0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (widget.isSelectionMode) {
                Navigator.pop(context, template);
              } else {
                _navigateToEditor(template: template);
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Tema.brandPurple.withOpacity(0.2), Tema.brandPurple.withOpacity(0.1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      widget.isSelectionMode ? Icons.check_circle_rounded : Icons.fitness_center_rounded, 
                      color: Tema.brandPurple,
                      size: 24,
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
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              '$blockCount series',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              width: 3, height: 3,
                              decoration: BoxDecoration(color: Colors.grey.shade400, shape: BoxShape.circle),
                            ),
                            Text(
                              'Total: ${totalDist}m',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!widget.isSelectionMode)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400, size: 22),
                        onPressed: () => _deleteTemplate(template),
                      ),
                    )
                  else
                    const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.black26),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
