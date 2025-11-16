// lib/features/journal/presentation/journal_editor_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/vibration_pill.dart';
import 'package:sincro_app_flutter/features/journal/models/journal_entry_model.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';

class JournalEditorScreen extends StatefulWidget {
  final UserModel userData;
  final JournalEntry? entry;

  const JournalEditorScreen({
    super.key,
    required this.userData,
    this.entry,
  });

  @override
  State<JournalEditorScreen> createState() => _JournalEditorScreenState();
}

class _JournalEditorScreenState extends State<JournalEditorScreen> {
  final _contentController = TextEditingController();
  final _firestoreService = FirestoreService();

  int? _selectedMood;
  bool _isSaving = false;
  late DateTime _noteDate;
  late int _personalDay;

  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();

    _noteDate = widget.entry?.createdAt ?? DateTime.now();
    _personalDay =
        widget.entry?.personalDay ?? _calculatePersonalDay(_noteDate);

    if (_isEditing) {
      _contentController.text = widget.entry!.content;
      _selectedMood = widget.entry!.mood;
    }
  }

  int _calculatePersonalDay(DateTime date) {
    final engine = NumerologyEngine(
      nomeCompleto: widget.userData.nomeAnalise,
      dataNascimento: widget.userData.dataNasc,
    );
    return engine.calculatePersonalDayForDate(date);
  }

  Future<void> _handleSave() async {
    if (_contentController.text.trim().isEmpty || _isSaving) return;

    setState(() => _isSaving = true);

    final dataToSave = {
      'content': _contentController.text.trim(),
      'updatedAt': Timestamp.now(),
      'mood': _selectedMood,
    };

    try {
      if (_isEditing) {
        await _firestoreService.updateJournalEntry(
            widget.userData.uid, widget.entry!.id, dataToSave);
      } else {
        dataToSave['createdAt'] = Timestamp.fromDate(_noteDate);
        dataToSave['personalDay'] = _personalDay;
        await _firestoreService.addJournalEntry(
            widget.userData.uid, dataToSave);
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _isSaving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade400,
          content: const Text('Erro ao salvar a anotação. Tente novamente.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = toBeginningOfSentenceCase(
      DateFormat("EEEE, d 'de' MMMM 'de' yyyy", 'pt_BR').format(_noteDate),
    );

    return Scaffold(
      backgroundColor: AppColors.cardBackground,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        leading: const CloseButton(color: AppColors.secondaryText),
        title: Text(
          _isEditing ? 'Editar Anotação' : 'Nova Anotação',
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: VibrationPill(vibrationNumber: _personalDay),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: TextField(
                controller: _contentController,
                autofocus: true,
                maxLines: null,
                expands: true,
                style: const TextStyle(
                    color: Colors.white, fontSize: 18, fontFamily: 'serif'),
                decoration: const InputDecoration(
                  hintText:
                      "Escreva seus pensamentos, sentimentos e reflexões do dia aqui...",
                  hintStyle:
                      TextStyle(color: AppColors.tertiaryText, fontSize: 18),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        decoration: const BoxDecoration(
          color: AppColors.cardBackground,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _MoodSelector(
              selectedMood: _selectedMood,
              onMoodSelected: (mood) {
                setState(() {
                  _selectedMood = (_selectedMood == mood) ? null : mood;
                });
              },
            ),
            FloatingActionButton(
              onPressed: _handleSave,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 2,
              // *** INÍCIO DA CORREÇÃO ***
              // Substituímos o CustomLoadingSpinner por um CircularProgressIndicator
              // com tamanho definido para caber dentro do botão.
              child: _isSaving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : const Icon(Icons.check),
              // *** FIM DA CORREÇÃO ***
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodSelector extends StatelessWidget {
  final int? selectedMood;
  final ValueChanged<int> onMoodSelected;

  const _MoodSelector({this.selectedMood, required this.onMoodSelected});

  @override
  Widget build(BuildContext context) {
    final moods = {
      1: '😔',
      2: '😟',
      3: '😐',
      4: '😊',
      5: '😄',
    };

    return Row(
      children: moods.entries.map((entry) {
        final moodId = entry.key;
        final emoji = entry.value;
        final isSelected = selectedMood == moodId;

        return GestureDetector(
          onTap: () => onMoodSelected(moodId),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
            transform: isSelected
                ? (Matrix4.identity()..scale(1.2))
                : Matrix4.identity(),
            child: Text(emoji, style: const TextStyle(fontSize: 28)),
          ),
        );
      }).toList(),
    );
  }
}
