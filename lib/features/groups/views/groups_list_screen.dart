import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:running_laps/core/utils/app_transitions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:ui';

// Repositories
import '../data/repositories/user_groups_repository.dart';
import '../data/repositories/groups_repository.dart';
import '../data/repositories/invites_repository.dart';

// Models
import '../data/models/group_models.dart';
import '../data/models/enums.dart';
import 'package:running_laps/config/app_theme.dart';
import '../../../../core/widgets/modern_snackbar.dart';

// Widgets
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/gradient_banner.dart';
import '../../../core/widgets/skeleton_shimmer.dart';

// Navigation
import 'package:running_laps/core/widgets/main_shell.dart';
import '../../profile/views/profile_menu_screen_legacy.dart';

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
        top: false,
        bottom: false,
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
              accentColor: AppColors.restSurface,
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
                    colors: [AppColors.brand, AppColors.brand],
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

              // context.mounted: context del builder del sheet, no el del State.
              // ModernSnackBar es el único snackbar permitido (convención).
              if (context.mounted) {
                ModernSnackBar.showSuccess(context, '¡Grupo creado!');
              }
            } catch (e) {
              if (context.mounted) {
                ModernSnackBar.showError(context, 'Error: $e');
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
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.group_add, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
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
                        color: AppColors.iconMutedOf(context),
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
                borderSide: const BorderSide(color: AppColors.brand, width: 2),
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
  Color get _accentColor => AppColors.brand;

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
            MainShell.shellKey.currentState?.navigateTo(7, params: widget.groupId);
          },
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: _accentColor.withOpacity(_isPressed ? 0.2 : 0.3),
                    blurRadius: _isPressed ? 8 : 12,
                    offset: Offset(0, _isPressed ? 4 : 8),
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    // 1. VIVID DYNAMIC BACKGROUND
                    Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: _accentColor,
                      ),
                    ),

                    // 2. LAYERED WATERMARKS (Dynamic based on index)
                    Positioned(
                      top: -30,
                      right: -20,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -40,
                      left: 40,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.06),
                        ),
                      ),
                    ),

                    // 3. CONTENT
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Avatar Area
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: Colors.white.withOpacity(0.4)),
                                ),
                                child: Center(
                                  child: Text(
                                    group.name.isNotEmpty
                                        ? group.name.substring(0, 1).toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                              // Floating Member Count Badge
                              Positioned(
                                bottom: -4,
                                right: -4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.people_rounded, size: 10, color: _accentColor),
                                      const SizedBox(width: 2),
                                      Text(
                                        "${group.memberCount}",
                                        style: TextStyle(
                                          color: _accentColor,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 20),

                          // INFO
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  group.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.4,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                // Subtitle / Status
                                Text(
                                  group.type == GroupType.private ? "Grupo Privado" : "Comunidad Pública",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Subtle Action Icon
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 18,
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
      height: 110,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.4),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2, 
            color: AppColors.brand.withOpacity(0.5)
          ),
        ),
      ),
    );
  }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _JoinByCodeSheet(currentUserId: currentUserId),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.1) : AppColors.brand.withOpacity(0.15),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.tag_rounded,
                      color: AppColors.brand, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '¿Tienes un código?',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: cs.onSurface,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Únete directamente a un grupo',
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
                  color: AppColors.brand.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.tag_rounded,
                    color: AppColors.brand, size: 22),
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
              color: AppColors.brand,
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
              fillColor: AppColors.brand.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide:
                    const BorderSide(color: AppColors.brand, width: 2),
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
                backgroundColor: AppColors.brand,
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
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final brandColor = AppColors.brand;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: brandColor.withOpacity(0.25),
                blurRadius: 15,
                offset: const Offset(0, 8),
                spreadRadius: -4,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // 1. VIVID BACKGROUND (Different direction)
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.brandSurface,
                  ),
                ),

                // 2. SPARKLE WATERMARK (Multiple Small Circles)
                ...List.generate(3, (i) => Positioned(
                  top: 10.0 + (i * 30),
                  right: 20.0 + (i * 15),
                  child: Container(
                    width: 40.0 - (i * 10),
                    height: 40.0 - (i * 10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.08 + (i * 0.02)),
                    ),
                  ),
                )),

                // 3. CONTENT
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Invite Icon in a Glass Circle
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "TE HAN INVITADO A",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        groupName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          letterSpacing: -0.5,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      
                      if (_isProcessing)
                        const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      else
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: _handleDecline,
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white.withOpacity(0.8),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text("Declinar", style: TextStyle(fontWeight: FontWeight.w700)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _handleAccept,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                    foregroundColor: brandColor,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text("Unirme", style: TextStyle(fontWeight: FontWeight.w900)),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
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
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
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
              color: AppColors.surfaceOf(context),
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



