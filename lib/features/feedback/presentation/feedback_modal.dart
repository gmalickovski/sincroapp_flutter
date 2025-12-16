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

  // Helper for Dropdown Items
  List<DropdownMenuItem<FeedbackType>> get _dropdownItems {
    const style = TextStyle(color: Colors.white);
    return const [
      DropdownMenuItem(value: FeedbackType.bug, child: Row(children: [Icon(Icons.bug_report, color: AppColors.secondaryText), SizedBox(width: 8), Text('Reportar Bug', style: style)])),
      DropdownMenuItem(value: FeedbackType.idea, child: Row(children: [Icon(Icons.lightbulb, color: AppColors.secondaryText), SizedBox(width: 8), Text('Sugerir Ideia', style: style)])),
      DropdownMenuItem(value: FeedbackType.account, child: Row(children: [Icon(Icons.person, color: AppColors.secondaryText), SizedBox(width: 8), Text('Conta e Segurança', style: style)])),
      DropdownMenuItem(value: FeedbackType.subscription, child: Row(children: [Icon(Icons.credit_card, color: AppColors.secondaryText), SizedBox(width: 8), Text('Assinatura e Planos', style: style)])),
      DropdownMenuItem(value: FeedbackType.tech, child: Row(children: [Icon(Icons.build, color: AppColors.secondaryText), SizedBox(width: 8), Text('Solução de Problemas', style: style)])),
      DropdownMenuItem(value: FeedbackType.general, child: Row(children: [Icon(Icons.help_outline, color: AppColors.secondaryText), SizedBox(width: 8), Text('Outros / Dúvidas', style: style)])),
    ];
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
          'Ajuda e Feedback', // Updated Title
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
                    // Subject Dropdown
                    const Text(
                      'Assunto',
                      style: TextStyle(color: AppColors.secondaryText, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.transparent),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<FeedbackType>(
                          value: _selectedType,
                          dropdownColor: AppColors.cardBackground,
                          icon: const Icon(Icons.arrow_drop_down, color: AppColors.secondaryText),
                          isExpanded: true,
                          items: _dropdownItems,
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedType = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

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
                        hintText: 'Como podemos ajudar? Descreva sua dúvida ou problema...',
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
                color: AppColors.background,
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
                            'Enviar',
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
                  'Ajuda e Feedback', // Updated Title
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
            
            // Dropdown Desktop
            const Text(
              'Assunto',
              style: TextStyle(color: AppColors.secondaryText, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<FeedbackType>(
                  value: _selectedType,
                  dropdownColor: AppColors.background,
                  icon: const Icon(Icons.arrow_drop_down, color: AppColors.secondaryText),
                  isExpanded: true,
                  items: _dropdownItems,
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedType = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            TextField(
              controller: _descriptionController,
              maxLines: 5,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Descreva sua dúvida ou problema...',
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
}

