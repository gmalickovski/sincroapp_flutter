import 'dart:io';
import 'dart:typed_data'; // Added for Uint8List

import 'package:flutter/foundation.dart'; // for kIsWeb
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
  Uint8List? _imageBytes; // Store bytes for robust upload/preview
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
        // Read bytes immediately to prevent "revoked blob" issues on Web
        final Uint8List bytes = await image.readAsBytes();
        
        setState(() {
          _selectedImage = image;
          _imageBytes = bytes;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Erro ao selecionar imagem: $e";
        });
      }
    }
  }

  Future<void> _handleSave() async {
    if (_selectedImage == null || _imageBytes == null) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      debugPrint('[ImageUploadDialog] Starting upload...');
      debugPrint('[ImageUploadDialog] File: ${_selectedImage!.name}, Bytes: ${_imageBytes!.length}');
      debugPrint('[ImageUploadDialog] UserId: ${widget.userData.uid}');
      
      // 1. Upload Image (using bytes)
      final String downloadUrl = await _storageService.uploadGoalImage(
        fileBytes: _imageBytes!,
        fileName: _selectedImage!.name,
        userId: widget.userData.uid,
      );

      debugPrint('[ImageUploadDialog] Upload successful! URL: $downloadUrl');

      // 2. Update Goal in Firestore
      final updatedGoal = widget.goal.copyWith(imageUrl: downloadUrl);
      
      debugPrint('[ImageUploadDialog] Updating goal ${widget.goal.id} with imageUrl...');
      await _firestoreService.updateGoal(updatedGoal);
      debugPrint('[ImageUploadDialog] Goal updated successfully!');

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Imagem atualizada com sucesso!'), backgroundColor: AppColors.primary),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('[ImageUploadDialog] ERROR: $e');
      debugPrint('[ImageUploadDialog] StackTrace: $stackTrace');
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        if (isMobile) {
          return Scaffold(
            backgroundColor: AppColors.cardBackground,
            appBar: AppBar(
              title: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.image, color: AppColors.primary, size: 24),
                  SizedBox(width: 12),
                  Text("Adicionar Imagem", style: TextStyle(color: Colors.white, fontSize: 18)),
                ],
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              automaticallyImplyLeading: false, // Remove back arrow
              actions: [
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.secondaryText),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _buildContent(),
              ),
            ),
          );
        }

        // Desktop Layout - Compact Dialog
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Desktop Header
                      _buildDesktopHeader(),
                      
                      // Content (Scrollable)
                      Flexible(
                         child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                               _buildErrorMessage(),
                               _buildImagePreview(),
                               const SizedBox(height: 24),
                               _buildInstructions(),
                               const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
            
                      // Footer (Fixed Buttons)
                      _buildFooterButtons(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.image, color: AppColors.primary, size: 24),
              SizedBox(width: 12),
              Text(
                "Adicionar Imagem",
                style: TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.secondaryText),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    if (_errorMessage == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Text(
          _errorMessage!,
          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 250,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: _imageBytes != null ? AppColors.primary : AppColors.border, 
              width: _imageBytes != null ? 1.5 : 1
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: _buildImageContent(),
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          "Dicas para a imagem:",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        SizedBox(height: 8),
        Text(
          "• Use imagens no formato paisagem (horizontal).\n• Escolha imagens que inspirem sua meta.\n• Tamanho máximo recomendado: 2MB.",
          style: TextStyle(color: AppColors.secondaryText, height: 1.5, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildFooterButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
         border: Border(
            top: BorderSide(color: AppColors.border.withValues(alpha: 0.2)),
         )
      ),
      child: _isSaving
        ? const Center(child: CustomLoadingSpinner())
        : Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Cancelar", style: TextStyle(color: AppColors.secondaryText)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _imageBytes != null ? _handleSave : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.3),
                    disabledForegroundColor: Colors.white.withValues(alpha: 0.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text("Salvar Imagem", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
    );
  }
  
  // Kept for compatibility with Mobile Layout call
  Widget _buildContent() {
     return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildErrorMessage(),
        _buildImagePreview(),
        const SizedBox(height: 24),
        _buildInstructions(),
        const SizedBox(height: 24),
        // On mobile, footer is part of content for now to keep it simple or we could refactor similarly
        _isSaving
        ? const Center(child: CustomLoadingSpinner())
        : Row(
            mainAxisAlignment: MainAxisAlignment.end,
             children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Cancelar", style: TextStyle(color: AppColors.secondaryText)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _imageBytes != null ? _handleSave : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.3),
                    disabledForegroundColor: Colors.white.withValues(alpha: 0.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text("Salvar Imagem", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
      ]
     );

  Widget _buildImageContent() {
    if (_imageBytes != null) {
      // Use Image.memory for consistent preview across platforms
      // and avoiding Blob URL revocation issues on Web
      return Image.memory(
        _imageBytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
      );
    }

    // Default Placeholder
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate_outlined,
            size: 48, color: AppColors.primary),
        SizedBox(height: 16),
        Text("Selecionar Imagem",
            style: TextStyle(color: AppColors.secondaryText, fontSize: 16)),
      ],
    );
  }
}
