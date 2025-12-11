import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; 

// IMPORTS DE TUS WIDGETS CORE
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_footer.dart';
import '../../../../app/tema.dart';

// IMPORTS DE MODELOS
import '../data/challenge_model.dart';
import '../../group_model.dart'; 

// IMPORTS DE DATOS LOCALES
import '../data/group_detail_repository.dart';

// IMPORT DEL REPOSITORIO DE HOME (Necesario para enviar la invitación)
import '../../home/data/groups_repository.dart';
import 'challenge_detail_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupDetailScreen({
    Key? key,
    required this.groupId,
    required this.groupName,
  }) : super(key: key);

  @override
  _GroupDetailScreenState createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GroupDetailRepository _repository = GroupDetailRepository();
  final GroupsRepository _homeRepository = GroupsRepository();

  bool _showMonthlyRanking = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _repository.checkAndSeedChallenges(widget.groupId);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- LÓGICA: MOSTRAR DIÁLOGO DE INVITACIÓN ---
  void _showInviteDialog() {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.mark_email_unread_outlined, color: Colors.purple),
            SizedBox(width: 10),
            Text("Invitar Corredor"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Escribe el email de tu amigo para enviarle una invitación oficial.",
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: "Correo electrónico",
                hintText: "ejemplo@gmail.com",
                prefixIcon: const Icon(Icons.alternate_email_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.purple, width: 2),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (emailController.text.isNotEmpty) {
                Navigator.pop(context); 

                try {
                  final currentUser = FirebaseAuth.instance.currentUser;
                  final myName = currentUser?.displayName ??
                      currentUser?.email?.split('@')[0] ??
                      "Un amigo";

                  await _homeRepository.sendInvitationByEmail(
                    widget.groupId,
                    widget.groupName,
                    myName,
                    emailController.text.trim(),
                  );

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(children: [
                          const Icon(Icons.check_circle, color: Colors.white),
                          const SizedBox(width: 10),
                          Expanded(child: Text("Invitación enviada a ${emailController.text}")),
                        ]),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Error: ${e.toString().replaceAll('Exception:', '')}"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text("Enviar Invitación", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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
              onTapLeft: () => Navigator.pop(context),
              onTapRight: () {
                // Acción de perfil (ya no es invitar)
              },
              showBottomDivider: false,
            ),

            // 2. NOMBRE DEL GRUPO
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 5),
              child: Text(
                widget.groupName,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // 3. NUEVO BOTÓN DE INVITAR (DISEÑO CÁPSULA)
            // Este es el componente que pediste
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              child: ElevatedButton.icon(
                onPressed: _showInviteDialog,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text(
                  "Invitar a un amigo",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black, // Color de alto contraste
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30), // Forma de cápsula
                  ),
                ),
              ),
            ),

            // 4. TABS MODERNOS (Segmented Control Style)
            Container(
              height: 50,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade200, // Fondo sutil
                borderRadius: BorderRadius.circular(25),
              ),
              padding: const EdgeInsets.all(4), // Padding interno para efecto flotante
              child: TabBar(
                controller: _tabController,
                // Indicador flotante blanco con sombra suave
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(21),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                labelColor: Colors.black87, // Texto seleccionado oscuro
                unselectedLabelColor: Colors.grey.shade600, // Texto no seleccionado
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                dividerColor: Colors.transparent, // Quitar línea inferior
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: const [
                  Tab(text: "Clasificación"),
                  Tab(text: "Retos"),
                ],
              ),
            ),
            const SizedBox(height: 15),

            // 5. CONTENIDO
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildRankingTab(),
                  _buildChallengesTab(),
                ],
              ),
            ),

            // 6. FOOTER
            AppFooter(isLoading: false, onTap: () {}),
          ],
        ),
      ),
    );
  }

  // --- VISTA RANKING ---
  Widget _buildRankingTab() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _FilterChip(
              label: "Este Mes",
              isSelected: _showMonthlyRanking,
              onTap: () => setState(() => _showMonthlyRanking = true),
            ),
            const SizedBox(width: 10),
            _FilterChip(
              label: "Histórico",
              isSelected: !_showMonthlyRanking,
              onTap: () => setState(() => _showMonthlyRanking = false),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: FutureBuilder<List<GroupMemberStats>>(
            future: _repository.fetchMemberStats(widget.groupId,
                onlyThisMonth: _showMonthlyRanking),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text("No hay datos de actividad."));
              }
              final stats = snapshot.data!;
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                itemCount: stats.length,
                itemBuilder: (context, index) {
                  return _RankingFullRow(pos: index + 1, stat: stats[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // --- VISTA RETOS ---
  Widget _buildChallengesTab() {
    return StreamBuilder<List<ChallengeModel>>(
      stream: _repository.getChallengesStream(widget.groupId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final challenges = snapshot.data ?? [];
        if (challenges.isEmpty) {
          return const Center(child: Text("No hay retos activos."));
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: challenges.length,
          itemBuilder: (context, index) {
            return _ChallengeCard(
              challenge: challenges[index],
              groupId: widget.groupId,
            );
          },
        );
      },
    );
  }
}

// === WIDGETS INTERNOS ===
class _RankingFullRow extends StatelessWidget {
  final int pos;
  final GroupMemberStats stat;
  const _RankingFullRow({required this.pos, required this.stat});

  @override
  Widget build(BuildContext context) {
    final bool isPodium = pos <= 3;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: isPodium
            ? Border.all(color: _getMedalColor(pos).withOpacity(0.5), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 5,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isPodium ? _getMedalColor(pos) : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: isPodium
                ? const Icon(Icons.emoji_events, color: Colors.white, size: 18)
                : Text("$pos",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
          ),
          const SizedBox(width: 15),
          AvatarHelper.construirAvatar(
            radius: 18,
            type: stat.profilePicType ?? 'none',
            config: stat.avatarConfig,
            url: stat.photoUrl,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              stat.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${stat.totalKm.toStringAsFixed(1)} Km",
                style: const TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 16, color: Colors.purple),
              ),
              const Text("TOTAL", style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          )
        ],
      ),
    );
  }

  Color _getMedalColor(int pos) {
    if (pos == 1) return const Color(0xFFFFD700);
    if (pos == 2) return const Color(0xFFC0C0C0);
    return const Color(0xFFCD7F32);
  }
}

