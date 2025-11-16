import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_button.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/features/authentication/data/auth_repository.dart';
import 'package:sincro_app_flutter/features/authentication/presentation/user_details/user_details_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authRepository = AuthRepository();
  String? _errorMessage;
  bool _isLoading = false;
  bool _showPassword = false;
  bool _agreedToTerms = false;

  Future<void> _signUp() async {
    if (!_agreedToTerms) {
      setState(() => _errorMessage =
          'Você deve aceitar os termos e políticas para continuar.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final displayName =
          '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';
      await _authRepository.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
        displayName: displayName,
      );

      final newUser = FirebaseAuth.instance.currentUser;
      if (mounted && newUser != null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
              builder: (context) => UserDetailsScreen(firebaseUser: newUser)),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          if (e.code == 'weak-password') {
            _errorMessage = 'A senha é muito fraca (mínimo 6 caracteres).';
          } else if (e.code == 'email-already-in-use') {
            _errorMessage = 'Este email já está a ser utilizado.';
          } else if (e.code == 'invalid-email') {
            _errorMessage = 'O email fornecido é inválido.';
          } else {
            _errorMessage = 'Ocorreu um erro. Tente novamente.';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Ocorreu um erro. Tente novamente.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Lado esquerdo - Logo e texto
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      'assets/images/sincroapp_logo_2.svg',
                      height: 96,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Descubra o propósito oculto\nnos números da sua vida',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: AppColors.secondaryText,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),
                    const Text(
                      'Crie sua Conta',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Comece sua jornada de autoconhecimento.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: AppColors.tertiaryText,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            // Lado direito - Formulário
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 48.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      children: [
                        _buildForm(),
                        const SizedBox(height: 24),
                        CustomTextButton(
                          text: 'Já tenho uma conta',
                          onPressed: () => Navigator.of(context).pop(),
                          color: AppColors.tertiaryText,
                          icon: Icons.arrow_back,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 384),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'assets/images/sincroapp_logo.svg',
                height: 48,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 20),
              const Text(
                'Crie sua Conta',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Comece sua jornada de autoconhecimento.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: AppColors.tertiaryText,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              _buildForm(),
              const SizedBox(height: 24),
              CustomTextButton(
                text: 'Já tenho uma conta',
                onPressed: () => Navigator.of(context).pop(),
                color: AppColors.tertiaryText,
                icon: Icons.arrow_back,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTextField(_firstNameController, 'Nome'),
          const SizedBox(height: 16),
          _buildTextField(_lastNameController, 'Sobrenome'),
          const SizedBox(height: 16),
          _buildTextField(_emailController, 'Email',
              keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 16),
          _buildTextField(_passwordController, 'Senha', isPassword: true),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 24.0,
                width: 24.0,
                child: Checkbox(
                  value: _agreedToTerms,
                  onChanged: (value) =>
                      setState(() => _agreedToTerms = value ?? false),
                  side: const BorderSide(color: AppColors.border),
                  activeColor: AppColors.primaryAccent,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text.rich(
                  TextSpan(
                    text: 'Eu li e concordo com os ',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.tertiaryText),
                    children: [
                      TextSpan(
                          text: 'Termos de Serviço',
                          style:
                              TextStyle(decoration: TextDecoration.underline)),
                      TextSpan(text: ' e a '),
                      TextSpan(
                          text: 'Política de Privacidade',
                          style:
                              TextStyle(decoration: TextDecoration.underline)),
                      TextSpan(text: '.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Text(_errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent)),
            ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _signUp,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0)),
            ),
            child: _isLoading
                ? const CustomLoadingSpinner()
                : const Text('Criar Conta',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {bool isPassword = false, TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword && !_showPassword,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.background,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: const BorderSide(color: AppColors.primaryAccent)),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                        _showPassword ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.tertiaryText),
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
