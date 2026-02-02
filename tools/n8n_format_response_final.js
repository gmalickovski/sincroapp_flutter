// N8n Node Code: Format Response (Ctx Aware v3)
// Copie e cole este código no campo "JavaScript Code" do nó "Format Response"

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
} catch (e) { }

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
