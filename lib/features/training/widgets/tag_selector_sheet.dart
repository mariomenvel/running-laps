import 'package:flutter/material.dart';
import 'package:running_laps/app/tema.dart';
import '../data/tag_model.dart';
import '../data/tag_manager.dart';
import '../data/training_repository.dart';
import '../data/entrenamiento.dart';
import 'tag_chip.dart';
import 'create_tag_dialog.dart';

/// Bottom sheet para seleccionar etiquetas de un entrenamiento
class TagSelectorSheet extends StatefulWidget {
  final Entrenamiento training;
  final String trainingId;

  const TagSelectorSheet({
    Key? key,
    required this.training,
    required this.trainingId,
  }) : super(key: key);

  @override
  State<TagSelectorSheet> createState() => _TagSelectorSheetState();
}

class _TagSelectorSheetState extends State<TagSelectorSheet> {
  final TagManager _tagManager = TagManager();
  final TrainingRepository _trainingRepo = TrainingRepository();

  List<TrainingTag> _availableTags = [];
  Set<String> _selectedTagNames = {};
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedTagNames = Set.from(widget.training.tags ?? []);
    _loadAvailableTags();
  }

  Future<void> _loadAvailableTags() async {
    setState(() => _isLoading = true);

    try {
      final tags = await _tagManager.getUserTags();
      setState(() {
        _availableTags = tags;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar etiquetas';
        _isLoading = false;
      });
    }
  }

  void _toggleTag(String tagName) {
    setState(() {
      if (_selectedTagNames.contains(tagName)) {
        _selectedTagNames.remove(tagName);
      } else {
        if (_selectedTagNames.length >= 5) {
          // Límite de 5 etiquetas por entrenamiento
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Máximo 5 etiquetas por entrenamiento'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        _selectedTagNames.add(tagName);
      }
    });
  }

  Future<void> _createNewTag() async {
    final newTag = await showDialog<TrainingTag>(
      context: context,
      builder: (context) => const CreateTagDialog(),
    );

    if (newTag != null) {
      await _loadAvailableTags();
      setState(() {
        _selectedTagNames.add(newTag.name);
      });
    }
  }

  Future<void> _saveTags() async {
    setState(() => _isSaving = true);

    try {
      await _trainingRepo.updateTrainingTags(
        widget.trainingId,
        _selectedTagNames.toList(),
      );

      if (mounted) {
        Navigator.of(context).pop(true); // Indicar que se guardaron cambios
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al guardar: ${e.toString()}';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text(
                'Etiquetas',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${_selectedTagNames.length}/5 seleccionadas',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 20),

          // Loading o lista de etiquetas
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(color: Tema.brandPurple),
              ),
            )
          else if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 12),
                    Text(_errorMessage!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _loadAvailableTags,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Wrap de etiquetas disponibles
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._availableTags.map((tag) {
                  final isSelected = _selectedTagNames.contains(tag.name);
                  return GestureDetector(
                    onTap: () => _toggleTag(tag.name),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? tag.color.withOpacity(0.15)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? tag.color
                              : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              size: 16,
                              color: tag.color,
                            ),
                          if (isSelected) const SizedBox(width: 6),
                          Text(
                            tag.name,
                            style: TextStyle(
                              color: isSelected
                                  ? tag.color
                                  : Colors.grey.shade700,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                // Botón "+ Nueva etiqueta"
                GestureDetector(
                  onTap: _createNewTag,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Tema.brandPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Tema.brandPurple,
                        width: 1,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_circle_outline,
                          size: 16,
                          color: Tema.brandPurple,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Nueva etiqueta',
                          style: TextStyle(
                            color: Tema.brandPurple,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),

          // Botones de acción
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveTags,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Tema.brandPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                    : const Text('Guardar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
