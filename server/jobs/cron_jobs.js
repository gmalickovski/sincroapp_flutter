const cron = require('node-cron');
const admin = require('../config/firebase_admin');
const { isBefore, startOfDay, endOfDay, format } = require('date-fns');

function initCronJobs(supabase) {
    if (!supabase) {
        console.error('[CRON] Supabase não fornecido. Jobs abortados.');
        return;
    }

    if (!admin.apps.length) {
        console.warn('[CRON] Firebase Admin não configurado. Jobs rodarão mas sem disparar Push Notifications.');
    }

    // Define the schema once correctly
    const db = supabase.schema('sincroapp');

    // Helper function to get tokens by user
    async function getUserTokens(userId) {
        try {
            const { data, error } = await db.from('user_push_tokens').select('fcm_token').eq('user_id', userId);
            if (error) throw error;
            return data ? data.map(d => d.fcm_token) : [];
        } catch (err) {
            console.error(`[CRON] Erro ao buscar tokens para \${userId}:`, err.message);
            return [];
        }
    }

    // Helper function to send multi-cast messages securely (silent catching)
    async function sendPushToUser(userId, title, body, dataPayload = {}) {
        if (!admin.apps.length) return; // Skip if firebase not active

        const tokens = await getUserTokens(userId);
        if (!tokens.length) return;

        try {
            const message = {
                notification: { title, body },
                data: dataPayload,
                tokens: tokens,
            };
            const response = await admin.messaging().sendEachForMulticast(message);
            if (response.failureCount > 0) {
                response.responses.forEach((resp, idx) => {
                    if (!resp.success) {
                        console.error(`[FIREBASE] Push failed for token \${tokens[idx]}:`, resp.error);
                    }
                });
            }
        } catch (err) {
            console.error(`[FIREBASE] Escrita de Push falhou para user \${userId}:`, err);
        }
    }

    // 1. Numerologia Matinal (08:30)
    // "30 08 * * *" -> Everyday at 08:30 server time
    cron.schedule('30 08 * * *', async () => {
        console.log('[CRON] Rodando Job Matinal de Numerologia (08:30)');
        // This assumes server timezone matches user's targeted timezone or was requested as 08:30 host local.
        // Opcional: you can loop over unique users and compute Numerology.
        try {
            const { data: users, error } = await db.from('users').select('id, data_nascimento');
            if (error) throw error;

            for (const u of users) {
                // Envia notificação matinal simples pra cada (a Numerologia poderia ser calculada aqui)
                await sendPushToUser(u.id, 'Bom dia! ☀️', 'Confira como as energias de hoje podem te guiar e veja suas tarefas para o dia.', {
                    action: 'VIEW_DASHBOARD'
                });
            }
            console.log(`[CRON] Push Matinal enviada para \${users.length} usuários.`);
        } catch (err) {
            console.error('[CRON] Erro no job Matinal:', err.message);
        }
    });

    // 2. Revisão Fim de Dia / Pendências (20:00)
    // "00 20 * * *" -> Everyday at 20:00 server time
    cron.schedule('00 20 * * *', async () => {
        console.log('[CRON] Rodando Job Noturno (20:00)');
        try {
            const { data: users, error } = await db.from('users').select('id');
            if (error) throw error;

            for (const u of users) {
                // Verifica se há tarefas pendentes hoje
                const { data: tasks } = await db.from('tasks')
                    .select('id')
                    .eq('owner_id', u.id)
                    .eq('status', 'Pendente')
                    .eq('is_deleted', false);

                if (tasks && tasks.length > 0) {
                    await sendPushToUser(u.id, 'Fim de dia 🌙', `Você tem \${tasks.length} tarefas pendentes para hoje. Que tal revisá-las?`, {
                        action: 'VIEW_TASKS'
                    });
                }
            }
        } catch (err) {
            console.error('[CRON] Erro no job Noturno:', err.message);
        }
    });

    // 3. Tarefas Atrasadas (a cada 30 min)
    // "0,30 * * * *" -> Runs on minute 0 and 30
    cron.schedule('0,30 * * * *', async () => {
        console.log('[CRON] Verificando tarefas recém-atrasadas...');
        try {
            const nowUtc = new Date().toISOString();

            // Pega tarefas q acabaram de vencer nas últimas horas e não estão deletadas e estão pendentes
            const { data: overdueTasks, error } = await db.from('tasks')
                .select('id, title, owner_id')
                .eq('status', 'Pendente')
                .eq('is_deleted', false)
                .lt('due_date', nowUtc)
                // Adiciona um limite ou flag na DB depois pra não notificar a mesma tarefa múltiplas vezes.
                // Simularemos pegando a lista basiquinha
                .limit(50);

            if (error) throw error;

            // Group by user
            const usersToNotify = {};
            overdueTasks.forEach(task => {
                if (!usersToNotify[task.owner_id]) usersToNotify[task.owner_id] = [];
                usersToNotify[task.owner_id].push(task);
            });

            for (const [userId, tasks] of Object.entries(usersToNotify)) {
                if (tasks.length === 1) {
                    await sendPushToUser(userId, 'Tarefa Atrasada 🚨', `A tarefa "\${tasks[0].title}" está atrasada.`, { action: 'VIEW_TASK', taskId: tasks[0].id });
                } else {
                    await sendPushToUser(userId, 'Tarefas Atrasadas 🚨', `Você tem \${tasks.length} tarefas que acabaram de atrasar.`, { action: 'VIEW_TASKS' });
                }
            }
        } catch (err) {
            console.error('[CRON] Erro no job de Atrasadas:', err.message);
        }
    });

    console.log('[CRON] Jobs de Notificação agendados com sucesso.');
}

module.exports = { initCronJobs };
