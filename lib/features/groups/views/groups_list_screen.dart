import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:running_laps/core/utils/app_transitions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

// Repositories
import '../data/repositories/user_groups_repository.dart';
import '../data/repositories/groups_repository.dart';
import '../data/repositories/invites_repository.dart';

// Models
import '../data/models/group_models.dart';
import '../data/models/enums.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import '../../../../core/widgets/modern_snackbar.dart';

// Widgets
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/app_footer.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/gradient_banner.dart';
import '../../../core/widgets/skeleton_shimmer.dart';
import 'package:running_laps/config/app_theme.dart';

// Navigation
import 'group_screen.dart';
import '../../training/views/training_start_view.dart';
import '../../profile/views/profile_menu_screen.dart';
import '../data/models/result_notification_model.dart';
import 'widgets/challenge_result_dialog.dart';

/// Pantalla profesional y moderna que lista todos los grupos del usuario
/// Diseño premium con gradientes vibrantes y animaciones fluidas
class GroupsListScreen extends StatefulWidget {
  const GroupsListScreen({Key? key}) : super(key: key);

  @override
  State<GroupsListScreen> createState() => _GroupsListScreenState();
}

class _GroupsListScreenState extends State<GroupsListScreen> {
  final UserGroupsRepository _userGroupsRepo = UserGroupsRepository();
  final GroupsRepository _groupsRepo = GroupsRepository();

  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header Premium
            AppHeader(
              onTapRight: () {
                Navigator.push(
                  context,
                  AppRoute(page: const ProfileMenuView()),
                );
              },
              showBottomDivider: false,
            ),

            // 2. Banner decorativo con gradiente
            GradientBanner(
              title: 'Mis Grupos',
              subtitle: 'Compite con tu comunidad de corredores',
              icon: Icons.groups_3_rounded,
              gradientColors: [
                Colors.blueAccent,
                Colors.lightBlue,
              ],
              height: 90,
            ),

            // 3. Lista de Grupos
            Expanded(
              child: _currentUserId == null
                  ? _buildLoginPrompt()
                  : StreamBuilder<List<UserGroupMembership>>(
                      stream: _userGroupsRepo.streamUserGroups(_currentUserId!),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return _buildLoadingState();
                        }

                        final memberships = snapshot.data ?? [];

                        if (memberships.isEmpty) {
                          return _buildEmptyState();
                        }

                        // Separar pendientes y activos
                        final pending = memberships
                            .where((m) => m.status == MemberStatus.pending)
                            .toList();
                        final active = memberships
                            .where((m) => m.status == MemberStatus.active)
                            .toList();

                        return ListView(
                          padding: const EdgeInsets.only(
                            left: 20,
                            right: 20,
                            top: 16,
                            bottom: 120,
                          ),
                          children: [
                            // SECTION: JOIN BY CODE
                            _JoinByCodeBanner(currentUserId: _currentUserId!),
                            const SizedBox(height: 16),

                            // SECTION: INVITATIONS
                            if (pending.isNotEmpty) ...[
                              _buildSectionTitle("Invitaciones Pendientes 📩"),
                              const SizedBox(height: 12),
                              ...pending.map((m) => _InvitationCard(
                                    membership: m,
                                    groupsRepo: _groupsRepo,
                                    currentUserId: _currentUserId!,
                                  )),
                              const SizedBox(height: 24),
                              _buildSectionTitle("Mis Grupos"),
                              const SizedBox(height: 12),
                            ],

                            // SECTION: ACTIVE GROUPS
                            if (active.isEmpty && pending.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Center(
                                  child: Text(
                                    "Acepta una invitación o crea un grupo",
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              )
                            else 
                              ...List.generate(active.length, (index) {
                                final m = active[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _StaggeredGroupItem(
                                    index: index,
                                    child: _PremiumGroupCard(
                                      groupId: m.groupId,
                                      groupsRepo: _groupsRepo,
                                      colorIndex: index,
                                    ),
                                  ),
                                );
                              }),
                          ],
                        );
                      },
                    ),
            ),

