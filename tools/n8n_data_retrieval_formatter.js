/**
 * N8n Data Retrieval - Format Tasks Response
 * Formata as tarefas retornadas do Supabase para o AI Agent
 */

// === INPUTS ===
const parserOutput = $('Parse Date Range').first().json; // .first() avoids "Paired item" error on multiple tasks
const tasksRaw = items; // Array de tarefas do Supabase

const tasks = tasksRaw.map(item => item.json);
const timeRange = parserOutput.timeRange;
const humanDescription = parserOutput.humanDescription;
const originalQuestion = parserOutput.originalQuestion;

// === FORMAT TASKS ===
// Inclui todos os campos necessários para renderizar TaskItem no Flutter
const formattedTasks = tasks.map((task, index) => {
    const dueDate = task.due_date ? new Date(task.due_date) : null;
    const formattedDate = dueDate
        ? dueDate.toLocaleDateString('pt-BR', { weekday: 'short', day: '2-digit', month: 'short' })
        : 'Sem data';

    // Verifica se a tarefa está atrasada
    const now = new Date();
    const isOverdue = dueDate && dueDate < now && !task.completed;

    return {
        // Campos essenciais para TaskModel
        id: task.id,
        text: task.text || task.title || 'Sem título',
        completed: task.completed || false,
        due_date: task.due_date,  // ISO string para parse no Flutter
        personal_day: task.personal_day || null,
        journey_id: task.journey_id || null,
        journey_title: task.journey_title || null,
        tags: task.tags || [],
        recurrence_type: task.recurrence_type || 'none',
        recurrence_days_of_week: task.recurrence_days_of_week || [],
        reminder_at: task.reminder_at || null,

        // Campos extras para display
        index: index + 1,
        date_formatted: formattedDate,
        is_overdue: isOverdue
    };
});

// === BUILD SUMMARY ===
const taskCount = formattedTasks.length;
let summary = '';

if (taskCount === 0) {
    switch (timeRange) {
        case 'next_week':
            summary = '🎉 Você não tem nenhuma tarefa agendada para a semana que vem.';
            break;
        case 'this_week':
            summary = '✨ Nenhuma tarefa para esta semana.';
            break;
        case 'today':
            summary = '🌟 Seu dia está livre! Nenhuma tarefa para hoje.';
            break;
        case 'overdue':
            summary = '👏 Parabéns! Você não tem tarefas atrasadas.';
            break;
        case 'this_month':
            summary = '📅 Nenhuma tarefa para este mês.';
            break;
        default:
            summary = '📭 Nenhuma tarefa encontrada.';
    }
} else {
    const plural = taskCount > 1 ? 's' : '';
    switch (timeRange) {
        case 'next_week':
            summary = `📅 Você tem ${taskCount} tarefa${plural} para a semana que vem:`;
            break;
        case 'this_week':
            summary = `📋 Você tem ${taskCount} tarefa${plural} para esta semana:`;
            break;
        case 'today':
            summary = `📌 Você tem ${taskCount} tarefa${plural} para hoje:`;
            break;
        case 'overdue':
            summary = `⚠️ Você tem ${taskCount} tarefa${plural} atrasada${plural}:`;
            break;
        case 'this_month':
            summary = `📅 Você tem ${taskCount} tarefa${plural} para este mês:`;
            break;
        default:
            summary = `📋 Encontrei ${taskCount} tarefa${plural}:`;
    }
}

// === BUILD TASK LIST FOR DISPLAY (internal use only - não enviar ao Flutter) ===
const taskList = formattedTasks.map(t =>
    `${t.index}. **${t.title}** - ${t.date}`
).join('\n');

// === OUTPUT FOR AI AGENT ===
// IMPORTANTE: answer_text contém APENAS o título, sem lista de tarefas
// O Flutter renderiza as tarefas visualmente usando o array 'tasks'
return {
    question: originalQuestion,
    timeRange: timeRange,
    humanDescription: humanDescription,
    taskCount: taskCount,
    summary: summary,
    // answer_text: Texto que aparece no chat - APENAS o título, sem lista
    answer_text: summary,
    // taskList: Lista formatada para uso interno do AI Agent (não exibir no Flutter)
    taskList: taskList,
    // tasks: Array completo para renderização visual no Flutter
    tasks: formattedTasks,
    hasActions: taskCount > 0,
    availableActions: taskCount > 0 ? [
        { type: 'edit', label: 'Alterar data' },
        { type: 'complete', label: 'Marcar como concluída' },
        { type: 'delete', label: 'Excluir' }
    ] : [],
    token_usage: { total_tokens: parserOutput.router_usage?.total_tokens || 0 }
};
