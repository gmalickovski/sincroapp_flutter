import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_end_date_picker_dialog.dart';
import 'package:sincro_app_flutter/models/user_model.dart';

class GoalOnboardingModal extends StatefulWidget {
  final Function(String title, String? date) onAddMilestone;
  final VoidCallback? onSuggestWithAI;
  final VoidCallback onClose;
  final UserModel userData;

  const GoalOnboardingModal({
    super.key,
    required this.onAddMilestone,
    required this.onClose,
    required this.userData,
    this.onSuggestWithAI,
  });

  @override
  State<GoalOnboardingModal> createState() => _GoalOnboardingModalState();
}

class _GoalOnboardingModalState extends State<GoalOnboardingModal> {
  final List<Map<String, String>> _addedMilestones = [];
  final TextEditingController _titleController = TextEditingController();
  DateTime? _selectedDate;
  bool _showAddForm = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _addMilestone() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Digite um título para o marco'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final milestone = {
      'title': _titleController.text.trim(),
      if (_selectedDate != null)
        'date': '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}',
    };

    setState(() {
      _addedMilestones.add(milestone);
      _titleController.clear();
      _selectedDate = null;
      _showAddForm = false;
    });

    // Chama o callback para adicionar no Firestore
    widget.onAddMilestone(
      milestone['title']!,
      milestone['date'],
    );
  }

  void _removeMilestone(int index) {
    setState(() {
      _addedMilestones.removeAt(index);
    });
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => CustomEndDatePickerDialog(
        initialDate: _selectedDate ?? DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 3650)),
        userData: widget.userData,
      ),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        if (isMobile) {
          return Scaffold(
            backgroundColor: AppColors.cardBackground,
            body: SafeArea(
              child: Column(
                children: [
                  // Mobile Header with Close Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.secondaryText),
                          onPressed: widget.onClose,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: _buildContent(isMobile: true),
                    ),
                  ),
                  // Mobile Footer (Fixed)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: _buildFooter(isMobile: true),
                  ),
                ],
              ),
            ),
          );
        }

        // Desktop / Tablet Layout
        return Stack(
          children: [
            // Backdrop Blur
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ),
            ),
            // Modal Content
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Scrollable Content
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
                          child: _buildContent(isMobile: false),
                        ),
                      ),
                      // Fixed Footer
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: _buildFooter(isMobile: false),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildContent({required bool isMobile}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        if (isMobile) ...[
          // Big Centered Header for Mobile
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.flag_rounded,
              size: 48,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Comece sua Jornada!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ] else ...[
          // Compact Row Header for Desktop
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.flag_rounded,
                  size: 24,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Comece sua Jornada!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
        
        const SizedBox(height: 16),
        
        // Subtitle
        Text(
          _addedMilestones.isEmpty
              ? 'Adicione marcos iniciais para dar os primeiros passos.'
              : '${_addedMilestones.length} marco(s) adicionado(s).',
          textAlign: isMobile ? TextAlign.center : TextAlign.left,
          style: const TextStyle(
            color: AppColors.secondaryText,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        
        const SizedBox(height: 24),

        // Explanatory Text
        if (!_showAddForm) // Hide info when adding to save space
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: AppColors.primary, size: 18),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Marcos são pequenas vitórias que compõem sua meta maior.',
                    style: TextStyle(
                      color: AppColors.tertiaryText,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 20),

        // Add Form Section
        if (_showAddForm) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Novo Marco',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // Close Button within form (kept as convenience)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _showAddForm = false;
                          _titleController.clear();
                          _selectedDate = null;
                        });
                      },
                      child: const Icon(
                        Icons.close,
                        color: AppColors.secondaryText,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Ex: Ler 10 páginas',
                    hintStyle: const TextStyle(color: AppColors.tertiaryText, fontSize: 14),
                    filled: true,
                    fillColor: AppColors.cardBackground,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today,
                            color: _selectedDate != null ? AppColors.primary : AppColors.tertiaryText, 
                            size: 18),
                        const SizedBox(width: 10),
                        Text(
                          _selectedDate == null
                              ? 'Data limite (opcional)'
                              : '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}',
                          style: TextStyle(
                            color: _selectedDate == null
                                ? AppColors.tertiaryText
                                : Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Button removed from here for Mobile, kept for Desktop logic if needed, 
                // but simpler to use the unified footer logic.
                // We'll hide the internal button and use the footer button.
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Milestones List
        if (_addedMilestones.isNotEmpty && !_showAddForm) ...[
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              itemCount: _addedMilestones.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final milestone = _addedMilestones[index];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, color: Colors.white, size: 10),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              milestone['title']!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (milestone['date'] != null)
                              Text(
                                milestone['date']!,
                                style: const TextStyle(
                                  color: AppColors.secondaryText,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                        onPressed: () => _removeMilestone(index),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // const SizedBox(height: 16), // Spacing handled by padding of parent scrollview/footer
        ],
      ],
    );
  }

  Widget _buildFooter({required bool isMobile}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_showAddForm) ...[
           // ACTIONS FOR ADD FORM (Back & Add)
           Row(
             children: [
               // Back Button
               Expanded(
                 flex: 1,
                 child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _showAddForm = false;
                        _titleController.clear();
                        _selectedDate = null;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Icon(Icons.arrow_back, color: AppColors.secondaryText, size: 20),
                 ),
               ),
               const SizedBox(width: 12),
               // Add Button
               Expanded(
                 flex: 3,
                 child: ElevatedButton(
                    onPressed: _addMilestone,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 4,
                      shadowColor: AppColors.primary.withValues(alpha: 0.4),
                    ),
                    child: const Text('Adicionar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                 ),
               ),
             ],
           ),

        ] else ...[
          // ACTIONS FOR MAIN VIEW
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _showAddForm = true;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 4,
                shadowColor: AppColors.primary.withValues(alpha: 0.4),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Adicionar Marco',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          if (widget.onSuggestWithAI != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: widget.onSuggestWithAI,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome, color: AppColors.primary, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Sugerir com IA',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          if (_addedMilestones.isNotEmpty) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: widget.onClose,
              child: const Text(
                'Concluir e Fechar',
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}
