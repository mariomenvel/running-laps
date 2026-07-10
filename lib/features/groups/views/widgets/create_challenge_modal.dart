import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/enums.dart';
import 'package:running_laps/config/app_theme.dart';


class CreateChallengeModal extends StatefulWidget {
  final void Function(
    String title,
    GoalKind kind,
    double value,
    DateTime start,
    DateTime end,
  ) onCreate;

  const CreateChallengeModal({
    Key? key,
    required this.onCreate,
  }) : super(key: key);

  @override
  State<CreateChallengeModal> createState() => _CreateChallengeModalState();
}

class _CreateChallengeModalState extends State<CreateChallengeModal>
    with TickerProviderStateMixin {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();

  GoalKind _selectedKind = GoalKind.distance;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  bool _isCreating = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Gradient colors: brandPurple → metric accent (consistent with ChallengeColorHelper)
  static const Map<GoalKind, List<Color>> _kindGradients = {
    GoalKind.distance: [AppColors.rest, AppColors.rest],
    GoalKind.time: [AppColors.rpeMid, AppColors.rpeMid],
    GoalKind.sessions: [AppColors.brand, AppColors.brand],
  };

  static const Map<GoalKind, IconData> _kindIcons = {
    GoalKind.distance: Icons.straighten_rounded,
    GoalKind.time: Icons.timer_rounded,
    GoalKind.sessions: Icons.fitness_center_rounded,
  };

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _valueController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selectedGradient = _kindGradients[_selectedKind]!;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
        ),
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 28,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: cs.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Header
              _buildHeader(selectedGradient),
              const SizedBox(height: 28),

              // Nombre del Reto
              _buildSectionTitle("NOMBRE DEL RETO"),
              const SizedBox(height: 10),
              _buildTitleInput(),
              const SizedBox(height: 24),

              // Tipo de Objetivo
              _buildSectionTitle("TIPO DE OBJETIVO"),
              const SizedBox(height: 12),
              _buildMetricSelector(),
              const SizedBox(height: 24),

              // Valor del Objetivo
              _buildSectionTitle(_getGoalLabel()),
              const SizedBox(height: 10),
              _buildValueInput(selectedGradient),
              const SizedBox(height: 24),

              // Fechas
              _buildSectionTitle("PERÍODO DEL RETO"),
              const SizedBox(height: 12),
              _buildDatePickers(),
              const SizedBox(height: 32),

              // Botón Crear
              _buildCreateButton(selectedGradient),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(List<Color> gradient) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: gradient.first,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: gradient.first.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            _kindIcons[_selectedKind],
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Crear Nuevo Reto",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Desafía a tu grupo 🔥",
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.close, size: 18, color: cs.onSurface.withValues(alpha: 0.6)),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: cs.onSurface.withValues(alpha: 0.5),
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildTitleInput() {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: _titleController,
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface),
      decoration: InputDecoration(
        hintText: "Ej: Semana de Runner 🏃",
        hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.4), fontWeight: FontWeight.normal),
        filled: true,
        fillColor: cs.onSurface.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.brand, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 10),
          child: Icon(Icons.edit_rounded, color: cs.onSurface.withValues(alpha: 0.4)),
        ),
      ),
    );
  }

  Widget _buildMetricSelector() {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [GoalKind.distance, GoalKind.time, GoalKind.sessions].map((kind) {
        final bool isSelected = _selectedKind == kind;
        final gradient = _kindGradients[kind]!;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: kind != GoalKind.sessions ? 10 : 0),
            child: GestureDetector(
              onTap: () => setState(() => _selectedKind = kind),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: isSelected ? gradient.first : cs.onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(18),
                  border: isSelected
                      ? null
                      : Border.all(color: cs.outline.withValues(alpha: 0.3)),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: gradient.first.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    Icon(
                      _kindIcons[kind],
                      color: isSelected ? Colors.white : cs.onSurface.withValues(alpha: 0.5),
                      size: 26,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getKindLabel(kind),
                      style: TextStyle(
                        color: isSelected ? Colors.white : cs.onSurface.withValues(alpha: 0.6),
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildValueInput(List<Color> selectedGradient) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: _valueController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: selectedGradient.first,
      ),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        hintText: _getValueHint(),
        hintStyle: TextStyle(
          color: cs.onSurface.withValues(alpha: 0.4),
          fontWeight: FontWeight.normal,
          fontSize: 18,
        ),
        filled: true,
        fillColor: cs.onSurface.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: selectedGradient.first, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        suffixText: _getValueSuffix(),
        suffixStyle: TextStyle(
          color: selectedGradient.first,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildDatePickers() {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(child: _buildDateCard("Inicio", _startDate, true)),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cs.onSurface.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.arrow_forward, color: cs.onSurface.withValues(alpha: 0.4), size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(child: _buildDateCard("Fin", _endDate, false)),
      ],
    );
  }

  Widget _buildDateCard(String label, DateTime date, bool isStart) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: AppColors.brand,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Colors.black87,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          setState(() {
            if (isStart) {
              _startDate = picked;
              if (_endDate.isBefore(_startDate)) {
                _endDate = _startDate.add(const Duration(days: 7));
              }
            } else {
              _endDate = picked;
            }
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              DateFormat('dd MMM').format(date),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat('yyyy').format(date),
              style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.4)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateButton(List<Color> gradient) {
    return GestureDetector(
      onTap: _isCreating ? null : _handleCreate,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 60,
        decoration: BoxDecoration(
          color: _isCreating ? AppColors.iconMuted : Colors.black,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _isCreating ? 0.1 : 0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: _isCreating
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 22),
                    SizedBox(width: 12),
                    Text(
                      "Crear Reto",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  void _handleCreate() {
    final title = _titleController.text.trim();
    final valueStr = _valueController.text.trim();

    if (title.isEmpty) {
      _showError("Por favor ingresa un nombre para el reto");
      return;
    }

    final value = double.tryParse(valueStr);
    if (value == null || value <= 0) {
      _showError("Por favor ingresa un valor válido");
      return;
    }

    if (_endDate.isBefore(_startDate) || _endDate.isAtSameMomentAs(_startDate)) {
      _showError("La fecha de fin debe ser posterior a la de inicio");
      return;
    }

    setState(() => _isCreating = true);

    Navigator.pop(context);
    widget.onCreate(title, _selectedKind, value, _startDate, _endDate);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Text(msg),
          ],
        ),
        backgroundColor: AppColors.rpeMax,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _getKindLabel(GoalKind kind) {
    switch (kind) {
      case GoalKind.distance: return "Distancia";
      case GoalKind.time: return "Tiempo";
      case GoalKind.sessions: return "Sesiones";
      default: return "";
    }
  }

  String _getGoalLabel() {
    switch (_selectedKind) {
      case GoalKind.distance: return "OBJETIVO EN KILÓMETROS";
      case GoalKind.time: return "OBJETIVO EN MINUTOS";
      case GoalKind.sessions: return "OBJETIVO EN SESIONES";
      default: return "OBJETIVO";
    }
  }

  String _getValueHint() {
    switch (_selectedKind) {
      case GoalKind.distance: return "Ej: 50";
      case GoalKind.time: return "Ej: 120";
      case GoalKind.sessions: return "Ej: 5";
      default: return "";
    }
  }

  String _getValueSuffix() {
    switch (_selectedKind) {
      case GoalKind.distance: return "km";
      case GoalKind.time: return "min";
      case GoalKind.sessions: return "sesiones";
      default: return "";
    }
  }
}
