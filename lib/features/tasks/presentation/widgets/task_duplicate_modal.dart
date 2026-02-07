import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';

class TaskDuplicateModal extends StatefulWidget {
  final TaskModel originalTask;
  final String userId;

  const TaskDuplicateModal({
    super.key,
    required this.originalTask,
    required this.userId,
  });

  @override
  State<TaskDuplicateModal> createState() => _TaskDuplicateModalState();
}

class _TaskDuplicateModalState extends State<TaskDuplicateModal> {
  late TextEditingController _textController;
  final _supabaseService = SupabaseService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: "${widget.originalTask.text} (Cópia)");
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _handleDuplicate() async {
    if (_textController.text.trim().isEmpty) return;
    
    setState(() => _isLoading = true);
    
    try {
      final newTask = widget.originalTask.copyWith(
        id: '', // New ID will be generated
        text: _textController.text.trim(),
        completed: false,
        createdAt: DateTime.now(),
        // Clear recurrence if duplication shouldn't carry it over, 
        // but typically a duplicate keeps properties. 
        // Let's keep basics, maybe reset completion.
      );

      await _supabaseService.addTask(widget.userId, newTask);
      
      if (mounted) {
        Navigator.pop(context, true); // Return true on success
      }
    } catch (e) {
      if (mounted) {
         setState(() => _isLoading = false);
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Erro ao duplicar: $e'), backgroundColor: Colors.red),
         );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16, 
        right: 16, 
        top: 16
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Duplicar Tarefa',
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.bold, 
              color: AppColors.primaryText
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _textController,
            autofocus: true,
            style: const TextStyle(color: AppColors.primaryText),
            decoration: const InputDecoration(
              labelText: 'Nome da nova tarefa',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar', style: TextStyle(color: AppColors.secondaryText)),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _isLoading ? null : _handleDuplicate,
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                child: _isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Duplicar'),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
