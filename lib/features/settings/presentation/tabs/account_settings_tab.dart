// lib/features/settings/presentation/tabs/account_settings_tab.dart

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';
import 'package:sincro_app_flutter/common/utils/username_validator.dart'; // NOVO
import 'package:sincro_app_flutter/features/settings/presentation/widgets/contact_management_modal.dart'; // NOVO
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountSettingsTab extends StatefulWidget {
  final UserModel userData;
  const AccountSettingsTab({super.key, required this.userData});

  @override
  State<AccountSettingsTab> createState() => _AccountSettingsTabState();
}

class _AccountSettingsTabState extends State<AccountSettingsTab> {
  final _supabaseService = SupabaseService();
  final _supabase = Supabase.instance.client;
  final _formKeyInfo = GlobalKey<FormState>();
  final _formKeyPassword = GlobalKey<FormState>();

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _usernameController; // NOVO: Controller para username
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
    _usernameController =
        TextEditingController(text: widget.userData.username ?? ''); // Inicializa username
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
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
      final newUsername = _usernameController.text.trim();
      final currentUsername = widget.userData.username;

      // Se mudou o username, faz validações extras
      if (newUsername.isNotEmpty && newUsername != currentUsername) {
        // Validação de formato (já feita pelo validator do campo, mas reforçando)
        if (!UsernameValidator.isValidFormat(newUsername)) {
          _showFeedback('Formato de username inválido.', isError: true);
          return;
        }

        // Verifica disponibilidade
        final isAvailable = await _supabaseService.isUsernameAvailable(newUsername);
        if (!isAvailable) {
          _showFeedback('Este nome de usuário já está em uso.', isError: true);
          return; // Para aqui
        }
      }

      // Prepara dados para atualização
      final Map<String, dynamic> updates = {
        'primeiroNome': _firstNameController.text.trim(),
        'sobrenome': _lastNameController.text.trim(),
      };
      
      // Adiciona username se mudou
      if (newUsername != currentUsername) {
        updates['username'] = newUsername.isEmpty ? null : newUsername;
      }

      await _supabaseService.updateUserData(widget.userData.uid, updates);
      
