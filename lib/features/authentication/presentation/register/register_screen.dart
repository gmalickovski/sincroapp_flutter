import 'package:supabase_flutter/supabase_flutter.dart';
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
  String? _selectedGender; // NOVO

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
      final response = await _authRepository.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
        displayName: displayName,
        gender: _selectedGender, // NOVO
      );

      final freshUser = response.user;

      if (mounted && freshUser != null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
              builder: (context) => UserDetailsScreen(user: freshUser)),
          (route) => false,
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          if (e.message.contains('Password should be at least')) {
            _errorMessage = 'A senha é muito fraca (mínimo 6 caracteres).';
          } else if (e.code == 'user_already_exists') {
            _errorMessage = 'Este email já está a ser utilizado.';
          } else {
            _errorMessage = e.message;
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
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/icon-logo-v1.png',
                  height: 54,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Crie sua Conta',
                  style: TextStyle(
                    fontSize: 28,
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
          TextField(
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
          TextField(
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
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedGender,
            decoration: InputDecoration(
              labelText: 'Gênero (Opcional)',
              labelStyle: const TextStyle(color: AppColors.secondaryText),
              prefixIcon: const Icon(Icons.wc, color: AppColors.secondaryText),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
            dropdownColor: AppColors.cardBackground, 
            style: const TextStyle(color: Colors.white),
            items: ['Masculino', 'Feminino', 'Outro'].map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (newValue) {
              setState(() {
                _selectedGender = newValue;
              });
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
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
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: !_showPassword,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Senha',
              labelStyle: const TextStyle(color: AppColors.secondaryText),
              prefixIcon: const Icon(Icons.lock_outline, color: AppColors.secondaryText),
              suffixIcon: IconButton(
                icon: Icon(
                    _showPassword ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.tertiaryText),
                onPressed: () =>
                    setState(() => _showPassword = !_showPassword),
              ),
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
            ),
            child: _isLoading
                ? const CustomLoadingSpinner(size: 24)
                : const Text('Criar Conta',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Helper method removed (inlined)
}
