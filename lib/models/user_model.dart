import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String primeiroNome;
  final String sobrenome;
  final String nomeAnalise;
  final String dataNasc;
  final String plano;
  final bool isAdmin;

  UserModel({
    required this.uid,
    required this.email,
    required this.primeiroNome,
    required this.sobrenome,
    required this.nomeAnalise,
    required this.dataNasc,
    required this.plano,
    required this.isAdmin,
  });

  factory UserModel.fromFirestore(DocumentSnapshot<Object?> doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      primeiroNome: data['primeiroNome'] ?? '',
      sobrenome: data['sobrenome'] ?? '',
      nomeAnalise: data['nomeAnalise'] ?? '',
      dataNasc: data['dataNasc'] ?? '',
      plano: data['plano'] ?? 'gratuito',
      isAdmin: data['isAdmin'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'primeiroNome': primeiroNome,
      'sobrenome': sobrenome,
      'nomeAnalise': nomeAnalise,
      'dataNasc': dataNasc,
      'plano': plano,
      'isAdmin': isAdmin,
    };
  }
}
