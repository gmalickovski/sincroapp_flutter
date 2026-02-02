# CÓDIGOS COMPLETOS E ATUALIZADOS (V6.1)

Aqui estão os códigos **V6.1** já prontos para você copiar e colar nos nós do seu N8n.
Eles incluem:
1.  **Memória de Chat**: Capacidade de entender "melhore o texto anterior".
2.  **Correção de Balões Fantasmas**: Remove mensagens de erro genéricas.
3.  **Correção de Textos**: Adiciona "Segue abaixo..." para melhor experiência.

---

## 1. NÓ: Router LLM (AI Agent)

**Campo**: `System Message` (Prompt)
**Ação**: Substitua TODO o prompt atual por este:

```markdown
# System Prompt: Sincro AI Router
# System Message: Router (Sincro V6)
**Modelo Recomendado**: GPT-4o-mini, Claude 3 Haiku, ou Llama 3 8B (Temp Baixa: 0.1)

---

Você é o **Roteador (Router)** da **Sincro IA**.
Seu **ÚNICO** trabalho é classificar a intenção do usuário e selecionar a ferramenta correta para lidar com ela.
Você NÃO responde ao usuário diretamente.
Você NÃO realiza cálculos.
Você NÃO acessa o banco de dados diretamente.
**IMPORTANTE**: Se o usuário fizer referências vagas ("mude isso", "melhore o texto", "na outra data"), consulte o **Histórico de Conversa** para entender o contexto anterior.

## Ferramentas Disponíveis

### 1. `numerology_engine`
**Quando usar**:
- Usuário pergunta sobre "vibração", "numerologia", "compatibilidade", "energia".
- Usuário pergunta "O dia hoje é bom para X?" ou "Qual meu Ano Pessoal?".
- Usuário pede insights ou explicações sobre seu perfil (ex: "O que significa meu número de Expressão?").
- Usuário menciona datas específicas em um contexto de dúvida/previsão (ex: "Veja a data 2026-05-10").
*Internamente, use a lógica da Numerologia Cabalística.*

### 2. `data_retrieval`
**Quando usar**:
- Usuário pergunta sobre dados passados ou armazenados.
- Exemplos: "Quais são minhas tarefas?", "Tenho metas para este mês?", "O que eu anotei ontem?".
- Recuperação de memória ou histórico (RAG).

**Parâmetros time_range**:
- `today` - Tarefas de hoje
- `tomorrow` - Tarefas de amanhã
- `this_week` - Tarefas desta semana
- `next_week` - Tarefas da semana que vem
- `this_month` - Tarefas até o fim do mês
- `overdue` - Tarefas atrasadas
- `pending` - Todas as tarefas pendentes

### 3. `action_scheduler`
**Quando usar**:
- Usuário quer explicitamente CRIAR, ATUALIZAR ou DELETAR algo.
- Palavras-chave: "Agende", "Crie uma tarefa", "Lembre-me de", "Marque uma reunião".
- **Usuário pede SUGESTÃO de melhor data para algo** (ex: "Qual melhor dia para passear?"). Neste caso, use `target_date: null`.

**OBRIGATÓRIO**: Sempre extraia um `title` curto e descritivo do texto (ex: "Meditação Guiada", "Passear com família").

**CRÍTICO**: Para calcular datas relativas ("amanhã", "semana que vem"), use SEMPRE a `currentDate` do contexto.

### 4. `chitchat`
**Quando usar**:
- Saudações ("Oi", "Bom dia").
- Perguntas genéricas que não exigem dados do usuário ou numerologia ("Quem é você?", "Conte uma piada").
- Agradecimentos simples.

## Formato de Saída (SOMENTE JSON)

Você deve retornar **estritamente** um objeto JSON. 
**NÃO** use blocos de código Markdown (```json). 
**NÃO** escreva explicações.
Retorne APENAS o JSON cru.

```json
{
  "tool": "nome_da_ferramenta",
  "confidence": 0.99,
  "params": {
    "intent": "create_task | update_task | delete_task",
    "title": "Título curto extraído do texto", // OBRIGATÓRIO para action_scheduler
    "target_date": "YYYY-MM-DDTHH:mm:ss", // Calcule baseado em currentDate. Se o usuário NÃO especificar horário, use 00:00:00.
    "time_specified": true // Defina como false se o usuário não mencionou um horário específico
  }
}
```

### Exemplos

**Entrada**: "Bom dia Sincro!"
**Saída**: `{"tool": "chitchat", "confidence": 1.0, "params": {}}`

**Entrada**: "Como está minha vibração para fechar negócio amanha?" (Contexto: currentDate = 2026-01-31)
**Saída**: `{"tool": "numerology_engine", "confidence": 0.99, "params": {"target_date": "2026-02-01T09:00:00", "intent": "business_contract"}}`

**Entrada**: "Quais minhas tarefas para hoje?"
**Saída**: `{"tool": "data_retrieval", "confidence": 0.99, "params": {"entities": ["task"], "time_range": "today"}}`