            // 4. Footer Intacto
            AppFooter(
              onTap: () {
                 Navigator.of(context).push(
                  AppRoute(page: TrainingStartView()),
                );
              },
            ),
          ],
        ),
      ),
      
      floatingActionButton: Builder(
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Container(
            height: 56,
            width: 56,
            margin: const EdgeInsets.only(bottom: 130, right: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.transparent : Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _handleCreateGroup,
            borderRadius: BorderRadius.circular(28),
            child: Center(
              child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  return const LinearGradient(
                    colors: [Tema.brandPurple, Colors.pinkAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds);
                },
                blendMode: BlendMode.srcIn,
                child: const Icon(Icons.add_rounded, size: 34),
              ),
            ),
          ),
        ),
      );
      },
    ),
    floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.login_rounded, size: 64, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'Inicia sesión para ver tus grupos',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SkeletonShimmer(
      builder: (sv) => ListView.builder(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 120),
        itemCount: 3,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            height: 108,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.transparent : Colors.black.withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                SkeletonBox(width: 68, height: 68, borderRadius: 22, shimmerValue: sv),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SkeletonLine(width: 140, shimmerValue: sv),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          SkeletonBox(width: 56, height: 24, borderRadius: 10, shimmerValue: sv),
                          const SizedBox(width: 8),
                          SkeletonBox(width: 60, height: 24, borderRadius: 10, shimmerValue: sv),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 16),
          child: _JoinByCodeBanner(currentUserId: _currentUserId!),
        ),
        Expanded(
          child: EmptyStateWidget(
            icon: Icons.people_outline_rounded,
            title: 'Sin grupos',
            description:
                'Únete o crea un grupo para competir con otros corredores',
            ctaLabel: 'Crear grupo',
            onCta: _handleCreateGroup,
          ),
        ),
      ],
    );
  }

  // === HANDLERS ===

  void _handleCreateGroup() {
    final TextEditingController nameController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateGroupModal(
        nameController: nameController,
        onSubmit: () async {
          if (nameController.text.isNotEmpty && _currentUserId != null) {
            Navigator.pop(context);
            try {
              final newGroup = Group(
                id: '',
                name: nameController.text,
                ownerId: _currentUserId!,
                createdAt: DateTime.now(),
                type: GroupType.private,
                memberCount: 1,
              );
              final groupId = await _groupsRepo.createGroup(newGroup);
              final ownerMember = GroupMember(
                uid: _currentUserId!,
                role: 'owner',
                status: MemberStatus.active,
                joinedAt: DateTime.now(),
              );
              await _groupsRepo.addMember(groupId, ownerMember);
              final userGroupsRepo = UserGroupsRepository();
              await userGroupsRepo.addUserToGroup(_currentUserId!, groupId);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 12),
                        Text("¡Grupo creado!"),
                      ],
                    ),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.green.shade600,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Error: $e"),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          }
        },
      ),
    );
  }
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
        ),
      ),
    );
  }
}

/// Modal de creación de grupo con diseño premium
class _CreateGroupModal extends StatelessWidget {
  final TextEditingController nameController;
  final VoidCallback onSubmit;

