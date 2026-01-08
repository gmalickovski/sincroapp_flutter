import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_button.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/features/authentication/data/auth_repository.dart';
import 'package:sincro_app_flutter/features/authentication/presentation/register/register_screen.dart';
import 'package:sincro_app_flutter/features/authentication/presentation/forgot_password/forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthRepository _authRepository = AuthRepository();
  String? _errorMessage;
  bool _isLoading = false;
  bool _isForgotPasswordHovered = false;

  Future<void> _signIn() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // debugPrint('[LoginScreen] Tentando login para ${_emailController.text.trim()}');
      await _authRepository.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } on AuthException catch (e) {
      // debugPrint('[LoginScreen] AuthException: ${e.message}');
      if (e.message.contains('Invalid login credentials')) {
        _errorMessage = 'Email ou senha inválidos.';
      } else {
        _errorMessage = e.message;
      }
    } catch (e) {
      _errorMessage = 'Ocorreu um erro. Tente novamente.';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 384),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  'assets/images/sincroapp_logo_2.svg',
                  height: 96,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(32.0),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(
                        color: AppColors.border.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _emailController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Email',
                          labelStyle: const TextStyle(color: AppColors.secondaryText),
                          prefixIcon: const Icon(Icons.email_outlined, color: AppColors.secondaryText),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.primary),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _passwordController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Senha',
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
                        obscureText: true,
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: MouseRegion(
                          onEnter: (_) => setState(() => _isForgotPasswordHovered = true),
                          onExit: (_) => setState(() => _isForgotPasswordHovered = false),
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ForgotPasswordScreen(),
                                ),
                              );
                            },
                            child: Text(
                              'Esqueci minha senha',
                              style: TextStyle(
                                color: AppColors.secondaryAccent,
                                fontSize: 12,
                                decoration: _isForgotPasswordHovered 
                                    ? TextDecoration.underline 
                                    : TextDecoration.none,
                                decorationColor: AppColors.secondaryAccent,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Text(_errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.redAccent)),
                        ),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _signIn,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          backgroundColor: AppColors.primaryAccent,
                          disabledBackgroundColor: Colors.grey.shade600,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CustomLoadingSpinner(size: 24))
                            : const Text('Entrar',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 24.0),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Não tem conta?',
                              style: TextStyle(color: AppColors.tertiaryText)),
                          const SizedBox(width: 4),
                          CustomTextButton(
                            text: 'Cadastre-se',
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const RegisterScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                CustomTextButton(
                  text: 'Voltar',
                  onPressed: () {}, // TODO: Implement back functionality? Or remove if not needed.
                  color: AppColors.tertiaryText,
                  icon: Icons.arrow_back,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
