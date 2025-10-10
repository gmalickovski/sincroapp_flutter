class UserModel {
  final String uid;
  final String email;
  final String? primeiroNome;
  final String? sobrenome;
  final String nomeAnalise;
  final String dataNasc;
  final String plano;
  final bool isAdmin;

  UserModel({
    required this.uid,
    required this.email,
    this.primeiroNome,
    this.sobrenome,
    required this.nomeAnalise,
    required this.dataNasc,
    this.plano = 'gratuito',
    this.isAdmin = false,
  });

  // Converte um documento do Firestore num objeto UserModel
  factory UserModel.fromFirestore(
      Map<String, dynamic> data, String documentId) {
    return UserModel(
      uid: documentId,
      email: data['email'] ?? '',
      primeiroNome: data['primeiroNome'],
      sobrenome: data['sobrenome'],
      nomeAnalise: data['nomeAnalise'] ?? '',
      dataNasc: data['dataNasc'] ?? '',
      plano: data['plano'] ?? 'gratuito',
      isAdmin: data['isAdmin'] ?? false,
    );
  }

  // Converte um objeto UserModel num mapa para ser salvo no Firestore
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
