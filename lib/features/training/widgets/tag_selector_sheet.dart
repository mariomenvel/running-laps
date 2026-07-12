import 'package:flutter/material.dart';
import 'package:running_laps/core/constants/training_tags.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import '../data/tag_model.dart';
import '../data/tag_manager.dart';
import '../data/training_repository.dart';
import '../data/entrenamiento.dart';
import '../../../core/widgets/modern_snackbar.dart';

class TagSelectorSheet extends StatefulWidget {
  final Entrenamiento training;
  final String trainingId;

  const TagSelectorSheet({
    super.key,
    required this.training,
    required this.trainingId,
  });

  @override
  State<TagSelectorSheet> createState() => _TagSelectorSheetState();
}

class _TagSelectorSheetState extends State<TagSelectorSheet> {
  final TagManager _tagManager = TagManager();
  final TrainingRepository _trainingRepo = TrainingRepository();
  final TextEditingController _newTagController = TextEditingController();
  final FocusNode _newTagFocus = FocusNode();

  List<TrainingTag> _customTags = [];
  Set<String> _selectedTagNames = {};
  bool _isLoading = true;
  bool _isSaving = false;
  bool _showNewTagField = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedTagNames = Set.from(widget.training.tags ?? []);
    _loadCustomTags();
  }

  @override
  void dispose() {
    _newTagController.dispose();
    _newTagFocus.dispose();
    super.dispose();
  }

  Future<void> _loadCustomTags() async {
    setState(() => _isLoading = true);
    try {
      final all = await _tagManager.getUserTags();
      setState(() {
        _customTags = all
            .where((t) => !TrainingTags.isPredefined(t.name))
            .toList();
        _isLoading = false;
      });
    } catch (_) {
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
          ModernSnackBar.showWarning(
              context, 'Máximo 5 etiquetas por entrenamiento');
          return;
        }
        _selectedTagNames.add(tagName);
      }
    });
  }

  Future<void> _createInlineTag() async {
    final name = _newTagController.text.trim().toLowerCase();
    if (name.isEmpty) return;
    if (name.length > 20) {
      ModernSnackBar.showWarning(context, 'Máximo 20 caracteres');
      return;
    }
    try {
      await _tagManager.createTag(TrainingTag(
        name: name,
        colorValue: 0xFF9E9E9E,
      ));
      if (!mounted) return;
      _newTagController.clear();
      setState(() => _showNewTagField = false);
      await _loadCustomTags();
      if (!mounted) return;
      if (_selectedTagNames.length < 5) {
        setState(() => _selectedTagNames.add(name));
      }
    } catch (e) {
      if (!mounted) return;
      ModernSnackBar.showError(context, 'Error al crear etiqueta');
    }
  }

  Future<void> _saveTags() async {
    setState(() => _isSaving = true);
    try {
      await _trainingRepo.updateTrainingTags(
        widget.trainingId,
        _selectedTagNames.toList(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al guardar: $e';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Etiquetas',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close,
                      color: AppColors.iconMutedOf(context)),
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
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: AppColors.brand),
                ),
              )
            else if (_errorMessage != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.rpeMax, size: 48),
                      const SizedBox(height: 12),
                      Text(_errorMessage!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      TextButton(
                          onPressed: _loadCustomTags,
                          child: const Text('Reintentar')),
                    ],
                  ),
                ),
              )
            else ...[
              _SectionLabel(label: 'Categorías', context: context),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: TrainingTags.predefined.map((name) {
                  final isSelected = _selectedTagNames.contains(name);
                  return _TagToggleChip(
                    name: name,
                    isSelected: isSelected,
                    isPredefined: true,
                    onTap: () => _toggleTag(name),
                    context: context,
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              _SectionLabel(label: 'Mis etiquetas', context: context),
              const SizedBox(height: 8),
              if (_customTags.isEmpty && !_showNewTagField)
                Text(
                  'Sin etiquetas personalizadas aún',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary(context),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _customTags.map((tag) {
                    final isSelected = _selectedTagNames.contains(tag.name);
                    return _TagToggleChip(
                      name: tag.name,
                      isSelected: isSelected,
                      isPredefined: false,
                      onTap: () => _toggleTag(tag.name),
                      context: context,
                    );
                  }).toList(),
                ),
              const SizedBox(height: 12),
              if (_showNewTagField)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newTagController,
                        focusNode: _newTagFocus,
                        autofocus: true,
                        textCapitalization: TextCapitalization.none,
                        style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary(context)),
                        decoration: InputDecoration(
                          hintText: 'Nombre de etiqueta',
                          hintStyle: TextStyle(
                              color: AppColors.textSecondary(context)),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                                color: AppColors.borderOf(context), width: 0.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                                color: AppColors.borderOf(context), width: 0.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: AppColors.brand, width: 1.5),
                          ),
                        ),
                        onSubmitted: (_) => _createInlineTag(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _createInlineTag,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.brandOf(context),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                      ),
                      child: const Text('Añadir',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    TextButton(
                      onPressed: () {
                        _newTagController.clear();
                        setState(() => _showNewTagField = false);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary(context),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 10),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ],
                )
              else
                GestureDetector(
                  onTap: () => setState(() => _showNewTagField = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.brand, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_circle_outline,
                            size: 16,
                            color: AppColors.brandOf(context)),
                        const SizedBox(width: 6),
                        Text(
                          '+ Crear etiqueta',
                          style: TextStyle(
                            color: AppColors.brandOf(context),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _isSaving ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveTags,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Guardar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final BuildContext context;
  const _SectionLabel({required this.label, required this.context});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.iconMutedOf(context),
        letterSpacing: 1.1,
      ),
    );
  }
}

class _TagToggleChip extends StatelessWidget {
  final String name;
  final bool isSelected;
  final bool isPredefined;
  final VoidCallback onTap;
  final BuildContext context;

  const _TagToggleChip({
    required this.name,
    required this.isSelected,
    required this.isPredefined,
    required this.onTap,
    required this.context,
  });

  @override
  Widget build(BuildContext ctx) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    final Color activeText =
        AppColors.brandOf(context);
    final Color inactiveText = AppColors.textSecondary(ctx);
    final Color activeBg = AppColors.brand.withValues(alpha: 0.15);
    final Color inactiveBg = isPredefined
        ? AppColors.brand.withValues(alpha: 0.05)
        : AppColors.surface2Of(ctx);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.brand
                : AppColors.borderOf(ctx),
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Icon(Icons.check_circle_rounded,
                  size: 14, color: activeText),
              const SizedBox(width: 5),
            ],
            Text(
              name,
              style: TextStyle(
                color: isSelected ? activeText : inactiveText,
                fontWeight: isSelected
                    ? FontWeight.w600
                    : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
