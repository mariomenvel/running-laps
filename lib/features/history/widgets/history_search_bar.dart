import 'package:flutter/material.dart';
import 'package:running_laps/config/app_theme.dart';

/// Search bar estilo iOS para el Historial
/// 
/// Diseño premium con fondo gris claro, icono de lupa, y botón X para limpiar
class HistorySearchBar extends StatefulWidget {
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final String hintText;

  const HistorySearchBar({
    Key? key,
    required this.query,
    required this.onChanged,
    required this.onClear,
    this.hintText = 'Buscar entrenamientos...',
  }) : super(key: key);

  @override
  State<HistorySearchBar> createState() => _HistorySearchBarState();
}

class _HistorySearchBarState extends State<HistorySearchBar> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Icono de búsqueda
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 8),
            child: Icon(
              Icons.search_rounded,
              color: Colors.grey.shade500,
              size: 20,
            ),
          ),
          
          // Campo de texto
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: widget.onChanged,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 15,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          
          // Botón X para limpiar (solo visible si hay texto)
          if (widget.query.isNotEmpty)
            GestureDetector(
              onTap: () {
                _controller.clear();
                widget.onClear();
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 12, left: 8),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

