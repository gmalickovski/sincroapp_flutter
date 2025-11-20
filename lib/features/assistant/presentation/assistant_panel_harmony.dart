  String _ensureTimeInTitle(String title, TimeOfDay? time) {
    if (time == null) return title;
    if (title.contains(':') || title.toLowerCase().contains('h')) return title;
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$title – $hh:$mm';
  }

  String _buildHarmonyAnalysis(
    int userMissao,
    int partnerMissao,
    Map<String, dynamic> userHarmony,
    Map<String, dynamic> partnerHarmony,
    String partnerName,
  ) {
    final vibra = userHarmony['vibra'] as List? ?? [];
    final atrai = userHarmony['atrai'] as List? ?? [];
    final oposto = userHarmony['oposto'] as List? ?? [];
    final passivo = userHarmony['passivo'] as List? ?? [];

    String compatibilityLevel;
    String emoji;
    String explanation;

    if (vibra.contains(partnerMissao)) {
      compatibilityLevel = "Vibração Perfeita";
      emoji = "💖";
      explanation = "Vocês possuem uma **vibração perfeita**! Há uma sintonia natural e profunda entre vocês.";
    } else if (atrai.contains(partnerMissao)) {
      compatibilityLevel = "Alta Atração";
      emoji = "✨";
      explanation = "Existe uma **forte atração** entre vocês. A relação tende a ser harmoniosa e complementar.";
    } else if (oposto.contains(partnerMissao)) {
      compatibilityLevel = "Energias Opostas";
      emoji = "⚡";
      explanation = "Vocês possuem **energias opostas**. Isso pode gerar desafios, mas também crescimento mútuo se houver compreensão.";
    } else if (passivo.contains(partnerMissao)) {
      compatibilityLevel = "Relação Passiva";
      emoji = "🌙";
      explanation = "A relação tende a ser **passiva e tranquila**. Pode faltar intensidade, mas há estabilidade.";
    } else {
      compatibilityLevel = "Neutro";
      emoji = "🔄";
      explanation = "A relação é **neutra** do ponto de vista numerológico. O sucesso dependerá de outros fatores.";
    }

    return '''
## $emoji Análise de Harmonia Conjugal

**Sua Missão**: $userMissao  
**Missão de $partnerName**: $partnerMissao  

**Compatibilidade**: $compatibilityLevel

$explanation

### Detalhes da sua Harmonia Conjugal:
- **Vibra com**: ${vibra.join(', ')}
- **Atrai**: ${atrai.join(', ')}
- **Oposto**: ${oposto.join(', ')}
- **Passivo**: ${passivo.join(', ')}

Lembre-se: a numerologia é uma ferramenta de autoconhecimento. O sucesso de qualquer relacionamento depende de amor, respeito, comunicação e esforço mútuo! 💕
''';
  }
}
