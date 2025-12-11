import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Asegúrate de que esta ruta sea correcta para tu pantalla de detalle
import '../../group/view/group_detail_screen.dart';

// 1. IMPORTS DE DATOS Y MODELOS
import '../data/groups_repository.dart';
import '../../group_model.dart'; // O '../models/group_model.dart' según donde lo hayas guardado
import '../../invitation_model.dart'; // EL NUEVO MODELO DE INVITACIÓN

// 2. IMPORTS TUS WIDGETS CORE
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_footer.dart';

class GroupsHomeScreen extends StatefulWidget {
  const GroupsHomeScreen({Key? key}) : super(key: key);

  @override
  _GroupsHomeScreenState createState() => _GroupsHomeScreenState();
}

class _GroupsHomeScreenState extends State<GroupsHomeScreen> {
  final GroupsRepository _repository = GroupsRepository();

  // Variable para recargar la lista de grupos
  late Future<List<GroupModel>> _groupsFuture;

  // Usuario actual (cacheado)
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _refreshGroups();
  }

  // Método para recargar la lista tras una acción
  void _refreshGroups() {
    setState(() {
      if (_currentUserId != null) {
        _groupsFuture = _repository.fetchUserGroupsPreview(_currentUserId!);
      } else {
        _groupsFuture = Future.value([]);
      }
    });
  }

  // --- LÓGICA UI: CREAR GRUPO ---
  void _handleCreateGroup() {
    final TextEditingController _nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Nuevo Grupo"),
        content: TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            hintText: "Ej: Corredores del Sur",
            labelText: "Nombre del Grupo",
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_nameController.text.isNotEmpty && _currentUserId != null) {
                Navigator.pop(context); // Cerrar
                await _repository.createGroup(
                  _nameController.text,
                  _currentUserId!,
                );
                _refreshGroups(); // Refrescar
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Grupo '${_nameController.text}' creado")),
                );
              }
            },
            child: const Text("Crear"),
          ),
        ],
      ),
    );
  }

  // --- LÓGICA UI: ABANDONAR GRUPO ---
  void _handleLeaveGroup(List<GroupModel> currentGroups) {
    if (currentGroups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No tienes grupos para abandonar")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text("¿Qué grupo quieres dejar?"),
        children: currentGroups.map((group) {
          return SimpleDialogOption(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(group.name, style: const TextStyle(fontSize: 16)),
                const Icon(Icons.exit_to_app, color: Colors.red),
              ],
            ),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("Confirmar"),
                  content: Text("¿Seguro que quieres salir de ${group.name}?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text("No"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text("Sí, salir", style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );

              if (confirm == true && _currentUserId != null) {
                Navigator.pop(context);
                await _repository.leaveGroup(group.id, _currentUserId!);
                _refreshGroups();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Has salido del grupo")),
                );
              }
            },
          );
        }).toList(),
      ),
    );
  }

  // --- LÓGICA UI: RESPONDER INVITACIÓN (Nuevo) ---
  Future<void> _handleAnswerInvite(InvitationModel invite, bool accept) async {
    if (_currentUserId == null) return;
    try {
      await _repository.answerInvitation(_currentUserId!, invite, accept);
      if (accept) {
        _refreshGroups(); // Si aceptamos, recargamos la lista para ver el grupo nuevo
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Te uniste a ${invite.groupName}")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invitación rechazada")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: SafeArea(
        child: Column(
          children: [
            // 1. HEADER
            AppHeader(
              onTapLeft: () {},
              onTapRight: () {},
              showBottomDivider: false,
            ),

            // 2. SECCIÓN DE INVITACIONES (CARRUSEL)
            // Solo se muestra si hay usuario y tiene invitaciones pendientes
            if (_currentUserId != null)
              StreamBuilder<List<InvitationModel>>(
                stream: _repository.getInvitationsStream(_currentUserId!),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const SizedBox.shrink(); // Invisible si no hay nada
                  }
                  
                  return Container(
                    height: 140, // Altura fija para las tarjetas
                    margin: const EdgeInsets.only(top: 10, bottom: 5),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        return _InvitationCard(
                          invitation: snapshot.data![index],
                          onAccept: () => _handleAnswerInvite(snapshot.data![index], true),
                          onReject: () => _handleAnswerInvite(snapshot.data![index], false),
                        );
                      },
                    ),
                  );
                },
              ),

            // 3. LISTA DE GRUPOS
            Expanded(
              child: FutureBuilder<List<GroupModel>>(
                future: _groupsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final groups = snapshot.data ?? [];

                  if (groups.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.groups_3_outlined, size: 60, color: Colors.grey),
                          SizedBox(height: 10),
                          Text(
                            "No estás en ningún grupo",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    itemCount: groups.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 15),
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      // Mapeo de datos para la tarjeta visual
                      final runnersList = group.topRunners
                              ?.map((r) => {'name': r.name, 'km': r.totalKm})
                              .toList() ?? [];

                      return GroupCard(
                        groupName: group.name,
                        runners: runnersList,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GroupDetailScreen(
                                groupId: group.id,
                                groupName: group.name,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),

            // 4. BOTONES FLOTANTES (Crear / Abandonar)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: "Crear",
                      gradient: const LinearGradient(
                        colors: [Color(0xFFAB47BC), Color(0xFF8E24AA)],
                      ),
                      onTap: _handleCreateGroup,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: FutureBuilder<List<GroupModel>>(
                      future: _groupsFuture,
                      builder: (context, snapshot) {
                        return _ActionButton(
                          label: "Abandonar",
                          color: const Color(0xFFFF5252),
                          onTap: () => _handleLeaveGroup(snapshot.data ?? []),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // 5. FOOTER
            AppFooter(isLoading: false, onTap: () {}),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// WIDGETS VISUALES LOCALES
// ==========================================

class GroupCard extends StatelessWidget {
  final String groupName;
  final List<Map<String, dynamic>> runners;
  final VoidCallback onTap;

  const GroupCard({
    Key? key,
    required this.groupName,
    required this.runners,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  groupName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
            const SizedBox(height: 15),
            if (runners.isEmpty)
              const Text("Sin actividad", style: TextStyle(color: Colors.grey))
            else
              ...runners.take(3).toList().asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: _RankingRow(
                    position: entry.key + 1,
                    name: entry.value['name'],
                    km: (entry.value['km'] as num).toDouble(),
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  final int position;
  final String name;
  final double km;

  const _RankingRow({
    Key? key,
    required this.position,
    required this.name,
    required this.km,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Row(
        children: [
          _buildBadge(position),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            width: 1,
            height: 12,
            color: Colors.grey[300],
            margin: const EdgeInsets.symmetric(horizontal: 10),
          ),
          Text(
            "${km.toStringAsFixed(1)} Km",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(int pos) {
    Color color = pos == 1
        ? const Color(0xFFFFD700)
        : (pos == 2 ? const Color(0xFFC0C0C0) : const Color(0xFFCD7F32));
    if (pos > 3) color = Colors.grey.shade300;
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        "$pos",
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: pos <= 3 ? Colors.white : Colors.black54,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final Gradient? gradient;
  const _ActionButton({
    required this.label,
    required this.onTap,
    this.color,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: color,
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// === NUEVO WIDGET: TARJETA DE INVITACIÓN ===
class _InvitationCard extends StatelessWidget {
  final InvitationModel invitation;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _InvitationCard({
    required this.invitation,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280, // Ancho fijo para el carrusel
      margin: const EdgeInsets.only(right: 15, bottom: 5),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mark_email_unread_rounded,
                  color: Colors.purple, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Invitación de ${invitation.invitedBy}",
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            invitation.groupName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  child: const Text("Rechazar"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    padding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  child: const Text("Unirme", style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}