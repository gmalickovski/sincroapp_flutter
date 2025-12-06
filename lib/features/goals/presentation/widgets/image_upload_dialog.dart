import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';
import 'package:sincro_app_flutter/services/storage_service.dart';

class ImageUploadDialog extends StatefulWidget {
  final UserModel userData;
  final Goal goal;

  const ImageUploadDialog({
    super.key,
    required this.userData,
    required this.goal,
  });

  @override
  State<ImageUploadDialog> createState() => _ImageUploadDialogState();
}

class _ImageUploadDialogState extends State<ImageUploadDialog> {
  final ImagePicker _picker = ImagePicker();
  final StorageService _storageService = StorageService();
  final FirestoreService _firestoreService = FirestoreService();
  
  XFile? _selectedImage;
  bool _isSaving = false;
  String? _errorMessage;

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _selectedImage = image;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Erro ao selecionar imagem: $e";
      });
    }
  }

  Future<void> _handleSave() async {
    if (_selectedImage == null) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      // 1. Upload Image
      final String downloadUrl = await _storageService.uploadGoalImage(
        file: _selectedImage!,
        userId: widget.userData.uid,
      );

      // 2. Update Goal in Firestore
      final updatedGoal = widget.goal.copyWith(imageUrl: downloadUrl);
      
      // We only need to update the imageUrl, but updateGoal expects a full object.
      // Or we can use a partial update method if available? updateGoal updates everything.
      // Let's use updateGoal for consistency.
      await _firestoreService.updateGoal(updatedGoal);

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Imagem atualizada com sucesso!'), backgroundColor: AppColors.primary),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Erro ao salvar: $e";
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Shared content for Dialog (Desktop) and Scaffold (Mobile)
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.redAccent),
              textAlign: TextAlign.center,
            ),
          ),
        
        // Image Preview Area
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 250,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              image: _selectedImage != null
                  ? DecorationImage(
                      image: kIsWeb
                          ? NetworkImage(_selectedImage!.path)
                          : FileImage(File(_selectedImage!.path)) as ImageProvider,
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _selectedImage == null
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate,
                          size: 48, color: AppColors.primary),
                      SizedBox(height: 16),
                      Text("Selecionar Imagem",
                          style: TextStyle(color: Colors.white, fontSize: 16)),
                    ],
                  )
                : Stack(
                    children: [
                      Positioned(
                        top: 8,
                        right: 8,
                        child: CircleAvatar(
                          backgroundColor: Colors.black54,
                          child: IconButton(
                            icon: const Icon(Icons.edit, color: Colors.white),
                            onPressed: _pickImage,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Instructions
        const Text(
          "Dicas para a imagem:",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          "• Use imagens no formato paisagem (horizontal) para melhor visualização.\n• Escolha imagens que inspirem sua meta.\n• Tamanho máximo recomendado: 2MB.",
          style: TextStyle(color: AppColors.secondaryText, height: 1.5),
        ),

        const SizedBox(height: 32),

        // Action Buttons
        if (_isSaving)
          const Center(child: CustomLoadingSpinner())
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Cancelar", style: TextStyle(color: AppColors.secondaryText)),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: _selectedImage != null ? _handleSave : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                  disabledForegroundColor: Colors.white.withOpacity(0.5),
                ),
                child: const Text("Salvar Imagem"),
              ),
            ],
          ),
      ],
    );

    // If context indicates a dialog (Desktop), return simpler structure.
    // If mobile, we might want a full Scaffold?
    // The user requested "modal fullscreen" for mobile, "modal dialog" for desktop.
    // We can control the wrapper in the parent, but let's make this widget adaptable.
    
    // Actually, usually CreateGoalScreen handles full screen.
    // Let's assume this widget is the BODY of the screen/dialog.
    // But since we need an AppBar for fullscreen mobile, let's wrap logic.
    
    // Checking parent constraints or platform might be better done by the caller.
    // I will return a Scaffold if it looks like we are on mobile (using kIsWeb false and Platform is Android/iOS, or just use context width).
    // The user explicitly said: "modal fullscren... (mobile)" and "modal dialog... (desktop)".
    
    // I'll leave the wrapping to the caller `GoalDetailScreen`. I will just build the content here or build the Scaffold myself.
    // To be safe, I'll build a Scaffold.
    
    return Scaffold(
      backgroundColor: AppColors.cardBackground, // Dialog color
      appBar: AppBar(
        title: const Text("Adicionar Imagem", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const CloseButton(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(child: content),
      ),
    );
  }
}
