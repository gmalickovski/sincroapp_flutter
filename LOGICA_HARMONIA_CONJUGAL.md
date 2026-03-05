# Lógica de Cálculo: Harmonia Conjugal & Sinastria Amorosa

Este documento descreve detalhadamente a lógica utilizada no sistema SincroApp para calcular a **Harmonia Conjugal** (Compatibilidade/Sinastria Amorosa) entre duas pessoas. O objetivo é fornecer as regras de negócio e tabelas de forma clara para que este cálculo possa ser replicado em qualquer outra plataforma ou sistema.

---

## 1. Conceitos Básicos

O cálculo da Sinastria baseia-se em dois números fundamentais da Numerologia Cabalística de cada indivíduo:
1. **Número de Destino**: Soma reduzida da Data de Nascimento.
2. **Número de Expressão**: Soma reduzida dos valores das letras do Nome Completo.
3. **Número de Harmonia Conjugal**: A soma do *Destino* com a *Expressão*, reduzida a um dígito (1 a 9).

### 1.1 Regra de Redução Numerológica
Qualquer soma acima de 9 deve ser reduzida somando-se seus dígitos, até resultar em um número único.
*Exceção: Números Mestres (11 e 22)* não são reduzidos ao calcular o Destino e Expressão individualmente, **mas são reduzidos ao calcular o Número da Harmonia Conjugal**.

**Exemplo de redução de 29:**
`2 + 9 = 11` -> Para Harmonia Conjugal, reduz novamente: `1 + 1 = 2`.

---

## 2. Cálculo do Número da Harmonia Conjugal (Individual)

Para cada pessoa (Pessoa A e Pessoa B), você deve encontrar o Número de Harmonia Conjugal seguindo a equação:

```text
Harmonia = Reduzir( Número de Destino + Número de Expressão )
```

> **Nota Crítica**: O resultado final deve ser **estritamente entre 1 e 9**. Se a soma der 11 ou 22, continue reduzindo (11 vira 2; 22 vira 4).

---

## 3. Matriz de Compatibilidade (Tabela de Harmonia)

Com o Número de Harmonia da Pessoa A (`hA`) e da Pessoa B (`hB`), utilizamos a seguinte tabela de relação geométrica numerológica do SincroApp. A tabela define qual é a relação do número X com o número Y.

As relações possíveis são:
- **Vibra (Vibram Juntos)**: Compatibilidade excelente, sintonia natural.
- **Atrai (Atração)**: Química poderosa, aprendizado, magnetismo.
- **Oposto (Opostos)**: Visões de mundo contrárias, exige diálogo, mas podem se complementar.
- **Passivo (Passivo)**: Relação estável mas que exige esforço mútuo para não cair na monotonia.

| Número | Vibra | Atrai | Oposto | Passivo |
| :---: | :---: | :---: | :---: | :---: |
| **1** | 9 | 4, 8 | 6, 7 | 2, 3, 5 |
| **2** | 8 | 7, 9 | 5 | 1, 3, 4, 6 |
| **3** | 7 | 5, 6, 9 | 4, 8 | 1, 2 |
| **4** | 6 | 1, 8 | 3, 5 | 2, 7, 9 |
| **5** | 5 | 3, 9 | 2, 4, 6 | 1, 7, 8 |
| **6** | 4 | 3, 7, 9 | 1, 5, 8 | 2 |
| **7** | 3 | 2, 6 | 1, 9 | 4, 5, 8 |
| **8** | 2 | 1, 4 | 3, 6 | 5, 7, 9 |
| **9** | 1 | 2, 3, 5, 6 | 7 | 4, 8 |

### Regra de Números Iguais
Se `hA == hB`:
- Se ambos forem `5`: "Compatíveis (Vibram juntos)".
- Se ambos forem qualquer outro número (1 a 4 ou 6 a 9): "Compatíveis (Monotonia)". Identificação imediata, mas tendência à rotina.

---

## 4. Cálculo do Score (Pontuação Final)

A Sinastria SincroApp converte a relação encontrada na tabela acima em um **score de 0 a 100**, somando um ajuste fino baseado nos Números de Destino.

### Passo 4.1: Pontuação Base (Status da Relação)

De acordo com o quadro em que `hB` se encontra na linha de `hA` (ou se são iguais), defina a pontuação base da relação (`score`):

