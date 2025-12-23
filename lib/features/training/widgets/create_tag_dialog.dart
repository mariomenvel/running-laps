import 'package:flutter/material.dart';
import 'package:running_laps/app/tema.dart';
import '../data/tag_model.dart';
import '../data/tag_manager.dart';

/// Dialog para crear una nueva etiqueta personalizada
class CreateTagDialog extends StatefulWidget {
  const CreateTagDialog({Key? key}) : super(key: key);

  @override
  State<CreateTagDialog> createState() => _CreateTagDialogState();
}

class _CreateTagDialogState extends State<CreateTagDialog> {
  final TextEditingController _nameController = TextEditingController();
  int _selectedColorIndex = 0;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
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
        colorValue: TagColors.palette[_selectedColorIndex].value,
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nueva Etiqueta',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),

            // Campo de nombre
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Nombre',
                hintText: 'ej: Competición',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                counterText:
                    '${_nameController.text.length}/${TagManager.maxTagNameLength}',
              ),
              maxLength: TagManager.maxTagNameLength,
              onChanged: (value) => setState(() {}),
              enabled: !_isLoading,
            ),
            const SizedBox(height: 20),

            // Selector de color
            const Text(
              'Color:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: List.generate(
                TagColors.palette.length,
                (index) => GestureDetector(
                  onTap: _isLoading
                      ? null
                      : () => setState(() => _selectedColorIndex = index),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: TagColors.palette[index],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _selectedColorIndex == index
                            ? Colors.black87
                            : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: _selectedColorIndex == index
                          ? [
                              BoxShadow(
                                color: TagColors.palette[index]
                                    .withOpacity(0.4),
                                blurRadius: 8,
                                spreadRadius: 2,
                              )
                            ]
                        : [],
                    ),
                    child: _selectedColorIndex == index
                        ? const Icon(Icons.check, color: Colors.white, size: 24)
                        : null,
                  ),
                ),
              ),
            ),

            // Mensaje de error
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Botones
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isLoading ? null : _createTag,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Tema.brandPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Crear'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
