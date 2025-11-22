// lib/features/authentication/presentation/user_details/user_details_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/models/subscription_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';
import 'package:sincro_app_flutter/app/routs/app_router.dart';

class UserDetailsScreen extends StatefulWidget {
  final User firebaseUser;
  const UserDetailsScreen({super.key, required this.firebaseUser});

  @override
  State<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen> {
  int _step = 1; // 1: Boas-vindas, 2: Formulário, 3: Carregando
  final _nomeAnaliseController = TextEditingController();
  final _dataNascController = TextEditingController();
  final _firestoreService = FirestoreService();
  bool _isLoading = false; // Usado para desabilitar botão durante o save

  @override
  void initState() {
    super.initState();
    // Deixa o campo em branco - nome de nascimento pode ser diferente do cadastro
  }

  Future<void> _saveDetails() async {
    if (_nomeAnaliseController.text.isEmpty ||
        _dataNascController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Por favor, preencha todos os campos.'),
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
      final displayName = widget.firebaseUser.displayName?.trim() ?? '';
      
      // Lógica de Fallback: Se o displayName vier vazio (erro no cadastro),
      // usamos o nome de nascimento inserido pelo usuário.
      final nameSource = displayName.isNotEmpty 
          ? displayName 
          : _nomeAnaliseController.text.trim();

      final nameParts = nameSource.split(' ');
      final primeiroNome = nameParts.isNotEmpty ? nameParts.first : '';
      final sobrenome =
          nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

      final newUser = UserModel(
        uid: widget.firebaseUser.uid,
        email: widget.firebaseUser.email ?? '',
        photoUrl: widget.firebaseUser.photoURL,
        primeiroNome: primeiroNome,
        sobrenome: sobrenome,
        nomeAnalise: _nomeAnaliseController.text.trim(),
        dataNasc: _dataNascController.text.trim(),
        plano: 'gratuito',
        isAdmin: false,
        dashboardCardOrder: UserModel.defaultCardOrder,
        subscription: SubscriptionModel.free(), // Plano gratuito padrão
      );

      await _firestoreService.saveUserData(newUser);
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
    // Não precisamos mais do setState(() => _isLoading = false) aqui,
    // pois ou a navegação ocorre via AuthCheck ou o erro já tratou o estado.
  }

  @override
  void dispose() {
    _nomeAnaliseController.dispose();
    _dataNascController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Definimos a cor de fundo aqui para cobrir a tela inteira
    return Scaffold(
      backgroundColor: AppColors.background, // Cor de fundo da tela
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              padding: const EdgeInsets.all(32.0),
              decoration: BoxDecoration(
                color: AppColors.cardBackground.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
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
      case 1: // Tela de Boas-vindas
        return Column(
          key: const ValueKey('step1'),
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
            const Text('Bem-vindo(a) ao SincroApp!',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondaryAccent)),
            const SizedBox(height: 12),
            const Text(
              'Sua jornada de autoconhecimento começa agora.\nPara calcularmos sua rota numerológica pessoal, precisamos de apenas duas informações.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: AppColors.secondaryText,
                  height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => setState(() => _step = 2),
                child: const Text('Começar'),
              ),
            ),
          ],
        );

      case 2: // Formulário
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
            const Text('Só mais um passo!',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondaryAccent)),
            const SizedBox(height: 12),
            const Text(
                'Para personalizar sua jornada, precisamos do seu nome completo de nascimento.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: AppColors.tertiaryText,
                    height: 1.5)),
            const SizedBox(height: 24),
            const Text('Seu nome completo de nascimento',
                style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextField(
                controller: _nomeAnaliseController,
                decoration: _buildInputDecoration("Ex: Maria da Silva"),
                textCapitalization:
                    TextCapitalization.words, // Capitaliza nomes
                onChanged: (_) => setState(() {}) // Para reavaliar o botão
                ),
            const Text("Exatamente como está na sua certidão.",
                style: TextStyle(color: AppColors.tertiaryText, fontSize: 12)),
            const SizedBox(height: 16),
            const Text('Data de Nascimento',
                style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextField(
                controller: _dataNascController,
                decoration: _buildInputDecoration("DD/MM/AAAA"),
                keyboardType: TextInputType.datetime,
                onChanged: (_) => setState(() {}) // Para reavaliar o botão
                ),
            const Text("Use o formato dia/mês/ano.",
                style: TextStyle(color: AppColors.tertiaryText, fontSize: 12)),
            const SizedBox(height: 24),
            Row(
              children: [
                OutlinedButton(
                    // Desabilita se estiver carregando
                    onPressed:
                        _isLoading ? null : () => setState(() => _step = 1),
                    child: const Text('Voltar')),
                const SizedBox(width: 16),
                Expanded(
                    child: ElevatedButton(
                        // Desabilita se estiver carregando ou se campos vazios
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

  InputDecoration _buildInputDecoration(String placeholder) {
    return InputDecoration(
      hintText: placeholder,
      hintStyle: const TextStyle(color: AppColors.tertiaryText),
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: AppColors.primaryAccent)),
      // Adiciona borda de erro
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: Colors.red.shade400)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: Colors.red.shade700)),
    );
  }
}
