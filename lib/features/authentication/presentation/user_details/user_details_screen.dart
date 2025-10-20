// lib/features/authentication/presentation/user_details/user_details_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/models/user_model.dart'; // Import necessário
import 'package:sincro_app_flutter/services/firestore_service.dart';

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
    _nomeAnaliseController.text = widget.firebaseUser.displayName ?? '';
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
    if (!_dataNascController.text.contains(dateRegex)) {
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
      final displayName = widget.firebaseUser.displayName ?? '';
      final nameParts = displayName.split(' ');
      final primeiroNome = nameParts.isNotEmpty ? nameParts.first : '';
      final sobrenome =
          nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

      // ================== INÍCIO DA CORREÇÃO ==================
      final newUser = UserModel(
        uid: widget.firebaseUser.uid,
        email: widget.firebaseUser.email ?? '',
        photoUrl: widget.firebaseUser.photoURL, // Adicionado photoUrl
        primeiroNome: primeiroNome,
        sobrenome: sobrenome,
        nomeAnalise: _nomeAnaliseController.text.trim(), // Adicionado trim()
        dataNasc: _dataNascController.text.trim(), // Adicionado trim()
        plano: 'gratuito', // Por defeito
        isAdmin: false,
        dashboardCardOrder:
            UserModel.defaultCardOrder, // Adicionada ordem padrão
      );
      // ================== FIM DA CORREÇÃO ==================

      await _firestoreService.saveUserData(newUser);
      // O AuthCheck em main.dart irá detectar a mudança nos dados do usuário
      // (especificamente nomeAnalise não vazio) e navegar para o Dashboard.
      // Não precisamos navegar manualmente aqui.

      // Se chegarmos aqui, o save foi bem-sucedido. O AuthCheck fará o resto.
      // A tela de loading (_step = 3) continuará visível até o AuthCheck reconstruir.
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
                color: AppColors.cardBackground.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(color: AppColors.border.withOpacity(0.5)),
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
            const Text('Bem-vindo(a) ao SincroApp!',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondaryAccent)),
            const SizedBox(height: 16),
            const Text(
              'Sua jornada de autoconhecimento começa agora.\nPara calcularmos sua rota numerológica pessoal, precisamos de apenas duas informações.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondaryText, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => setState(() => _step = 2),
              child: const Text('Começar'),
            ),
          ],
        );

      case 2: // Formulário
        return Column(
          key: const ValueKey('step2'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Só mais um passo!',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondaryAccent)),
            const SizedBox(height: 8),
            const Text(
                'Para personalizar sua jornada, precisamos do seu nome completo de nascimento.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.tertiaryText)),
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
        return Column(
          key: const ValueKey('step3'),
          children: [
            const CustomLoadingSpinner(),
            const SizedBox(height: 24),
            const Text('Calculando sua rota...',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondaryAccent)),
            const SizedBox(height: 8),
            Text('Estamos alinhando os números para você.',
                style: TextStyle(color: AppColors.tertiaryText)),
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