**Entrada**: "Agende um jogo de futebol para amanhã" (Sem horário)
**Saída**: `{"tool": "action_scheduler", "confidence": 0.98, "params": {"intent": "create_task", "target_date": "2026-02-01T00:00:00", "title": "Jogo de futebol", "time_specified": false}}`

---
**CRÍTICO**: NUNCA alucine uma ferramenta não listada. Em caso de dúvida, use `chitchat`.
```

---

## 2. NÓ: Router LLM (AI Agent)

**Campo**: `Text` (Input da IA)
**Ação**: Troque para "Expression" e cole este código para injetar o histórico:

```javascript
=Contexto: Data atual = {{ $json.body.context.currentDate }} ({{ $json.body.context.currentWeekDay }})

Histórico:
{{ $json.body.context.previous_messages ? $json.body.context.previous_messages.map(m => '- ' + m.role + ': ' + m.content).join('\n') : 'Nenhum' }}

Pergunta do usuário: {{ $json.body.question }}
```

---

## 3. NÓ: Format Response (Code Node)

**Campo**: `JavaScript Code`
**Ação**: Este é o código que corrige os balões vazios e coloca os textos "Segue abaixo...":

```javascript
// N8n Node Code: Format Response (Ctx Aware v3)

// --- 1. RASTREAMENTO DE CUSTO (TOKENS) ---
const routerNode = $('Parse Router JSON');
const routerUsage = (routerNode.first() && routerNode.first().json.router_usage) || { total_tokens: 0 };
const workerUsage = items[0].json.tokenUsage || items[0].json.token_usage || { total_tokens: 0 };
const totalTokens = (routerUsage.total_tokens || 0) + (workerUsage.total_tokens || 0);

// --- 2. RECUPERAÇÃO DE DADOS & RESPOSTA ---
const input = items[0].json;
let content = input.output || input.text || input.message?.content || "";
let response = {};

// Parsing inteligente de JSON
if (typeof content === 'string' && (content.trim().startsWith('{') || content.includes('```json'))) {
    try {
        const clean = content.replace(/```json/g, "").replace(/```/g, "").trim();
        const parsed = JSON.parse(clean);
        response = parsed; 
    } catch (e) {
        response.answer = content; // Fallback
    }
} else if (typeof content === 'object') {
    response = content;
} else {
    response.answer = content || "Resposta processada.";
}

// [CASO ESPECIAL: RAG/Tarefas] recupera dados de tasks se existirem
try {
    const ragNode = $('Format Tasks Response'); 
    if (ragNode && ragNode.first()) {
        const ragData = ragNode.first().json;
        if (ragData.tasks) {
            response.tasks = ragData.tasks;
            response.taskCount = ragData.taskCount;
        }
    }
} catch (e) {}

// [CASO ESPECIAL: AÇÃO]
if (input.actions && !response.actions) response.actions = input.actions;

// --- 3. REFINAMENTO DE MENSAGEM (O Segredo!) ---
// Se tiver actions (cards de ação), e a resposta for genérica, substitui por frase útil pelo tipo de ação.
if (response.actions && response.actions.length > 0) {
    const genericPhrases = [
        "Resposta processada.", 
        "Resposta processada...", 
        "Ação agendada.", 
        "Solicitação processada."
    ];
    
    // Normaliza para lowercase e valida se é genérica ou vazia
    const cleanAnswer = (response.answer || "").trim();
    
    if (genericPhrases.includes(cleanAnswer) || cleanAnswer.length === 0) {
        // Verifica se é uma ação de agendamento (ActionProposalBubble)
        const isScheduling = response.actions.some(a => 
            a.type === 'schedule_event' || 
            a.type === 'create_task' || 
            a.type === 'propose_task' 
        );

        if (isScheduling) {
             response.answer = "Segue abaixo seu agendamento proposto:";
        } else {
             // Fallback para sugestões ou outras ações
             response.answer = "Segue abaixo sugestões de datas favoráveis:";
        }
    }
}

// --- 4. MONTAGEM FINAL DO TOKEN USAGE ---
response.token_usage = {
    total_tokens: totalTokens,
    router: routerUsage.total_tokens,
    worker: workerUsage.total_tokens
};

return response;
```

---

## 4. WORKERS (Numerology & Chitchat)

Para que eles também vejam o histórico (ex: "melhore isso"), cole a expressão de histórico no campo `Text` (Prompt) de ambos os nós.

**Código para o campo Text (Expression):**
```javascript
=Histórico:
{{ $('Webhook (SincroApp)').item.json.body.context.previous_messages ? $('Webhook (SincroApp)').item.json.body.context.previous_messages.map(m => '- ' + m.role + ': ' + m.content).join('\n') : 'Nenhum' }}

Pergunta Atual: {{ $('Webhook (SincroApp)').item.json.body.question }}
```
