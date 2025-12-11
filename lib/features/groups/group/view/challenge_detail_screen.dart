import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// REPOSITORIO & MODELS
import '../data/group_detail_repository.dart';
import '../data/challenge_model.dart';

// CORE WIDGETS
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_footer.dart';

class ChallengeDetailScreen extends StatefulWidget {
  final ChallengeModel challenge;
  final String groupId;

  const ChallengeDetailScreen({
    Key? key,
    required this.challenge,
    required this.groupId,
  }) : super(key: key);

  @override
  _ChallengeDetailScreenState createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen> {
  final GroupDetailRepository _repository = GroupDetailRepository();
  final String _currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  bool _isLoading = false;
  double _currentProgressKm = 0.0;
  bool _isParticipant = false;

  @override
  void initState() {
    super.initState();
    _checkParticipationAndProgress();
  }

  Future<void> _checkParticipationAndProgress() async {
    setState(() => _isLoading = true);

    // 1. Check if user is already in the list
    if (widget.challenge.participants.contains(_currentUid)) {
      _isParticipant = true;
      // 2. Calculate progress if participant
      final km = await _repository.calculateChallengeProgress(
        _currentUid,
        widget.challenge.startDate,
        widget.challenge.endDate,
      );
      _currentProgressKm = km;
    } else {
      _isParticipant = false;
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _joinChallenge() async {
    setState(() => _isLoading = true);
    try {
      await _repository.joinChallenge(widget.groupId, widget.challenge.id, _currentUid);
      
      // Update local state to reflect change immediately
      _isParticipant = true;
      
      // Recalculate progress (likely 0 or historical for that period)
      await _checkParticipationAndProgress(); 

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("¡Reto aceptado! ¡A correr!")),
        );
        Navigator.pop(context); // Regresar a la pantalla anterior
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al unirse: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Basic date formatting
    final dateFormat = DateFormat('dd MMM yyyy', 'es_ES');
    final String rangeStr = "${dateFormat.format(widget.challenge.startDate)} - ${dateFormat.format(widget.challenge.endDate)}";

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: SafeArea(
        child: Column(
          children: [
            // 1. HEADER
            AppHeader(
              onTapLeft: () => Navigator.pop(context),
              onTapRight: () {},
              showBottomDivider: false,
            ),

            // 2. CONTENT
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // --- TITULO & DESCRIPCION ---
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.purple.withOpacity(0.05),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          )
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.emoji_events_rounded, 
                                size: 40, color: Colors.purple),
                          ),
                          const SizedBox(height: 15),
                          Text(
                            widget.challenge.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22, 
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            widget.challenge.description,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 20),
                          
                          // STATUS TAGS
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _StatusTag(
                                icon: Icons.calendar_today_rounded,
                                label: rangeStr,
                              ),
                            ],
                          )
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // --- ACCION PRINCIPAL / PROGRESO ---
                    if (_isLoading)
                      const CircularProgressIndicator()
                    else if (!_isParticipant)
                      _buildJoinCard()
                    else
                      _buildProgressCard(),

                    const SizedBox(height: 30),

                    // --- PARTICIPANTES ---
                    Text(
                      "${widget.challenge.participantsCount} Corredores participan",
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. FOOTER
            AppFooter(isLoading: false, onTap: () {}),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinCard() {
    return Column(
      children: [
        const Text(
          "¿Aceptas el desafío?",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 15),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: _joinChallenge,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            child: const Text(
              "ACEPTAR RETO",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressCard() {
    final double percentage = (_currentProgressKm / widget.challenge.targetKm).clamp(0.0, 1.0);
    final int percentInt = (percentage * 100).toInt();

    return Column(
      children: [
        // RADIAL PROGRESS
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 150,
              height: 150,
              child: CircularProgressIndicator(
                value: percentage,
                strokeWidth: 12,
                backgroundColor: Colors.grey.shade200,
                color: percentage >= 1.0 ? Colors.green : Colors.purple,
                strokeCap: StrokeCap.round,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "$percentInt%",
                  style: const TextStyle(
                    fontSize: 32, 
                    fontWeight: FontWeight.w900, 
                    color: Colors.black87
                  ),
                ),
                Text(
                  "Completado",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                )
              ],
            )
          ],
        ),
        const SizedBox(height: 20),
        
        // STATS ROW
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _StatBox(
              label: "Recorrido",
              value: "${_currentProgressKm.toStringAsFixed(1)} km",
              color: Colors.blue,
            ),
            Container(width: 1, height: 40, color: Colors.grey.shade300),
            _StatBox(
              label: "Meta",
              value: "${widget.challenge.targetKm.toStringAsFixed(0)} km",
              color: Colors.purple,
            ),
          ],
        )
      ],
    );
  }
}

class _StatusTag extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatusTag({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade800, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
