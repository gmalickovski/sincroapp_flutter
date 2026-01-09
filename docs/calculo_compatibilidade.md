# Documentação do Cálculo de Compatibilidade (Harmonia Conjugal)

Este documento detalha a lógica utilizada pelo sistema Sincro para calcular a compatibilidade e sinergia entre dois perfis, baseando-se estritamente nos preceitos da **Numerologia Cabalística**.

## 1. Fonte de Dados (O Coração do Sistema)

Todo o cálculo utiliza como base os números gerados pelo `NumerologyEngine`, que processa os nomes e datas de nascimento seguindo a tabela de conversão cabalística.

*   **Importante**: A tabela diferencia letras acentuadas. Por exemplo, 'a' possui valor 1, enquanto 'á' possui valor 3 (1 + 2). A grafia correta é essencial.

## 2. Parâmetros Utilizados

A análise de compatibilidade ("Sinastria Amorosa") utiliza principalmente os seguintes números do perfil de cada pessoa:

1.  **Número de Harmonia (ou Harmonia Conjugal)**:
    *   Calculado somando-se o **Número de Destino** + **Número de Expressão**.
    *   O resultado é reduzido a um dígito (1 a 9).
    *   *Nota*: Este é o principal indicador da dinâmica do relacionamento.

2.  **Número de Destino**:
    *   Derivado da data de nascimento. Usado para modular o "Score" (pontuação) final da compatibilidade.

## 3. Lógica de Classificação (Tabela de Harmonia)

A relação entre os Números de Harmonia das duas pessoas é classificada em 4 categorias, conforme a matriz definida no serviço `HarmonyService` (baseada na literatura da numerologia):

*   **Vibram (Sinergia Alta)**: Números que possuem a mesma essência vibracional. A compreensão é imediata.
    *   *Exemplo*: 1 com 9; 3 com 7.
*   **Atraem (Sinergia Média-Alta)**: Números que se complementam e geram atração/interesse.
    *   *Exemplo*: 1 com 4 ou 8.
*   **Opostos (Sinergia Desafiadora)**: Números que veem o mundo de ângulos contrários. Exige diálogo e evolução, mas é muito poderoso se bem trabalhado.
    *   *Exemplo*: 1 com 6 ou 7.
*   **Passivos (Sinergia Neutra/Estável)**: Relação tranquila, mas com risco de monotonia. Exige esforço para manter a chama.
    *   *Exemplo*: 1 com 2 ou 3.
*   **Monotonia (Mesmo Número)**: Se ambos possuem o **mesmo** número de harmonia (ex: 7 e 7), a relação é de espelho. É compatível, mas tende ao tédio se não houver inovação. (Exceto número 5 com 5, que é pura vibração).

## 4. Cálculo do Score (Porcentagem)

O sistema atribui uma pontuação percentual para facilitar a visualização da compatibilidade:

*   **Base**:
    *   **Vibram**: 95% (Excelente)
    *   **Atraem**: 80% (Muito Bom)
    *   **Passivo/Monotonia**: 60% (Regular/Bom)
    *   **Oposto**: 65% (Desafiador/Potente)

*   **Ajuste Fino (Destinos)**:
    *   Se os **Números de Destino** forem compatíveis (Vibram ou Atraem), adiciona-se **+5%** ao score.
    *   Se forem incompatíveis, remove-se **-5%**.
    *   Isso reflete que, mesmo que a Harmonia seja difícil, Destinos compatíveis ajudam na jornada (e vice-versa).

## 5. Implementação Técnica

A lógica está centralizada em `lib/services/harmony_service.dart`, método `calculateSynastry`, garantindo consistência em todo o aplicativo.

---
*Documento gerado automaticamente pela Equipe de Engenharia Sincro.*