- **Vibram Juntos** / **Compatíveis (Monotonia)**: `Score Base = 95.0`
- **Atração (Atrai)**: `Score Base = 85.0`
- **Opostos (Oposto)**: `Score Base = 65.0`
- **Passivo**: `Score Base = 40.0`
- **Neutro** (nenhuma regra encontrada, fallback): `Score Base = 50.0`

### Passo 4.2: Ajuste Fino pelo Propósito de Vida (Destino)

Verifique o Número de Destino da Pessoa A (`dA`) e o Número de Destino da Pessoa B (`dB`). Esses números **mantêm os numerais mestres 11 e 22** se existirem.

Aplica-se apenas o **maior** bônus válido abaixo ao Score Base:
1. **Destinos Iguais:** Se `dA == dB`, `Score += 5`
2. **Mesma Vibração Par/Ímpar:** Se não são iguais, mas ambos são pares ou ambos são ímpares (exemplo: `dA % 2 == dB % 2`), `Score += 2`

### Passo 4.3: Clamp
Por fim, garanta que o score final nunca ultrapasse os limites:
- Se `Score > 100`, então `Score = 100`.
- Se `Score < 0`, então `Score = 0`.

---

## 5. Exemplo Prático (Pseudo-Código)

```javascript
function calcularSinastriaAmorosa(pessoaA, pessoaB) {
  // 1. Extrair os números calculados previamente
  const harmoniaA = reduzir1A9(pessoaA.destino + pessoaA.expressao);
  const harmoniaB = reduzir1A9(pessoaB.destino + pessoaB.expressao);
  
  // 2. Definir Status e Score Base
  let status = "";
  let scoreBase = 50;

  if (harmoniaA === harmoniaB) {
    if (harmoniaA === 5) {
      status = "Vibram Juntos";
      scoreBase = 95;
    } else {
      status = "Monotonia";
      scoreBase = 95;
    }
  } else {
    // Buscar na tabela a relação de harmoniaB dentro das listas de harmoniaA
    const regrasDeA = tabelaHarmonia[harmoniaA];
    
    if (regrasDeA.vibra.includes(harmoniaB)) {
      status = "Vibram Juntos"; scoreBase = 95;
    } else if (regrasDeA.atrai.includes(harmoniaB)) {
      status = "Atração"; scoreBase = 85;
    } else if (regrasDeA.oposto.includes(harmoniaB)) {
      status = "Opostos"; scoreBase = 65;
    } else if (regrasDeA.passivo.includes(harmoniaB)) {
      status = "Passivo"; scoreBase = 40;
    } else {
      status = "Neutro"; scoreBase = 50;
    }
  }

  // 3. Ajuste Fino pelo Destino
  let bônus = 0;
  if (pessoaA.destino === pessoaB.destino) {
    bônus = 5;
  } else if ((pessoaA.destino % 2) === (pessoaB.destino % 2)) {
    bônus = 2;
  }

  // 4. Fechar Total
  const scoreFinal = Math.min(100, Math.max(0, scoreBase + bônus));

  return {
    score: scoreFinal,
    status: status
  };
}
```

## 6. Integração com IA Neural (N8N)
Quando o sistema gera análises mais complexas em linguagem humanizada, enviamos o resultado numérico exato extraído desta lógica como a **verdade absoluta** para a IA, num Payload estruturado para o webhook. Exemplo de payload enviado ao integrador (N8N):

```json
{
  "instructions": "CRITICAL: You are an expert Numerologist. You MUST use the pre-calculated numbers provided in this JSON... The provided numbers (...) are the ABSOLUTE TRUTH...",
  "user": {
    "name": "João",
    "birthDate": "12/05/1990",
    "profile": { "destino": 9, "expressao": 1, "harmoniaConjugal": 1 }
  },
  "partner": {
    "name": "Maria",
    "birthDate": "22/10/1992",
    "profile": { "destino": 8, "expressao": 5, "harmoniaConjugal": 4 }
  },
  "synastry": {
    "score": 85,
    "status": "Atração",
    "details": {
       "numA": 1, 
       "numB": 4,
       "destinyMatch": false
    }
  }
}
```
A IA, em seguida, unifica os arquétipos dos perfis preenchendo a experiência do usuário, baseada sempre na regra matemática travada por este Engine.