class _ChallengeCard extends StatelessWidget {
  final ChallengeModel challenge;
  final String groupId; // New
  const _ChallengeCard({required this.challenge, required this.groupId});

  @override
  Widget build(BuildContext context) {
    final daysLeft = challenge.endDate.difference(DateTime.now()).inDays;
    final currentUser = FirebaseAuth.instance.currentUser;
    final isParticipant = currentUser != null && challenge.participants.contains(currentUser.uid);

    return GestureDetector(
      onTap: () {
         Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChallengeDetailScreen(
                challenge: challenge,
                groupId: groupId,
              ),
            ),
          );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.purple.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.purple.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  label: Text("🎯 Objetivo: ${challenge.targetKm}km"),
                  backgroundColor: Colors.purple.shade100,
                  labelStyle: const TextStyle(
                      color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                Text(
                  daysLeft > 0 ? "$daysLeft días restantes" : "Finalizado",
                  style: TextStyle(
                      color: daysLeft > 0 ? Colors.orange : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(challenge.title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            Text(challenge.description,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            const SizedBox(height: 20),
            
            // LOGICA DE ESTADO: PARTICIPANDO vs NO
            if (isParticipant)
              _buildProgressSection(currentUser.uid)
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChallengeDetailScreen(
                          challenge: challenge,
                          groupId: groupId, 
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Ver Detalles / Aceptar", style: TextStyle(color: Colors.white)),
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection(String uid) {
    return FutureBuilder<double>(
      future: GroupDetailRepository().calculateChallengeProgress(
          uid, challenge.startDate, challenge.endDate),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const LinearProgressIndicator(color: Colors.purple, backgroundColor: Colors.white);
        }
        final currentKm = snapshot.data!;
        final progress = (currentKm / challenge.targetKm).clamp(0.0, 1.0);
        final percent = (progress * 100).toInt();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Tu progreso: $percent%", 
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                Text("${currentKm.toStringAsFixed(1)} / ${challenge.targetKm.toInt()} km",
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                color: Colors.purple,
                backgroundColor: Colors.purple.shade100,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.purple : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? Colors.purple : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black54,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}