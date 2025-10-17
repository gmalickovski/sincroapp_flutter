// lib/features/tasks/presentation/widgets/goal_selection_modal.dart
import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';

class GoalSelectionModal extends StatefulWidget {
  final String userId;
  final Function(Goal) onGoalSelected;

  const GoalSelectionModal({
    super.key,
    required this.userId,
    required this.onGoalSelected,
  });

  @override
  State<GoalSelectionModal> createState() => _GoalSelectionModalState();
}

class _GoalSelectionModalState extends State<GoalSelectionModal> {
  late Future<List<Goal>> _goalsFuture;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _goalsFuture = _firestoreService.getActiveGoals(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.0),
          topRight: Radius.circular(24.0),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 16, top: 8),
            child: Text(
              'Selecionar Jornada',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.primaryText,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Goal>>(
              future: _goalsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary));
                }
                if (snapshot.hasError ||
                    !snapshot.hasData ||
                    snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      'Nenhuma jornada encontrada.',
                      style: TextStyle(color: AppColors.secondaryText),
                    ),
                  );
                }

                final goals = snapshot.data!;
                return ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: goals.length,
                  itemBuilder: (context, index) {
                    final goal = goals[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppColors.background.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          splashColor: AppColors.primary.withOpacity(0.2),
                          hoverColor: AppColors.primary.withOpacity(0.1),
                          onTap: () {
                            widget.onGoalSelected(goal);
                            Navigator.of(context).pop();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                const Icon(Icons.track_changes_outlined,
                                    color: AppColors.secondaryText),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    goal.title,
                                    style: const TextStyle(
                                      color: AppColors.primaryText,
                                      fontSize: 16,
                                    ),
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
              },
            ),
          ),
        ],
      ),
    );
  }
}
