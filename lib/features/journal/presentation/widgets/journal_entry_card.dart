// lib/features/journal/presentation/widgets/journal_entry_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/vibration_pill.dart';
import 'package:sincro_app_flutter/features/journal/models/journal_entry_model.dart';

class JournalEntryCard extends StatelessWidget {
  final JournalEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const JournalEntryCard({
    super.key,
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  // Mapeia o ID do humor para o emoji correspondente
  static const Map<int, String> _moodMap = {
    1: '😔',
    2: '😟',
    3: '😐',
    4: '😊',
    5: '😄',
  };

  // Mapeia o número do Dia Pessoal para uma cor de borda
  Color _getBorderColor() {
    switch (entry.personalDay) {
      case 1:
        return Colors.red.shade400;
      case 2:
        return Colors.orange.shade400;
      case 3:
        return Colors.yellow.shade400;
      case 4:
        return Colors.lime.shade400;
      case 5:
        return Colors.cyan.shade400;
      case 6:
        return Colors.blue.shade400;
      case 7:
        return Colors.purple.shade400;
      case 8:
        return Colors.pink.shade400;
      case 9:
        return Colors.teal.shade400;
      case 11:
        return Colors.purple.shade300;
      case 22:
        return Colors.indigo.shade300;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _getBorderColor();
    final formattedDate =
        DateFormat("d 'de' MMMM", 'pt_BR').format(entry.createdAt);
    final formattedTime = DateFormat("HH:mm").format(entry.createdAt);

    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho do Card
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formattedDate,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        formattedTime,
                        style: const TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (entry.mood != null && _moodMap.containsKey(entry.mood))
                  Text(_moodMap[entry.mood]!,
                      style: const TextStyle(fontSize: 24)),
              ],
            ),
            const SizedBox(height: 12),

            // Corpo do Card
            Text(
              entry.content,
              maxLines: 10, // Limita o número de linhas visíveis
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 15,
                height: 1.5,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 12),

            // Rodapé do Card
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                VibrationPill(vibrationNumber: entry.personalDay),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    } else if (value == 'delete') {
                      onDelete();
                    }
                  },
                  icon: const Icon(Icons.more_vert,
                      color: AppColors.secondaryText),
                  color: AppColors.cardBackground,
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child:
                          Text('Editar', style: TextStyle(color: Colors.white)),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('Excluir',
                          style: TextStyle(color: Colors.red.shade400)),
                    ),
                  ],
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
