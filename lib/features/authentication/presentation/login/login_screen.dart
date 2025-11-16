import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_button.dart';
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

  Future<void> _signIn() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authRepository.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        _errorMessage = 'Email ou senha inválidos.';
      } else if (e.code == 'invalid-email') {
        _errorMessage = 'O formato do email é inválido.';
      } else {
        _errorMessage = 'Ocorreu um erro. Tente novamente.';
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
                const SizedBox(height: 24),
                const Text(
                  'Bem-vindo(a) de volta!',
                  style: TextStyle(
                    fontSize: 20,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(32.0),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16.0),
                    border:
                        Border.all(color: AppColors.border.withOpacity(0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Email',
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _emailController,
                        decoration: _buildInputDecoration(),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Senha',
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _passwordController,
                        decoration: _buildInputDecoration(),
                        obscureText: true,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: CustomTextButton(
                          text: 'Esqueci minha senha',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ForgotPasswordScreen(),
                              ),
                            );
                          },
                          color: AppColors.secondaryAccent,
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
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0)),
                          backgroundColor: AppColors.primaryAccent,
                          disabledBackgroundColor: Colors.grey.shade600,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
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
                  onPressed: () {},
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

  InputDecoration _buildInputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: const BorderSide(color: AppColors.primaryAccent),
      ),
    );
  }
}
