import 'package:flutter/material.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/core/theme/app_theme.dart' show AppMotion;
import '../data/tag_model.dart';
import '../data/tag_manager.dart';

/// Bottom sheet moderno para crear una nueva etiqueta personalizada
class CreateTagDialog extends StatefulWidget {
  const CreateTagDialog({super.key});

  @override
  State<CreateTagDialog> createState() => _CreateTagDialogState();
}

class _CreateTagDialogState extends State<CreateTagDialog> with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  int _selectedColorIndex = 2; // Verde por defecto
  bool _isLoading = false;
  String? _errorMessage;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: AppMotion.base,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _createTag() async {
    final String name = _nameController.text.trim();

    if (name.isEmpty) {
      setState(() => _errorMessage = 'El nombre no puede estar vacío');
      return;
    }

    if (name.length > TagManager.maxTagNameLength) {
      setState(() =>
          _errorMessage =
              'Máximo ${TagManager.maxTagNameLength} caracteres');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tagManager = TagManager();

      // Verificar si ya existe
      final exists = await tagManager.tagExists(name);
      if (exists) {
        setState(() {
          _errorMessage = 'Ya existe una etiqueta con ese nombre';
          _isLoading = false;
        });
        return;
      }

      // Crear tag
      final newTag = TrainingTag(
        name: name,
        colorValue: TagColors.palette[_selectedColorIndex].toARGB32(),
      );

      await tagManager.createTag(newTag);

      if (mounted) {
        Navigator.of(context).pop(newTag); // Retornar el tag creado
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
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
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Título
          const Text(
            'Nueva Etiqueta',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 24),

          // Campo de nombre (estilo iOS limpio)
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Nombre',
              hintText: 'ej: Competición',
              hintStyle: TextStyle(color: AppColors.iconMuted),
              labelStyle: TextStyle(color: AppColors.iconMuted, fontSize: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.iconMuted),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.iconMuted),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.brand, width: 2),
              ),
              filled: true,
              fillColor: AppColors.iconMuted,
              counterText:
                  '${_nameController.text.length}/${TagManager.maxTagNameLength}',
              counterStyle: TextStyle(color: AppColors.iconMuted, fontSize: 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            ),
            maxLength: TagManager.maxTagNameLength,
            onChanged: (value) => setState(() {}),
            enabled: !_isLoading,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 28),

          // Selector de color
          const Text(
            'Color:',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: List.generate(
              TagColors.palette.length,
              (index) => GestureDetector(
                onTap: _isLoading
                    ? null
                    : () {
                        setState(() => _selectedColorIndex = index);
                        _animController.forward(from: 0);
                      },
                child: AnimatedContainer(
                  duration: AppMotion.base,
                  curve: AppMotion.snap,
                  width: _selectedColorIndex == index ? 50 : 46,
                  height: _selectedColorIndex == index ? 50 : 46,
                  decoration: BoxDecoration(
                    color: TagColors.palette[index],
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _selectedColorIndex == index
                          ? Colors.black87
                          : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: _selectedColorIndex == index
                        ? [
                            BoxShadow(
                              color: TagColors.palette[index]
                                  .withValues(alpha: 0.5),
                              blurRadius: 12,
                              spreadRadius: 2,
                            )
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            )
                          ],
                  ),
                  child: _selectedColorIndex == index
                      ? const Icon(Icons.check, color: Colors.white, size: 28)
                      : null,
                ),
              ),
            ),
          ),

          // Mensaje de error
          if (_errorMessage != null) ...{
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.rpeMax,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.rpeMax),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: AppColors.rpeMax, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: AppColors.rpeMax,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          },

          const SizedBox(height: 28),

          // Botones
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    side: BorderSide(color: AppColors.iconMuted),
                  ),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.iconMuted,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createTag,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: AppColors.brand.withValues(alpha: 0.4),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Crear',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

