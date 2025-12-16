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
    final isDesktop = MediaQuery.of(context).size.width >= 600;
    
    if (isDesktop) {
      showDialog(
        context: context,
        builder: (context) => FeedbackModal(userData: userData),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true, // Native "Close" button animation feeling
          builder: (context) => FeedbackModal(userData: userData),
        ),
      );
    }
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
    final isDesktop = MediaQuery.of(context).size.width >= 600;
    return isDesktop ? _buildDesktopLayout() : _buildMobileLayout();
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: AppColors.secondaryText),
          ),
        ],
        title: const Text(
          'Enviar Feedback',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Type Selector
                    // Type Selector (Grid)
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 2.5, // Adjust for card shape
                      children: [
                        _buildTypeButton(type: FeedbackType.bug, label: 'Reportar Bug', icon: Icons.bug_report),
                        _buildTypeButton(type: FeedbackType.idea, label: 'Sugerir Ideia', icon: Icons.lightbulb),
                        _buildTypeButton(type: FeedbackType.account, label: 'Conta', icon: Icons.person),
                        _buildTypeButton(type: FeedbackType.subscription, label: 'Assinatura', icon: Icons.credit_card),
                        _buildTypeButton(type: FeedbackType.tech, label: 'Problemas', icon: Icons.build),
                        _buildTypeButton(type: FeedbackType.general, label: 'Outros', icon: Icons.help_outline),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Description Label
                    const Text(
                      'Descrição',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Description Input
                    TextField(
                      controller: _descriptionController,
                      maxLines: 8,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: _selectedType == FeedbackType.bug
                            ? 'Qual o problema? O que você estava fazendo quando aconteceu?'
                            : 'Compartilhe sua ideia para melhorar o app...',
                        hintStyle: const TextStyle(color: AppColors.tertiaryText),
                        filled: true,
                        fillColor: AppColors.cardBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Footer (Bottom Actions)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.background, // Match background to avoid "floating" feel
                border: Border(top: BorderSide(color: Colors.white10)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   // Attachment Button
                  OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: Icon(
                      _attachment == null ? Icons.attach_file : Icons.check_circle, 
                      color: _attachment == null ? AppColors.secondaryText : Colors.green
                    ),
                    label: Text(
                      _attachment == null ? 'Anexar Captura de Tela' : 'Imagem Anexada',
                      style: TextStyle(
                        color: _attachment == null ? AppColors.secondaryText : Colors.green
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: _attachment == null ? AppColors.border : Colors.green
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Submit Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Enviar Feedback',
                            style: TextStyle(
                              color: Colors.white, 
                              fontSize: 16, 
                              fontWeight: FontWeight.bold
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Dialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 500),
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
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 3, // Wider cards for desktop
              children: [
                _buildTypeButton(type: FeedbackType.bug, label: 'Reportar Bug', icon: Icons.bug_report),
                _buildTypeButton(type: FeedbackType.idea, label: 'Sugerir Ideia', icon: Icons.lightbulb),
                _buildTypeButton(type: FeedbackType.account, label: 'Conta e Segurança', icon: Icons.person),
                _buildTypeButton(type: FeedbackType.subscription, label: 'Assinatura e Planos', icon: Icons.credit_card),
                _buildTypeButton(type: FeedbackType.tech, label: 'Solução de Problemas', icon: Icons.build),
                _buildTypeButton(type: FeedbackType.general, label: 'Primeiros Passos / Outros', icon: Icons.help_outline),
              ],
            ),
            const SizedBox(height: 24),
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