  const _CreateGroupModal({
    required this.nameController,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 24,
        right: 24,
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
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Header con gradiente
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Tema.brandPurple, Tema.brandPurple.withOpacity(0.7)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.group_add, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Crear Nuevo Grupo",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Dale un nombre genial a tu comunidad",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // Input
          TextField(
            controller: nameController,
            autofocus: true,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: "Ej. Corredores Nocturnos",
              hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
              filled: true,
              fillColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: Tema.brandPurple, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 18,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 16, right: 8),
                child: Icon(Icons.edit_rounded, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Botón crear
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 4,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.rocket_launch, size: 20),
                  SizedBox(width: 10),
                  Text(
                    "Crear Grupo",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta Premium de Grupo con gradientes vibrantes
class _PremiumGroupCard extends StatefulWidget {
  final String groupId;
  final GroupsRepository groupsRepo;
  final int colorIndex;

  const _PremiumGroupCard({
    required this.groupId,
    required this.groupsRepo,
    required this.colorIndex,
  });

  @override
  State<_PremiumGroupCard> createState() => _PremiumGroupCardState();
}

class _PremiumGroupCardState extends State<_PremiumGroupCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  // Paleta de colores vibrantes para los grupos
  static const List<List<Color>> _gradientPalette = [
    [Color(0xFF8E24AA), Color(0xFFAB47BC)], // Purple
    [Color(0xFF1E88E5), Color(0xFF42A5F5)], // Blue
    [Color(0xFF43A047), Color(0xFF66BB6A)], // Green
    [Color(0xFFE53935), Color(0xFFEF5350)], // Red
    [Color(0xFFFB8C00), Color(0xFFFFA726)], // Orange
    [Color(0xFF00ACC1), Color(0xFF26C6DA)], // Cyan
    [Color(0xFF5E35B1), Color(0xFF7E57C2)], // Deep Purple
    [Color(0xFFD81B60), Color(0xFFEC407A)], // Pink
  ];

  List<Color> get _gradientColors =>
      _gradientPalette[widget.colorIndex % _gradientPalette.length];

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _hoverController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _hoverController.reverse();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _hoverController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Group?>(
      stream: widget.groupsRepo.streamGroup(widget.groupId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildSkeleton();
        }

        final group = snapshot.data;
        if (group == null) return const SizedBox.shrink();

        return GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          onTap: () {
            Navigator.push(
              context,
              AppRoute(page: GroupScreen(groupId: widget.groupId)),
            );
          },
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: _gradientColors.first.withOpacity(_isPressed ? 0.2 : 0.12),
                    blurRadius: _isPressed ? 16 : 24,
                    offset: Offset(0, _isPressed ? 4 : 8),
                    spreadRadius: _isPressed ? -2 : 0,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  children: [
                    // Decoración de fondo
                    Positioned(
                      top: -30,
                      right: -30,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              _gradientColors.first.withOpacity(0.08),
                              _gradientColors.last.withOpacity(0.04),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Contenido principal
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          // Avatar con gradiente
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _gradientColors,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: _gradientColors.first.withOpacity(0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                group.name.isNotEmpty
                                    ? group.name.substring(0, 1).toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),

                          // Información Principal
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  group.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Theme.of(context).colorScheme.onSurface,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    // Badge de Miembros
                                    _GlassBadge(
                                      icon: Icons.person_outline,
                                      label: '${group.memberCount}',
                                      color: _gradientColors.first,
                                    ),
                                    const SizedBox(width: 8),
                                    // Badge de Privacidad
                                    _GlassBadge(
                                      icon: group.type == GroupType.private
                                          ? Icons.lock_outline
                                          : Icons.public,
                                      label: group.type == GroupType.private
                                          ? 'Privado'
                                          : 'Público',
                                      color: Colors.blue.shade600,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Flecha con animación
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkeleton() {
    return Container(
      height: 108,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: Tema.brandPurple),
      ),
    );
  }



  // ... (Rest of existing methods)
}

// ─────────────────────────────────────────────────────────────────────────────
// Join-by-code banner (tap to open sheet)
// ─────────────────────────────────────────────────────────────────────────────

class _JoinByCodeBanner extends StatelessWidget {
  final String currentUserId;
  const _JoinByCodeBanner({required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _JoinByCodeSheet(currentUserId: currentUserId),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: cs.onSurface.withOpacity(0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Tema.brandPurple.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Tema.brandPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.tag_rounded,
                  color: Tema.brandPurple, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¿Tienes un código de invitación?',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: cs.onSurface,
                    ),
                  ),
                  Text(
                    'Únete directamente con un código de 6 letras',
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withOpacity(0.5)),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: cs.onSurface.withOpacity(0.35)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Join-by-code bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _JoinByCodeSheet extends StatefulWidget {
  final String currentUserId;
  const _JoinByCodeSheet({required this.currentUserId});

  @override
  State<_JoinByCodeSheet> createState() => _JoinByCodeSheetState();
}

class _JoinByCodeSheetState extends State<_JoinByCodeSheet> {
  final _invitesRepo = InvitesRepository();
  final _codeController = TextEditingController();
  bool _isJoining = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _error = 'El código debe tener 6 caracteres');
      return;
    }
    setState(() { _isJoining = true; _error = null; });
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      await _invitesRepo.joinByShortCode(
        code,
        widget.currentUserId,
        email: currentUser?.email,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ModernSnackBar.showSuccess(context, '¡Bienvenid@ al grupo!');
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      setState(() { _error = msg; _isJoining = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        top: 16,
        left: 24,
        right: 24,
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
              decoration: BoxDecoration(
                color: cs.outline.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Tema.brandPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.tag_rounded,
                    color: Tema.brandPurple, size: 22),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unirse con código',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'Introduce el código de 6 caracteres',
                    style: TextStyle(
                        fontSize: 13, color: cs.onSurface.withOpacity(0.5)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Code input
          TextField(
            controller: _codeController,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 10,
              color: Tema.brandPurple,
            ),
            textAlign: TextAlign.center,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
            ],
            decoration: InputDecoration(
              counterText: '',
              hintText: 'XXXXXX',
              hintStyle: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 10,
                color: cs.onSurface.withOpacity(0.18),
              ),
              filled: true,
              fillColor: Tema.brandPurple.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide:
                    const BorderSide(color: Tema.brandPurple, width: 2),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            ),
            onSubmitted: (_) => _join(),
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.error_outline_rounded,
                    size: 16, color: cs.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _error!,
                    style: TextStyle(color: cs.error, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isJoining ? null : _join,
              style: ElevatedButton.styleFrom(
                backgroundColor: Tema.brandPurple,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                elevation: 0,
              ),
              child: _isJoining
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text(
                      'Unirse al grupo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de invitación pendiente
class _InvitationCard extends StatefulWidget {
  final UserGroupMembership membership;
  final GroupsRepository groupsRepo;
  final String currentUserId;

  const _InvitationCard({
    required this.membership,
    required this.groupsRepo,
    required this.currentUserId,
  });

  @override
  State<_InvitationCard> createState() => _InvitationCardState();
}

class _InvitationCardState extends State<_InvitationCard> {
  final InvitesRepository _invitesRepo = InvitesRepository();
  bool _isProcessing = false;

  Future<void> _handleAccept() async {
    setState(() => _isProcessing = true);
    try {
      await _invitesRepo.acceptDirectInvite(widget.membership.groupId, widget.currentUserId);
      if (mounted) {
        ModernSnackBar.showSuccess(context, "¡Invitación aceptada! Bienvenid@ al grupo.");
      }
    } catch (e) {
      if (mounted) {
        ModernSnackBar.showError(context, "Error: $e");
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleDecline() async {
    setState(() => _isProcessing = true);
    try {
      await _invitesRepo.declineDirectInvite(widget.membership.groupId, widget.currentUserId);
      if (mounted) {
        ModernSnackBar.showSuccess(context, "Invitación rechazada.");
      }
    } catch (e) {
      if (mounted) {
        ModernSnackBar.showError(context, "Error: $e");
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Group?>(
      stream: widget.groupsRepo.streamGroup(widget.membership.groupId),
      builder: (context, snapshot) {
        final groupName = snapshot.data?.name ?? "Cargando grupo...";
        
        return Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Tema.brandPurple.withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Tema.brandPurple.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Tema.brandPurple.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.mark_email_unread_rounded, size: 20, color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandPurpleLight : Tema.brandPurple),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Te han invitado a unirte a",
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                        ),
                        Text(
                          groupName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_isProcessing)
                const Center(child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ))
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _handleDecline,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade400,
                          side: BorderSide(color: Colors.red.shade200),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("Rechazar"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _handleAccept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Tema.brandPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text("Aceptar"),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Badge con efecto cristal/glassmorphism
class _GlassBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _GlassBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Animación escalonada mejorada para elementos de lista
class _StaggeredGroupItem extends StatefulWidget {
  final int index;
  final Widget child;

  const _StaggeredGroupItem({
    Key? key,
    required this.index,
    required this.child,
  }) : super(key: key);

  @override
  State<_StaggeredGroupItem> createState() => _StaggeredGroupItemState();
}

class _StaggeredGroupItemState extends State<_StaggeredGroupItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
    ));
    
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    // Delay basado en el índice
    Future.delayed(Duration(milliseconds: widget.index * 100), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: widget.child,
        ),
      ),
    );
  }
}

class _PremiumFloatingActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PremiumFloatingActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_PremiumFloatingActionButton> createState() => _PremiumFloatingActionButtonState();
}

class _PremiumFloatingActionButtonState extends State<_PremiumFloatingActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.black, Color(0xFF333333)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



