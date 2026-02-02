/**
 * N8n Universal Response Formatter
 * 
 * Este código deve ser usado no nó "Final Response" (ou "Format Response") ao final do fluxo.
 * Ele consolida a resposta de qualquer Worker (Numerologia, RAG, Ação, Chitchat) e
 * calcula o uso total de tokens.
 * 
 * DESTAQUES:
 * 1. Usa .first() para evitar erro de "Paired item data unavailable".
 * 2. Faz parse automático se o output vier como string Markdown (```json).
 * 3. Garante estrutura limpa para o App Flutter.
 */

// --- 1. RASTREAMENTO DE CUSTO (TOKENS) ---
// Usa .first() para evitar erros de pareamento (N-to-1 aggregation issue)
const routerNode = $('Parse Router JSON');
const routerUsage = (routerNode.first() && routerNode.first().json.router_usage) || { total_tokens: 0 };

// Pega o custo do Worker atual (input imediato)
// Tenta várias propriedades comuns de usage
const workerUsage = items[0].json.tokenUsage || items[0].json.token_usage || { total_tokens: 0 };
const totalTokens = (routerUsage.total_tokens || 0) + (workerUsage.total_tokens || 0);

// --- 2. RECUPERAÇÃO DE DADOS & RESPOSTA ---
const input = items[0].json;
let content = input.output || input.text || input.message?.content || "";
let response = {};

// Tenta fazer parse se vier como string JSON (comum em IAs que respondem com Markdown)
if (typeof content === 'string' && (content.trim().startsWith('{') || content.includes('```json'))) {
    try {
        const clean = content.replace(/```json/g, "").replace(/```/g, "").trim();
        const parsed = JSON.parse(clean);
        response = parsed;
    } catch (e) {
        response.answer = content; // Fallback se o parse falhar
    }
} else if (typeof content === 'object') {
    response = content;
} else {
    // Se for texto simples
    response.answer = content || "Resposta processada.";
}

// [CASO ESPECIAL: RAG/Tarefas]
// Recupera tasks de forma segura tentando acessar o nó de tasks
try {
    const ragNode = $('Format Tasks Response');
    // Só tenta ler se o node existiu E rodou
    if (ragNode && ragNode.first()) {
        const ragData = ragNode.first().json;
        if (ragData.tasks) {
            response.tasks = ragData.tasks;
            response.taskCount = ragData.taskCount;
        }
    }
} catch (e) {
    // Silenciosamente ignora se o nó não faz parte deste caminho
}

// [CASO ESPECIAL: AÇÃO]
// Se o input original tinha actions (e não foram pegas pelo parse acima), preserva elas
if (input.actions && !response.actions) response.actions = input.actions;

// --- 3. MONTAGEM DO TOKEN USAGE ---
response.token_usage = {
    total_tokens: totalTokens,
    router: routerUsage.total_tokens,
    worker: workerUsage.total_tokens
};

return response;
