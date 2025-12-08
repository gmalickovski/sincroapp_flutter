import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/feedback/models/feedback_model.dart';
import 'package:sincro_app_flutter/services/feedback_service.dart';
import 'package:sincro_app_flutter/models/user_model.dart';

class FeedbackModal extends StatefulWidget {
  final UserModel userData;

  const FeedbackModal({super.key, required this.userData});

  static void show(BuildContext context, UserModel userData) {
    showDialog(
      context: context,
      builder: (context) => FeedbackModal(userData: userData),
    );
  }

  @override
  State<FeedbackModal> createState() => _FeedbackModalState();
}

class _FeedbackModalState extends State<FeedbackModal> {
  FeedbackType _selectedType = FeedbackType.bug;
  final TextEditingController _descriptionController = TextEditingController();
  XFile? _attachment;
  bool _isLoading = false;
  final FeedbackService _service = FeedbackService();

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    // Optimization: Resize/Compress to solve Mobile Web Timeout with large camera photos
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024, // Reasonable HD width
      imageQuality: 70, // 70% quality (greatly reduces size)
    );
    if (picked != null) {
      setState(() {
        _attachment = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, descreva o problema ou ideia.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final feedback = FeedbackModel(
        type: _selectedType,
        description: _descriptionController.text.trim(),
        userId: widget.userData.uid,
        userEmail: widget.userData.email,
        appVersion: '', // Service fills this
        deviceInfo: '', // Service fills this
        timestamp: DateTime.now(),
      );

      await _service.sendFeedback(feedback: feedback, attachment: _attachment);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Obrigado! Seu feedback foi enviado.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 500), // Desktop friendly
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Enviar Feedback',
                  style: TextStyle(
                    color: Colors.white, 
                    fontSize: 20, 
                    fontWeight: FontWeight.bold
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.secondaryText),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const SizedBox(height: 24),
            
            // Type Selector
            Row(
              children: [
                Expanded(
                  child: _buildTypeButton(
                    type: FeedbackType.bug,
                    label: 'Reportar Bug',
                    icon: Icons.bug_report,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTypeButton(
                    type: FeedbackType.idea,
                    label: 'Sugerir Ideia',
                    icon: Icons.lightbulb,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Description
            TextField(
              controller: _descriptionController,
              maxLines: 5,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: _selectedType == FeedbackType.bug
                    ? 'Descreva o que aconteceu, passos para reproduzir...'
                    : 'Compartilhe sua ideia ou sugestão...',
                hintStyle: const TextStyle(color: AppColors.tertiaryText),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Attachment (Visual only for now if MVP doesn't support upload in logic)
            // Ideally we'd show a preview here.
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: Icon(_attachment == null ? Icons.attach_file : Icons.check, color: AppColors.primary),
              label: Text(
                _attachment == null ? 'Anexar Print (Opcional)' : 'Imagem Anexada',
                style: const TextStyle(color: AppColors.primary),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),

            const SizedBox(height: 24),
            
            // Submit
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Enviar',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeButton({
    required FeedbackType type,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedType == type;
    return InkWell(
      onTap: () => setState(() => _selectedType = type),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.2) : AppColors.background,
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppColors.primary : AppColors.secondaryText),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.secondaryText,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
