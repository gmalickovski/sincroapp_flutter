import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/vibration_pill.dart';
import 'package:sincro_app_flutter/features/authentication/data/content_data.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';

class TaskInputModal extends StatefulWidget {
  final Function(String text) onAddTask;
  final UserModel? userData;

  const TaskInputModal({
    super.key,
    required this.onAddTask,
    required this.userData,
  });

  @override
  State<TaskInputModal> createState() => _TaskInputModalState();
}

class _TaskInputModalState extends State<TaskInputModal> {
  final _textController = TextEditingController();
  int _personalDay = 0;
  VibrationContent? _dayInfo;

  @override
  void initState() {
    super.initState();
    _calculateVibration();
  }

  // Calcula a vibração do dia atual para exibir no modal
  void _calculateVibration() {
    if (widget.userData != null && widget.userData!.dataNasc.isNotEmpty) {
      final engine = NumerologyEngine(
        nomeCompleto: widget.userData!.nomeAnalise,
        dataNascimento: widget.userData!.dataNasc,
      );
      final day = engine.calculatePersonalDayForDate(DateTime.now());
      if (mounted) {
        setState(() {
          _personalDay = day;
          _dayInfo = ContentData.vibracoes['diaPessoal']?[_personalDay];
        });
      }
    }
  }

  // Insere o texto dos botões de ação (#, @, /) no campo de texto
  void _insertActionText(String char) {
    final text = _textController.text;
    final selection = _textController.selection;
    final newText = text.replaceRange(selection.start, selection.end, char);
    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: selection.start + char.length),
    );
  }

  void _submit() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      widget.onAddTask(text);
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        decoration: const BoxDecoration(
          color: Color(0xFF27272a), // Cor de fundo do modal, mais escura
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24.0),
            topRight: Radius.circular(24.0),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Campo de texto principal
            TextField(
              controller: _textController,
              autofocus: true,
              style:
                  const TextStyle(fontSize: 16, color: AppColors.secondaryText),
              decoration: const InputDecoration(
                hintText: "Adicionar tarefa, #tag, @jornada, /data",
                hintStyle: TextStyle(color: AppColors.tertiaryText),
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),

            // Barra de contexto com a VibrationPill (se houver dados)
            if (_personalDay > 0 && _dayInfo != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    VibrationPill(
                      vibrationNumber: _personalDay,
                      onTap: () => showVibrationInfoModal(context,
                          vibrationNumber: _personalDay),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _dayInfo!.descricaoCurta,
                        style: const TextStyle(
                            color: AppColors.secondaryText, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 4),

            // Botões de ação e botão de submeter
            Row(
              children: [
                _buildActionButton(
                    icon: Icons.tag, onTap: () => _insertActionText('#')),
                _buildActionButton(
                    icon: Icons.track_changes_outlined,
                    onTap: () => _insertActionText('@')),
                _buildActionButton(
                    icon: Icons.calendar_today_outlined,
                    onTap: () {
                      // No futuro, isto abrirá um mini-calendário
                      _insertActionText('/');
                    }),
                const Spacer(),
                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  child: const Icon(Icons.arrow_upward,
                      color: Colors.white, size: 20),
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  // Widget para os botões de ação (apenas ícone)
  Widget _buildActionButton(
      {required IconData icon, required VoidCallback onTap}) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: AppColors.tertiaryText),
      splashRadius: 20,
      constraints: const BoxConstraints(),
      padding: const EdgeInsets.all(8),
    );
  }
}
