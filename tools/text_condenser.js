/**
 * Sincro AI - Text Condenser (RAG Pre-processor)
 * 
 * Este script deve rodar em um "Code Node" do n8n (Workflow B).
 * Ele recebe uma lista bruta de objetos do Supabase (tasks, goals)
 * e a transforma em uma string Markdown compacta para o LLM.
 * 
 * Objetivo: Reduzir uso de tokens drasticamente.
 */

const items = $input.all().map(i => i.json); // Pega todos os itens da query Supabase

// Se vazio
if (!items.length) {
    return { markdown: "Nenhum item encontrado para este período." };
}

// Detecta tipo de entidade baseada nos campos
const isTask = items[0].hasOwnProperty('due_date');
const isGoal = items[0].hasOwnProperty('progress');
const isJournal = items[0].hasOwnProperty('mood');

let markdownOutput = "";

if (isTask) {
    markdownOutput = "### Tarefas Encontradas:\n";
    items.forEach(t => {
        const status = t.completed ? "[x]" : "[ ]";
        const dia = t.due_date ? t.due_date.split('T')[0] : "Sem data";
        // Formato: - [ ] Título (Data) #tags
        markdownOutput += `- ${status} ${t.title || t.text} (${dia}) ${t.shared_with && t.shared_with.length ? '👥' : ''}\n`;
    });
} else if (isGoal) {
    markdownOutput = "### Metas Ativas:\n";
    items.forEach(g => {
        // Formato: - Título (Progresso%) - Prazo
        markdownOutput += `- 🎯 ${g.title} (${g.progress || 0}%) [Prazo: ${g.target_date || 'N/A'}]\n`;
    });
} else if (isJournal) {
    markdownOutput = "### Diário Recente:\n";
    items.forEach(j => {
        // Formato: - Data (Mood): Resumo...
        const data = j.created_at.split('T')[0];
        const content = j.content ? j.content.substring(0, 100).replace(/\n/g, ' ') : "";
        markdownOutput += `- ${data} (Mood ${j.mood}/5): ${content}...\n`;
    });
} else {
    // Fallback genérico
    markdownOutput = JSON.stringify(items.slice(0, 10)); // Limita a 10 se não reconhecer
}

return {
    record_count: items.length,
    markdown_context: markdownOutput
};