      _showFeedback('Informações salvas com sucesso!');
    } catch (e) {
      debugPrint('Erro: $e');
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
      final user = _supabase.auth.currentUser;
      if (user == null || user.email == null) throw 'Usuário não logado';

      // Re-autenticar para segurança antes de mudar senha
      await _supabase.auth.signInWithPassword(
        email: user.email, 
        password: _currentPasswordController.text
      );
      
      // Atualizar senha
      await _supabase.auth.updateUser(
        UserAttributes(password: _newPasswordController.text)
      );

      _showFeedback('Senha alterada com sucesso!');
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    } on AuthException catch (e) {
       _showFeedback(
          'Erro ao alterar a senha: ${e.message}',
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
      final user = _supabase.auth.currentUser;
      if (user == null || user.email == null) throw 'Usuário não logado';

      // Re-autenticar para confirmar que sabe a senha
      await _supabase.auth.signInWithPassword(
        email: user.email, 
        password: password
      );
      
      // Como o Client Side do Supabase não permite deletar usuário por padrão (security),
      // e ainda não configuramos uma Edge Function para isso, vamos apenas exibir um aviso
      // ou implementar Soft Delete se tivermos essa lógica.
      // Por enquanto, vamos avisar para contactar suporte ou lançar erro amigável.
      
      // await _supabase.functions.invoke('delete-account'); // Exemplo futuro
      
      _showFeedback('Funcionalidade indisponível temporariamente. Contate o suporte.', isError: false);

      /* 
      // Em um cenário ideal com permissão ou Edge Function:
      await _supabase.rpc('soft_delete_account'); 
      await _supabase.auth.signOut();
      // Navigate to login...
      */
      
    } on AuthException catch (e) {
       _showFeedback(
          'Senha incorreta ou erro de autenticação: ${e.message}',
          isError: true);
    } catch (e) {
      _showFeedback('Ocorreu um erro inesperado ao processar.',
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
          decoration: InputDecoration(
            labelText: 'Digite sua senha para confirmar',
            labelStyle: const TextStyle(color: AppColors.secondaryText),
            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.secondaryText),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
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
    // Check if running on desktop (based on SettingsScreen breakpoint)
    final isDesktop = MediaQuery.of(context).size.width >= 720;
    
    return SingleChildScrollView(
      padding: isDesktop
          ? const EdgeInsets.fromLTRB(16, 0, 16, 16)
          : const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Seção Minha Conta
          _buildSectionCard(
            title: 'Minha Conta',
            subtitle: 'Veja e edite suas informações pessoais.',
            content: Form(
              key: _formKeyInfo,
              child: Column(
                children: [
                  // --- CAMPO USERNAME ---
                  TextFormField(
                    controller: _usernameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Nome de Usuário (@username)',
                      hintText: 'Ex: joao.silva',
                      labelStyle: const TextStyle(color: AppColors.secondaryText),
                      prefixIcon: const Icon(Icons.alternate_email, color: AppColors.secondaryText),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                    validator: (value) {
                       if (value == null || value.isEmpty) return null; // Opcional
                       return UsernameValidator.validate(value);
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _firstNameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Nome',
                      labelStyle: const TextStyle(color: AppColors.secondaryText),
                      prefixIcon: const Icon(Icons.person_outline, color: AppColors.secondaryText),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _lastNameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Sobrenome',
                      labelStyle: const TextStyle(color: AppColors.secondaryText),
                      prefixIcon: const Icon(Icons.person_outline, color: AppColors.secondaryText),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isSavingInfo ? null : _handleSaveChanges,
                    child: _isSavingInfo
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Salvar Alterações'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Seção Contatos (NOVO)
          _buildSectionCard(
            title: 'Contatos',
            subtitle: 'Gerencie sua lista de contatos e bloqueios.',
            content: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.people_outline, color: AppColors.primary),
                label: const Text('Gerenciar Contatos'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => ContactManagementModal(userId: widget.userData.uid),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Seção Alterar Senha
          _buildSectionCard(
            title: 'Alterar Senha',
            subtitle: 'Recomendamos o uso de uma senha forte e única.',
            content: Form(
              key: _formKeyPassword,
              child: Column(
                children: [
                  TextFormField(
                    controller: _currentPasswordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Senha Atual',
                      labelStyle: const TextStyle(color: AppColors.secondaryText),
                      prefixIcon: const Icon(Icons.lock_outline, color: AppColors.secondaryText),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                    validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Nova Senha',
                      labelStyle: const TextStyle(color: AppColors.secondaryText),
                      prefixIcon: const Icon(Icons.key, color: AppColors.secondaryText), // Using key icon to differentiate
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                    validator: (v) =>
                        (v?.length ?? 0) < 6 ? 'Mínimo de 6 caracteres' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Confirmar Nova Senha',
                      labelStyle: const TextStyle(color: AppColors.secondaryText),
                      prefixIcon: const Icon(Icons.check_circle_outline, color: AppColors.secondaryText),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                    validator: (v) =>
                        (v?.length ?? 0) < 6 ? 'Mínimo de 6 caracteres' : null,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isSavingPassword ? null : _handleChangePassword,
                    child: _isSavingPassword
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Alterar Senha'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Seção Zona de Perigo
          _buildSectionCard(
            isDangerZone: true,
            title: 'Zona de Perigo',
            subtitle:
                'Esta ação é irreversível. Todos os seus dados serão permanentemente excluídos.',
            content: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade800.withValues(alpha: 0.8),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 45)),
              onPressed: _isDeleting ? null : _handleDeleteAccount,
              child: _isDeleting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Deletar minha conta'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required Widget content,
    bool isDangerZone = false,
  }) {
    final borderColor = isDangerZone ? Colors.red.shade400 : AppColors.border;
    final titleColor =
        isDangerZone ? Colors.red.shade300 : AppColors.primaryText;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: titleColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 16),
            child: Text(subtitle,
                style: const TextStyle(color: AppColors.secondaryText)),
          ),
          content,
        ],
      ),
    );
  }
}
