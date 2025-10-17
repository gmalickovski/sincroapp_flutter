// lib/features/settings/presentation/tabs/account_settings_tab.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';

class AccountSettingsTab extends StatefulWidget {
  final UserModel userData;
  const AccountSettingsTab({super.key, required this.userData});

  @override
  State<AccountSettingsTab> createState() => _AccountSettingsTabState();
}

class _AccountSettingsTabState extends State<AccountSettingsTab> {
  final _firestoreService = FirestoreService();
  final _auth = FirebaseAuth.instance;
  final _formKeyInfo = GlobalKey<FormState>();
  final _formKeyPassword = GlobalKey<FormState>();

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSavingInfo = false;
  bool _isSavingPassword = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _firstNameController =
        TextEditingController(text: widget.userData.primeiroNome);
    _lastNameController =
        TextEditingController(text: widget.userData.sobrenome);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showFeedback(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade400 : Colors.green.shade400,
      ),
    );
  }

  Future<void> _handleSaveChanges() async {
    if (!_formKeyInfo.currentState!.validate()) return;
    setState(() => _isSavingInfo = true);
    try {
      await _firestoreService.updateUserData(widget.userData.uid, {
        'primeiroNome': _firstNameController.text.trim(),
        'sobrenome': _lastNameController.text.trim(),
      });
      _showFeedback('Informações salvas com sucesso!');
    } catch (e) {
      _showFeedback('Erro ao salvar as informações.', isError: true);
    } finally {
      if (mounted) setState(() => _isSavingInfo = false);
    }
  }

  Future<void> _handleChangePassword() async {
    if (!_formKeyPassword.currentState!.validate()) return;
    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showFeedback('As novas senhas não coincidem.', isError: true);
      return;
    }
    setState(() => _isSavingPassword = true);
    try {
      final user = _auth.currentUser;
      final cred = EmailAuthProvider.credential(
          email: user!.email!, password: _currentPasswordController.text);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(_newPasswordController.text);
      _showFeedback('Senha alterada com sucesso!');
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    } on FirebaseAuthException catch (e) {
      _showFeedback(
          'Erro ao alterar a senha: ${e.code == 'wrong-password' ? 'Senha atual incorreta.' : 'Tente novamente.'}',
          isError: true);
    } catch (e) {
      _showFeedback('Ocorreu um erro inesperado.', isError: true);
    } finally {
      if (mounted) setState(() => _isSavingPassword = false);
    }
  }

  Future<void> _handleDeleteAccount() async {
    final password = await _showPasswordConfirmationDialog();
    if (password == null || password.isEmpty) return;

    setState(() => _isDeleting = true);
    try {
      final user = _auth.currentUser;
      final cred =
          EmailAuthProvider.credential(email: user!.email!, password: password);
      await user.reauthenticateWithCredential(cred);
      await user.delete();
      // Em um app real, aqui você navegaria para a tela de login
      _showFeedback('Conta deletada com sucesso.');
    } on FirebaseAuthException catch (e) {
      _showFeedback(
          'Erro ao deletar conta: ${e.code == 'wrong-password' ? 'Senha incorreta.' : 'Tente novamente.'}',
          isError: true);
    } catch (e) {
      _showFeedback('Ocorreu um erro inesperado ao deletar a conta.',
          isError: true);
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  Future<String?> _showPasswordConfirmationDialog() {
    final passwordController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Confirmar Exclusão',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Digite sua senha para confirmar',
            labelStyle: TextStyle(color: AppColors.secondaryText),
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('Confirmar', style: TextStyle(color: Colors.red)),
            onPressed: () => Navigator.of(context).pop(passwordController.text),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Seção Minha Conta
          _buildSectionHeader(
              'Minha Conta', 'Veja e edite suas informações pessoais.'),
          Form(
            key: _formKeyInfo,
            child: Column(
              children: [
                TextFormField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(labelText: 'Sobrenome'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isSavingInfo ? null : _handleSaveChanges,
            child: _isSavingInfo
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Salvar Alterações'),
          ),

          const Divider(height: 48),

          // Seção Alterar Senha
          _buildSectionHeader('Alterar Senha', ''),
          Form(
            key: _formKeyPassword,
            child: Column(
              children: [
                TextFormField(
                  controller: _currentPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Senha Atual'),
                  validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Nova Senha'),
                  validator: (v) =>
                      (v?.length ?? 0) < 6 ? 'Mínimo de 6 caracteres' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: 'Confirmar Nova Senha'),
                  validator: (v) =>
                      (v?.length ?? 0) < 6 ? 'Mínimo de 6 caracteres' : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isSavingPassword ? null : _handleChangePassword,
            child: _isSavingPassword
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Alterar Senha'),
          ),

          const Divider(height: 48),

          // Seção Zona de Perigo
          _buildSectionHeader('Zona de Perigo',
              'Esta ação é irreversível. Todos os seus dados serão permanentemente excluídos.',
              isDangerZone: true),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.2),
                foregroundColor: Colors.red.shade300),
            onPressed: _isDeleting ? null : _handleDeleteAccount,
            child: _isDeleting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Deletar minha conta'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle,
      {bool isDangerZone = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: isDangerZone ? Colors.red.shade300 : Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (subtitle.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 16),
            child: Text(subtitle,
                style: const TextStyle(color: AppColors.secondaryText)),
          ),
      ],
    );
  }
}
