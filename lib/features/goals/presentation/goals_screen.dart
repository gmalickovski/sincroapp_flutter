// lib/features/goals/presentation/goals_screen.dart
import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/features/authentication/data/auth_repository.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/features/goals/presentation/create_goal_screen.dart';
import 'package:sincro_app_flutter/features/goals/presentation/goal_detail_screen.dart';
import 'package:sincro_app_flutter/features/goals/presentation/widgets/goal_card.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';

class GoalsScreen extends StatefulWidget {
  final UserModel userData;
  const GoalsScreen({super.key, required this.userData});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final String _userId = AuthRepository().getCurrentUser()!.uid;

  void _navigateToCreateGoal() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => CreateGoalScreen(userData: widget.userData),
      fullscreenDialog: true,
    ));
  }

  void _navigateToGoalDetail(Goal goal) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => GoalDetailScreen(
        initialGoal:
            goal, // O nome do parâmetro foi atualizado para initialGoal
        userData: widget.userData,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 12.0 : 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              Expanded(
                child: StreamBuilder<List<Goal>>(
                  stream: _firestoreService.getGoalsStream(_userId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CustomLoadingSpinner());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Erro: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return _buildEmptyState();
                    }

                    final goals = snapshot.data!;

                    return ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 80),
                      itemCount: goals.length,
                      itemBuilder: (context, index) {
                        final goal = goals[index];
                        return GoalCard(
                          goal: goal,
                          onTap: () => _navigateToGoalDetail(goal),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateGoal,
        backgroundColor: AppColors.primary,
        tooltip: 'Nova Jornada',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.only(top: 16, bottom: 16),
      child: Text(
        'Jornadas',
        style: TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.flag_outlined,
            color: AppColors.tertiaryText,
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            'Nenhuma jornada iniciada',
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Crie sua primeira jornada para começar a evoluir.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.tertiaryText),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _navigateToCreateGoal,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Criar Jornada',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          )
        ],
      ),
    );
  }
}
