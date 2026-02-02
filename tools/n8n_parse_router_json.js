// N8n Node Code: Parse Router JSON
// Copie e cole este código no campo "JavaScript Code" do nó "Parse Router JSON"

const input = items[0].json;
const content = input.output || input.text || input.message?.content || JSON.stringify(input);

// 1. Limpeza do JSON (Markdown Code Blocks)
let cleanJson = content;
if (typeof content === 'string') {
    cleanJson = content.replace(/```json/g, "").replace(/```/g, "").trim();
}

// 2. Parsing do JSON
let parsed = {};
try {
    parsed = typeof cleanJson === 'object' ? cleanJson : JSON.parse(cleanJson);
} catch (e) {
    parsed = { error: "Failed to parse JSON", raw_content: content };
}

// 3. Captura Robusta de Uso de Tokens
// Tenta pegar de várias fontes possíveis (Groq usa camelCase, OpenAI usa snake_case)
let rawUsage = input.tokenUsage || input.usage || input.token_usage || { total_tokens: 0 };

// 4. Normalização para snake_case (Padrão do Workflow)
const usage = {
    total_tokens: rawUsage.totalTokens || rawUsage.total_tokens || 0,
    prompt_tokens: rawUsage.promptTokens || rawUsage.prompt_tokens || 0,
    completion_tokens: rawUsage.completionTokens || rawUsage.completion_tokens || 0
};

// 5. Estimativa de Fallback (Se o N8n engoliu os dados)
if (usage.total_tokens === 0) {
    // Estimativa grosseira: ~4 caracteres por token
    const estimated = Math.ceil(JSON.stringify(parsed).length / 4);
    usage.total_tokens = estimated;
    usage.estimated = true; // Flag para indicar que foi estimado
}

// Atribui o uso ao objeto final
parsed.router_usage = usage;

// [Específico para Groq/LangChain]
// Às vezes a resposta real está aninhada profundamente
if (input.response?.generations?.[0]?.text && !parsed.tool) {
    try {
        const nested = JSON.parse(input.response.generations[0].text);
        // Mescla o conteúdo aninhado com o parsed atual
        parsed = { ...parsed, ...nested };
    } catch (e) {
        // Falha silenciosa se não for JSON válido
    }
}

return parsed;
