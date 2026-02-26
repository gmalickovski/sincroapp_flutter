// lib/features/authentication/presentation/user_details/user_details_screen.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/features/authentication/data/auth_repository.dart'; // NEW
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/models/subscription_model.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';
import 'package:sincro_app_flutter/app/routs/app_router.dart';
import 'package:sincro_app_flutter/common/utils/username_validator.dart'; // NOVO: Validador
import 'dart:async'; // Para Timer

class UserDetailsScreen extends StatefulWidget {
  final User user;
  const UserDetailsScreen({super.key, required this.user});

  @override
  State<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen> {
  int _step = 1; // 1: Boas-vindas, 2: Formulário, 3: Carregando
  final _nomeAnaliseController = TextEditingController();
  final _dataNascController = TextEditingController();
  final _usernameController = TextEditingController(); // NOVO
  final _supabaseService = SupabaseService();
  bool _isLoading = false;

  // Username Logic State
  bool _isAutoUsername = false;
  bool _isCheckingUsername = false;
  bool _isUsernameValid = false;
  String? _usernameError;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _nomeAnaliseController.dispose();
    _dataNascController.dispose();
    _usernameController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // --- USERNAME LOGIC ---

  void _onUsernameChanged(String value) {
    if (_isAutoUsername) return; // Ignore limits if auto

    // Cancel any pending remote check
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // Reset state immediately on any change
    setState(() {
      _isUsernameValid = false;
      _usernameError = null;
      _isCheckingUsername = false; // Stop spinner
    });

    // If empty, just stop here (state is already clean)
    if (value.isEmpty) return;

    // Local Format Validation
    final error = UsernameValidator.validate(value);
    if (error != null) {
      setState(() => _usernameError = error);
      return;
    }

    // If local format is valid, start remote check
    setState(() => _isCheckingUsername = true);

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final isAvailable = await _supabaseService.isUsernameAvailable(value);
        if (mounted) {
          setState(() {
            _isCheckingUsername = false;
            _isUsernameValid = isAvailable;
            _usernameError =
                isAvailable ? null : 'Nome de usuário já está em uso.';
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isCheckingUsername = false;
            // Don't block user on network error, but maybe warn?
            // For now, assume valid if check fails to avoid blocking?
            // Or safer: assume invalid. Let's assume invalid and show generic error.
            _usernameError = 'Erro ao verificar disponibilidade.';
          });
        }
      }
    });
  }

  Future<void> _toggleAutoUsername(bool? value) async {
    setState(() {
      _isAutoUsername = value ?? false;
      if (!_isAutoUsername) {
        _usernameController.clear();
        _isUsernameValid = false;
        _usernameError = null;
      }
    });

    if (_isAutoUsername) {
      await _generateAndSetUsername();
    }
  }

  Future<void> _generateAndSetUsername() async {
    final name = _nomeAnaliseController.text.trim();
    if (name.isEmpty) return; // Wait for name

    setState(() => _isCheckingUsername = true);

    // Simple generation logic: first.last + random?
    // For now, let's try strict first.last, if taken, append suffix
    // But since we need "analysis name" which is full name:
    final parts = name.split(' ');
    String base = parts.first.toLowerCase();
    if (parts.length > 1) {
      base += '.${parts.last.toLowerCase()}';
    }

    // Sanitize
    base = base.replaceAll(RegExp(r'[^a-z0-9.]'), '');

    String candidate = base;
    bool isAvailable = await _supabaseService.isUsernameAvailable(candidate);

    if (!isAvailable) {
      // Try adding random numbers until found
      int attempts = 0;
      while (!isAvailable && attempts < 5) {
        final suffix = DateTime.now().millisecond.toString().padLeft(3, '0');
        candidate = '$base$suffix';
        isAvailable = await _supabaseService.isUsernameAvailable(candidate);
        attempts++;
      }
    }

    if (mounted) {
      setState(() {
        _usernameController.text = candidate;
        _isUsernameValid = isAvailable; // Should be true unless really unlucky
        _isCheckingUsername = false;
        _usernameError = isAvailable
            ? null
            : 'Não foi possível gerar um nome único. Tente outro nome.';
      });
    }
  }

  Future<void> _saveDetails() async {
    if (_nomeAnaliseController.text.isEmpty ||
        _dataNascController.text.isEmpty ||
        _usernameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Por favor, preencha todos os campos.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    if (!_isUsernameValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(_usernameError ?? 'Nome de usuário inválido ou em uso.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    // Validação simples da data (DD/MM/AAAA)
    final dateRegex = RegExp(r'^\d{2}/\d{2}/\d{4}$');
    if (!dateRegex.hasMatch(_dataNascController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Formato de data inválido. Use DD/MM/AAAA.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() {
      _isLoading = true; // Desabilita botão
      _step = 3; // Vai para a tela de "Calculando..."
    });

    try {
      final displayName = widget.user.userMetadata?['full_name'] ?? '';
      final gender = widget.user.userMetadata?['gender']; // NOVO

      // Lógica de Fallback: Se o displayName vier vazio (erro no cadastro),
      // usamos o nome de nascimento inserido pelo usuário.
      final nameSource = displayName.toString().isNotEmpty
          ? displayName.toString()
          : _nomeAnaliseController.text.trim();

      final nameParts = nameSource.split(' ');
      final primeiroNome = nameParts.isNotEmpty ? nameParts.first : '';
      final sobrenome =
          nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

      final newUser = UserModel(
        uid: widget.user.id,
        email: widget.user.email ?? '',
        photoUrl: null,
        username: _usernameController.text.trim(), // Salva o username
        primeiroNome: primeiroNome,
        sobrenome: sobrenome,
        nomeAnalise: _nomeAnaliseController.text.trim(),
        dataNasc: _dataNascController.text.trim(),
        gender: gender, // NOVO
        plano: 'essencial',
        isAdmin: false,
        dashboardCardOrder: UserModel.defaultCardOrder,
        subscription: SubscriptionModel.free(), // Plano gratuito padrão
      );

      await _supabaseService.saveUserData(newUser);

      // NOVO: Enviar Webhook ao N8N após salvar dados de análise
      await AuthRepository().sendSignupWebhook(
        email: newUser.email,
        userId: newUser.uid,
        displayName: '${newUser.primeiroNome} ${newUser.sobrenome}'.trim(),
      );

      // Navegação direta para o Dashboard após salvar com sucesso.
      // Mantemos o AuthCheck como plano B, mas forçamos a navegação
      // para evitar ficar preso no estado de carregamento em algumas plataformas (web).
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.dashboard,
          (route) => false,
        );
      }
    } catch (e) {
      // Se der erro, volta ao formulário e mostra mensagem
      if (mounted) {
        setState(() {
          _isLoading = false; // Reabilita botão
          _step = 2;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao salvar: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
    }
  } // Fim de _saveDetails

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: isMobile ? EdgeInsets.zero : const EdgeInsets.all(16.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isMobile ? size.width : 700, // Widened for desktop
              minHeight: isMobile ? size.height : 0,
            ),
            child: Container(
              padding:
                  EdgeInsets.all(isMobile ? 24.0 : 48.0), // More breathing room
              decoration: isMobile
                  ? null // Native fullscreen on mobile
                  : BoxDecoration(
                      color: AppColors.cardBackground.withValues(alpha: 0.5),
                      borderRadius:
                          BorderRadius.circular(24.0), // Softer corners
                      border: Border.all(
                          color: AppColors.border.withValues(alpha: 0.5)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                switchInCurve: Curves.easeOutQuart,
                switchOutCurve: Curves.easeInQuart,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  // Sutil slide + fade sync
                  final offsetAnimation = Tween<Offset>(
                    begin: const Offset(0.05, 0.0), // Subtle slide from right
                    end: Offset.zero,
                  ).animate(animation);

                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: offsetAnimation,
                      child: child,
                    ),
                  );
                },
                child: _buildStepContent(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 1: // Tela de Boas-vindas e Username
        return Column(
          key: const ValueKey('step1'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Passo 1 de 2',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.tertiaryText,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 8),
            const Text('Bem-vindo(a) ao SincroApp! ✨',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 24, // Maior (Mario?)
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondaryAccent)),
            const SizedBox(height: 12),
            const Text(
              'Sua jornada de autoconhecimento começa agora. 🌌\nVamos criar sua identidade única no Sincro. 🆔',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.secondaryText,
                  height: 1.5),
            ),
            const SizedBox(height: 32),

            // --- USERNAME FIELD (Moved to Step 1) ---
            TextField(
              controller: _usernameController,
              enabled: !_isAutoUsername,
              style: const TextStyle(color: Colors.white),
              onChanged: _onUsernameChanged,
              decoration: _buildInputDecoration(
                      "Nome de Usuário (@username)", Icons.alternate_email)
                  .copyWith(
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide(
                    color: _isUsernameValid
                        ? Colors.green.shade400
                        : (_usernameError != null
                            ? Colors.red.shade400
                            : AppColors.border),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide(
                    color: _isUsernameValid
                        ? Colors.green.shade400
                        : (_usernameError != null
                            ? Colors.red.shade400
                            : AppColors.primaryAccent),
                  ),
                ),
                suffixIcon: _isCheckingUsername
                    ? Transform.scale(
                        scale: 0.5, child: const CircularProgressIndicator())
                    : (_isUsernameValid
                        ? Icon(Icons.check_circle, color: Colors.green.shade400)
                        : null),
                errorText: _usernameError,
              ),
            ),

            // Username Instructions
            if (!_isAutoUsername) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "O nome de usuário deve ser único, sem espaços ou acentos.",
                      style: TextStyle(
                          color: AppColors.secondaryText, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                            color: AppColors.tertiaryText, fontSize: 12),
                        children: [
                          const TextSpan(text: "Exemplos: "),
                          TextSpan(
                              text: "joaopedro",
                              style: TextStyle(color: Colors.green.shade400)),
                          const TextSpan(text: " ("),
                          TextSpan(
                              text: "não",
                              style: TextStyle(color: Colors.red.shade400)),
                          const TextSpan(text: ": joão pedro), "),
                          TextSpan(
                              text: "joao_pedro",
                              style: TextStyle(color: Colors.green.shade400)),
                          const TextSpan(text: ", "),
                          TextSpan(
                              text: "JoaoPedro",
                              style: TextStyle(color: Colors.green.shade400)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // "Let system create" Toggle
            Row(
              children: [
                Checkbox(
                  value: _isAutoUsername,
                  activeColor: AppColors.primary,
                  onChanged: _toggleAutoUsername,
                  side:
                      const BorderSide(color: AppColors.tertiaryText, width: 2),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _toggleAutoUsername(!_isAutoUsername),
                    child: const Text("Criar automaticamente para mim 🎲",
                        style: TextStyle(
                            color: AppColors.secondaryText, fontSize: 13)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isUsernameValid || _isAutoUsername)
                    ? () => setState(() => _step = 2)
                    : null,
                child: const Text('Continuar'),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () async {
                // Cancel registration -> Sign out
                await Supabase.instance.client.auth.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed(AppRoutes.login);
                }
              },
              child: const Text("Cancelar",
                  style: TextStyle(color: AppColors.tertiaryText)),
            ),
          ],
        );

      case 2: // Formulário (Dados de Análise)
        return Column(
          key: const ValueKey('step2'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Passo 2 de 2',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.tertiaryText,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 8),
            const Text('Só mais um passo! 🚀',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 24, // Maior
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondaryAccent)),
            const SizedBox(height: 12),
            const Text(
                'Para personalizar sua jornada, precisamos do seu nome completo de nascimento. 📜',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.tertiaryText,
                    height: 1.5)),
            const SizedBox(height: 32),
            TextField(
              controller: _nomeAnaliseController,
              style: const TextStyle(color: Colors.white),
              decoration: _buildInputDecoration(
                  "Seu nome completo de nascimento", Icons.person_outline),
              textCapitalization: TextCapitalization.words,
              onChanged: (_) {
                setState(() {});
                if (_isAutoUsername) _generateAndSetUsername();
              },
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8.0, left: 4.0),
              child: Text("Exatamente como está na sua certidão. ✍️",
                  style:
                      TextStyle(color: AppColors.tertiaryText, fontSize: 12)),
            ),
            const SizedBox(height: 16),
            TextField(
                controller: _dataNascController,
                style: const TextStyle(color: Colors.white),
                decoration: _buildInputDecoration(
                    "Data de Nascimento", Icons.calendar_today_outlined,
                    hint: "DD/MM/AAAA"),
                keyboardType: TextInputType.datetime,
                onChanged: (_) => setState(() {})),
            const Padding(
              padding: EdgeInsets.only(top: 8.0, left: 4.0),
              child: Text("Use o formato dia/mês/ano. 📅",
                  style:
                      TextStyle(color: AppColors.tertiaryText, fontSize: 12)),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                OutlinedButton(
                    onPressed:
                        _isLoading ? null : () => setState(() => _step = 1),
                    style: OutlinedButton.styleFrom(
                        shape: const StadiumBorder(),
                        side: const BorderSide(color: AppColors.primary),
                        foregroundColor: AppColors.primary),
                    child: const Text('Voltar')),
                const SizedBox(width: 16),
                Expanded(
                    child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: const StadiumBorder(),
                        ),
                        // Username validation happens at Step 1 now, check logic here just in case?
                        // Actually, _isUsernameValid should still be true from Step 1.
                        onPressed: _isLoading ||
                                _nomeAnaliseController.text.isEmpty ||
                                _dataNascController.text.isEmpty
                            ? null
                            : _saveDetails,
                        child: const Text('Iniciar Jornada'))),
              ],
            ),
          ],
        );

      case 3: // Tela de Carregamento
      default:
        return const Column(
          key: ValueKey('step3'),
          children: [
            CustomLoadingSpinner(),
          ],
        );
    }
  }

  InputDecoration _buildInputDecoration(String label, IconData icon,
      {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: AppColors.secondaryText),
      hintStyle: const TextStyle(color: AppColors.tertiaryText),
      prefixIcon: Icon(icon, color: AppColors.secondaryText),
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: AppColors.primaryAccent)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: Colors.red.shade400)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: Colors.red.shade700)),
    );
  }
}
