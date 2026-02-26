import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';
import 'package:sincro_app_flutter/common/utils/username_validator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sincro_app_flutter/features/settings/presentation/widgets/settings_section_title.dart';

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
  late TextEditingController _usernameController;
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _selectedGender; // NOVO

  bool _isSavingInfo = false;
  bool _isSavingPassword = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    var cleanFirstName = widget.userData.primeiroNome;
    final lastName = widget.userData.sobrenome;

    if (lastName.isNotEmpty &&
        cleanFirstName.toLowerCase().endsWith(lastName.toLowerCase())) {
      cleanFirstName = cleanFirstName
          .substring(0,
              cleanFirstName.toLowerCase().lastIndexOf(lastName.toLowerCase()))
          .trim();
    }

    _firstNameController = TextEditingController(text: cleanFirstName);
    _lastNameController =
        TextEditingController(text: widget.userData.sobrenome);
    _usernameController =
        TextEditingController(text: widget.userData.username ?? '');
    _selectedGender = widget.userData.gender; // NOVO
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

      if (newUsername.isNotEmpty && newUsername != currentUsername) {
        if (!UsernameValidator.isValidFormat(newUsername)) {
          _showFeedback('Formato de username inválido.', isError: true);
          return;
        }
        final isAvailable =
            await _supabaseService.isUsernameAvailable(newUsername);
        if (!isAvailable) {
          _showFeedback('Este nome de usuário já está em uso.', isError: true);
          return;
        }
      }

      final Map<String, dynamic> updates = {
        'primeiroNome': _firstNameController.text.trim(),
        'sobrenome': _lastNameController.text.trim(),
        'gender': _selectedGender, // NOVO
      };

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

      await _supabase.auth.signInWithPassword(
          email: user.email, password: _currentPasswordController.text);

      await _supabase.auth
          .updateUser(UserAttributes(password: _newPasswordController.text));

      _showFeedback('Senha alterada com sucesso!');
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    } on AuthException catch (e) {
      _showFeedback('Erro ao alterar a senha: ${e.message}', isError: true);
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

      await _supabase.auth
          .signInWithPassword(email: user.email, password: password);

      _showFeedback(
          'Funcionalidade indisponível temporariamente. Contate o suporte.',
          isError: false);
    } on AuthException catch (e) {
      _showFeedback('Senha incorreta ou erro de autenticação: ${e.message}',
          isError: true);
    } catch (e) {
      _showFeedback('Ocorreu um erro inesperado ao processar.', isError: true);
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
            prefixIcon:
                Icon(Icons.lock_outline, color: AppColors.secondaryText),
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
      child: Column(
        children: [
          // 1. Meus Dados Section
          const SettingsSectionTitle(title: 'Meus Dados'),

          Form(
            key: _formKeyInfo,
            child: Column(
              children: [
                TextFormField(
                  controller: _usernameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Nome de Usuário (@username)',
                    hintText: 'Ex: joao.silva',
                    prefixIcon: Icon(Icons.alternate_email,
                        color: AppColors.secondaryText),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return null;
                    return UsernameValidator.validate(value);
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Nome',
                          prefixIcon: Icon(Icons.person_outline,
                              color: AppColors.secondaryText),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Sobrenome',
                          prefixIcon: Icon(Icons.person_outline,
                              color: AppColors.secondaryText),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedGender,
                  decoration: const InputDecoration(
                    labelText: 'Gênero',
                    prefixIcon: Icon(Icons.wc, color: AppColors.secondaryText),
                  ),
                  dropdownColor: AppColors.cardBackground,
                  style: const TextStyle(color: Colors.white),
                  items: ['Masculino', 'Feminino', 'Outro'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) =>
                      setState(() => _selectedGender = newValue),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSavingInfo ? null : _handleSaveChanges,
                    child: _isSavingInfo
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Salvar Alterações'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // 3. Alterar Senha Section
          const SettingsSectionTitle(title: 'Segurança'),

          Form(
            key: _formKeyPassword,
            child: Column(
              children: [
                TextFormField(
                  controller: _currentPasswordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Senha Atual',
                    prefixIcon: Icon(Icons.lock_outline,
                        color: AppColors.secondaryText),
                  ),
                  validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _newPasswordController,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Nova Senha',
                          prefixIcon:
                              Icon(Icons.key, color: AppColors.secondaryText),
                        ),
                        validator: (v) => (v?.length ?? 0) < 6
                            ? 'Mínimo de 6 caracteres'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Confirmar',
                          prefixIcon: Icon(Icons.check_circle_outline,
                              color: AppColors.secondaryText),
                        ),
                        validator: (v) => (v?.length ?? 0) < 6
                            ? 'Mínimo de 6 caracteres'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSavingPassword ? null : _handleChangePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cardBackground,
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                    ),
                    child: _isSavingPassword
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.primary))
                        : const Text('Atualizar Senha'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 48),

          // Danger Zone
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.redAccent.withValues(alpha: 0.8),
              ),
              icon: const Icon(Icons.delete_forever, size: 20),
              onPressed: _isDeleting ? null : _handleDeleteAccount,
              label: _isDeleting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.redAccent))
                  : const Text('Excluir minha conta'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
