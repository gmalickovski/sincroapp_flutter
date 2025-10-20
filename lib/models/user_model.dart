// lib/models/user_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String? photoUrl;
  final String primeiroNome;
  final String sobrenome;
  final String nomeAnalise;
  final String dataNasc;
  final String plano;
  final bool isAdmin;
  final List<String> dashboardCardOrder; // *** NOVO CAMPO ADICIONADO ***

  UserModel({
    required this.uid,
    required this.email,
    this.photoUrl,
    required this.primeiroNome,
    required this.sobrenome,
    required this.nomeAnalise,
    required this.dataNasc,
    required this.plano,
    required this.isAdmin,
    required this.dashboardCardOrder, // *** NOVO CAMPO ADICIONADO ***
  });

  // Lista de ordem padrão para novos usuários ou usuários existentes
  static List<String> get defaultCardOrder => [
        'goalsProgress',
        'focusDay',
        'vibracaoDia',
        'bussola',
        'vibracaoMes',
        'vibracaoAno',
        'arcanoRegente',
        'arcanoVigente',
        'cicloVida',
      ];

  factory UserModel.fromFirestore(DocumentSnapshot<Object?> doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // *** LÓGICA ADICIONADA PARA O NOVO CAMPO ***
    // Tenta ler a ordem do Firestore, se não existir, usa a ordem padrão.
    final List<dynamic> rawOrder =
        data['dashboardCardOrder'] ?? defaultCardOrder;
    final List<String> cardOrder = rawOrder.cast<String>();

    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      photoUrl: data['photoUrl'],
      primeiroNome: data['primeiroNome'] ?? '',
      sobrenome: data['sobrenome'] ?? '',
      nomeAnalise: data['nomeAnalise'] ?? '',
      dataNasc: data['dataNasc'] ?? '',
      plano: data['plano'] ?? 'gratuito',
      isAdmin: data['isAdmin'] ?? false,
      dashboardCardOrder: cardOrder, // *** NOVO CAMPO ADICIONADO ***
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'photoUrl': photoUrl,
      'primeiroNome': primeiroNome,
      'sobrenome': sobrenome,
      'nomeAnalise': nomeAnalise,
      'dataNasc': dataNasc,
      'plano': plano,
      'isAdmin': isAdmin,
      'dashboardCardOrder': dashboardCardOrder, // *** NOVO CAMPO ADICIONADO ***
    };
  }

  // *** MÉTODO 'copyWith' ADICIONADO (BOA PRÁTICA) ***
  // Permite criar cópias do usuário modificando apenas alguns campos
  UserModel copyWith({
    String? uid,
    String? email,
    String? photoUrl,
    String? primeiroNome,
    String? sobrenome,
    String? nomeAnalise,
    String? dataNasc,
    String? plano,
    bool? isAdmin,
    List<String>? dashboardCardOrder,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      primeiroNome: primeiroNome ?? this.primeiroNome,
      sobrenome: sobrenome ?? this.sobrenome,
      nomeAnalise: nomeAnalise ?? this.nomeAnalise,
      dataNasc: dataNasc ?? this.dataNasc,
      plano: plano ?? this.plano,
      isAdmin: isAdmin ?? this.isAdmin,
      dashboardCardOrder: dashboardCardOrder ?? this.dashboardCardOrder,
    );
  }
}
