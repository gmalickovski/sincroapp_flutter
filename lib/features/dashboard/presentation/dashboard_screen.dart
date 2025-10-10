import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/features/authentication/data/auth_repository.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  UserModel? _userData;
  NumerologyResult? _numerologyData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final authRepository = AuthRepository();
    final firestoreService = FirestoreService();
    final currentUser = authRepository.getCurrentUser();

    if (currentUser != null) {
      final userData = await firestoreService.getUserData(currentUser.uid);
      if (userData != null &&
          userData.nomeAnalise.isNotEmpty &&
          userData.dataNasc.isNotEmpty) {
        final engine = NumerologyEngine(
          nomeCompleto: userData.nomeAnalise,
          dataNascimento: userData.dataNasc,
        );
        final numerologyData = engine.calcular();
        if (mounted) {
          setState(() {
            _userData = userData;
            _numerologyData = numerologyData;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SincroApp'),
        backgroundColor: AppColors.cardBackground,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              AuthRepository().signOut();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CustomLoadingSpinner())
          : _numerologyData == null
              ? const Center(child: Text("Não foi possível calcular os dados."))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bem-vindo(a), ${_userData?.primeiroNome ?? ''}!',
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),
                      // Grid de cartões
                      GridView.count(
                        crossAxisCount: 2, // 2 colunas em telas menores
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.5, // Proporção dos cartões
                        children: [
                          _buildInfoCard(
                            title: 'Vibração do Dia',
                            number: _numerologyData!.numeros['diaPessoal']
                                .toString(),
                            description:
                                'Finalização e Compaixão', // Exemplo estático
                          ),
                          _buildInfoCard(
                            title: 'Vibração do Mês',
                            number: _numerologyData!.numeros['mesPessoal']
                                .toString(),
                            description:
                                'Mês de Conquistas', // Exemplo estático
                          ),
                          _buildInfoCard(
                            title: 'Vibração do Ano',
                            number: _numerologyData!.numeros['anoPessoal']
                                .toString(),
                            description:
                                'Ano de Autoavaliação', // Exemplo estático
                          ),
                          _buildInfoCard(
                            title: 'Ciclo de Vida Atual',
                            number: _numerologyData!
                                .estruturas['cicloDeVidaAtual']['regente']
                                .toString(),
                            description: _numerologyData!
                                .estruturas['cicloDeVidaAtual']['nome'],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }

  // Widget auxiliar para criar os cartões do dashboard
  Widget _buildInfoCard(
      {required String title,
      required String number,
      required String description}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  color: AppColors.secondaryText, fontWeight: FontWeight.bold)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                number,
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryAccent,
                ),
              ),
              Expanded(
                child: Text(
                  description,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      color: AppColors.tertiaryText, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
