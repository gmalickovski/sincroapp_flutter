import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_button.dart';
import 'package:sincro_app_flutter/features/authentication/data/auth_repository.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _authRepository = AuthRepository();

  bool _isSending = false;
  String? _errorMessage;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Informe seu email';
    final emailRegex = RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$");
    if (!emailRegex.hasMatch(v)) return 'Email inválido';
    return null;
  }

  Future<void> _sendReset() async {
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;
    setState(() {
      _isSending = true;
      _errorMessage = null;
    });
    try {
      await _authRepository.sendPasswordResetEmail(
          email: _emailController.text);
      if (!mounted) return;
      setState(() {
        _emailSent = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text('Se o email existir, enviaremos um link para redefinição.'),
        backgroundColor: Colors.green,
      ));
    } on FirebaseAuthException catch (e) {
      String msg = 'Não foi possível enviar o email. Tente novamente.';
      if (e.code == 'invalid-email') {
        msg = 'O email informado é inválido.';
      } else if (e.code == 'user-not-found') {
        // Por segurança, mesma mensagem genérica
        msg = 'Se o email existir, enviaremos um link para redefinição.';
      } else if (e.code == 'missing-android-pkg-name' ||
          e.code == 'missing-continue-uri' ||
          e.code == 'invalid-continue-uri' ||
          e.code == 'unauthorized-continue-uri') {
        msg =
            'Configuração do link de redefinição inválida. Contate o suporte.';
      }
      if (!mounted) return;
      setState(() {
        _errorMessage = msg;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Erro inesperado. Tente novamente.';
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Erro inesperado. Tente novamente.'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.secondaryText,
        elevation: 0,
        title: const Text('Recuperar senha'),
      ),
      backgroundColor: AppColors.background,
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
                  height: 72,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Informe seu email para receber o link de redefinição de senha.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.secondaryText),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(
                        color: AppColors.border.withValues(alpha: 0.5)),
                  ),
                  child: Form(
                    key: _formKey,
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
                        TextFormField(
                          controller: _emailController,
                          validator: _validateEmail,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.background,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                              borderSide:
                                  const BorderSide(color: AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                              borderSide:
                                  const BorderSide(color: AppColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                              borderSide: const BorderSide(
                                  color: AppColors.primaryAccent),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        ElevatedButton(
                          onPressed: _isSending ? null : _sendReset,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14.0),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0)),
                            backgroundColor: AppColors.primaryAccent,
                            disabledBackgroundColor: Colors.grey.shade600,
                          ),
                          child: _isSending
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text(
                                  'Enviar link',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                        ),
                        const SizedBox(height: 12),
                        if (_emailSent)
                          const Text(
                            'Se o email existir, você receberá um link de redefinição. Confira também a pasta de spam.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.tertiaryText),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                CustomTextButton(
                  text: 'Voltar ao login',
                  icon: Icons.arrow_back,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
