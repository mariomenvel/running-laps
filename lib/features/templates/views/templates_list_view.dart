import 'package:flutter/material.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/utils/app_transitions.dart';
import 'package:running_laps/core/widgets/app_header.dart'; // Using AppHeader if appropriate, or standard AppBar
import 'package:running_laps/core/widgets/modern_snackbar.dart';
import '../data/template_models.dart';
import '../data/templates_repository.dart';
import 'package:running_laps/core/widgets/gradient_banner.dart';
import 'template_editor_view.dart';
import 'package:running_laps/features/profile/views/profile_menu_screen.dart';

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
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
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
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.delete_sweep_rounded, size: 40, color: Colors.red.shade400),
            ),
            const SizedBox(height: 24),
            Text(
              '¿Eliminar plantilla?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Vas a eliminar "${template.name}". Esta acción no se puede deshacer.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontWeight: FontWeight.bold, fontSize: 16),
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
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text(
                        'Eliminar',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
      AppModalRoute(
        page: TemplateEditorView(
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
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              onTapRight: () {
                Navigator.push(
                  context,
                  AppRoute(page: const ProfileMenuView()),
                );
              },
            ),
            GradientBanner(
              title: 'Mis Plantillas',
              subtitle: 'Sesiones personalizadas',
              icon: Icons.description_rounded,
              gradientColors: [Colors.teal.shade400, Colors.teal.shade700],
              height: 85,
            ),
            Expanded(
              child: FutureBuilder<List<TrainingTemplate>>(
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
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${snapshot.error}',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 14),
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
                            child: Icon(Icons.description_outlined, size: 80, color: (Theme.of(context).brightness == Brightness.dark ? AppColors.brandPurpleLight : Tema.brandPurple).withOpacity(0.4)),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            'No tienes plantillas guardadas',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Crea tu primera plantilla para entrenar\nde forma estructurada.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
            ),
            if (!widget.isSelectionMode) _buildBottomAction(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.transparent
                : Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: () => _navigateToEditor(),
        child: Container(
          height: 60,
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
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, color: Colors.white, size: 32),
                SizedBox(width: 8),
                Text(
                  "NUEVA PLANTILLA",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateCard(TrainingTemplate template) {
    final int blockCount = template.blocks.length;
    int totalDist = 0;
    for (var b in template.blocks) {
      if (b.type == TemplateBlockType.distance) totalDist += b.value;
    }

    final templateColor = Color(template.colorValue);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.transparent
                : Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: widget.isSelectionMode
            ? Border.all(color: templateColor.withOpacity(0.4), width: 1.5)
            : Border.all(color: Theme.of(context).colorScheme.surface, width: 0),
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
                        colors: [templateColor.withOpacity(0.2), templateColor.withOpacity(0.1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      widget.isSelectionMode ? Icons.check_circle_rounded : Icons.description_rounded, 
                      color: templateColor,
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
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
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
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              width: 3, height: 3,
                              decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35), shape: BoxShape.circle),
                            ),
                            Text(
                              'Total: ${totalDist}m',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
                    Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.25)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
