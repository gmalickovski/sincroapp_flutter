# Guia de Atualização Manual: Contexto do Chat no N8n 🧠

Este guia explica exatamente onde clicar e o que colar no N8n para que a IA comece a entender o contexto da conversa (ex: "melhore o texto anterior").

---

## Opção A: Importação Automática (Recomendada)
O arquivo `tools/n8n_v6_workflows.json` já foi atualizado com todas as mudanças.
1. No N8n, delete seu workflow atual.
2. Vá em **Import from File**.
3. Selecione o arquivo `tools/n8n_v6_workflows.json`.
4. Pronto!

---

## Opção B: Atualização Manual (Passo a Passo)

Se você prefere editar nó por nó, siga estes 3 passos simples.

### 1. Atualizar o **Router LLM**
Este nó precisa saber do histórico para decidir se você está pedindo uma correção ou algo novo.

*   **Abra o nó**: `Router LLM` (AI Agent / OpenAI)
*   **Encontre o campo**: `Text` (ou Prompt)
*   **Apague** o conteúdo atual.
*   **Cole** exatamente este código (clique no ícone de engrenagem e mude para "Expression" se necessário):

```javascript
=Contexto: Data atual = {{ $json.body.context.currentDate }} ({{ $json.body.context.currentWeekDay }})

Histórico:
{{ $json.body.context.previous_messages ? $json.body.context.previous_messages.map(m => '- ' + m.role + ': ' + m.content).join('\n') : 'Nenhum' }}

Pergunta do usuário: {{ $json.body.question }}
```

---

### 2. Atualizar o Worker: **Numerology Insight**
Este nó precisa ver o texto anterior para saber o que "melhorar".

*   **Abra o nó**: `Worker: Numerology Insight`
*   **Encontre o campo**: `Text` (ou Prompt)
*   **Cole** este código:

```javascript
=Histórico:
{{ $('Webhook (SincroApp)').item.json.body.context.previous_messages ? $('Webhook (SincroApp)').item.json.body.context.previous_messages.map(m => '- ' + m.role + ': ' + m.content).join('\n') : 'Nenhum' }}

Pergunta Atual: {{ $('Webhook (SincroApp)').item.json.body.question }}
```

---

### 3. Atualizar o Worker: **Chitchat**
Para manter conversas fluidas.

*   **Abra o nó**: `Worker: Chitchat`
*   **Encontre o campo**: `Text` (ou Prompt)
*   **Cole** o mesmo código acima:

```javascript
=Histórico:
{{ $('Webhook (SincroApp)').item.json.body.context.previous_messages ? $('Webhook (SincroApp)').item.json.body.context.previous_messages.map(m => '- ' + m.role + ': ' + m.content).join('\n') : 'Nenhum' }}

Pergunta Atual: {{ $('Webhook (SincroApp)').item.json.body.question }}
```

---

## ✅ Conclusão

Agora, quando você disser *"Melhore isso"* ou *"Faça mais curto"*, a IA vai ler o **Histórico** que inserimos acima e entenderá a que você se refere! 🚀
