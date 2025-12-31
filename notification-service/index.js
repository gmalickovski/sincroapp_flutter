/**
 * SincroApp - Notification Service (Supabase + FCM)
 * Serviço standalone para envio de notificações push (FCM)
 * Roda na VPS junto com o sistema web
 * 
 * Funcionalidades:
 * 1. Notificações diárias de fim de dia (21h BRT)
 * 2. Notificações de dia pessoal (8h BRT)
 * 3. Lembretes de tarefas vencidas
 * 
 * MIGRADO PARA SUPABASE (Dados) + FIREBASE (Messaging)
 */

require('dotenv').config(); // Carrega variáveis de ambiente (.env)
const admin = require('firebase-admin');
const cron = require('node-cron');
const axios = require('axios');
const { createClient } = require('@supabase/supabase-js');

// ========================================
// CONFIGURAÇÃO
// ========================================

// 1. Inicializa Firebase Admin (Apenas para Messaging)
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  // databaseURL não é mais necessário para Firestore, mas mantemos se precisar de algo legacy
});

const messaging = admin.messaging();

// 2. Inicializa Supabase Client (Para Dados)
const SUPABASE_URL = process.env.SUPABASE_URL || 'https://supabase.studiomlk.com.br';
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_KEY; // Use Service Role Key parar ignorar RLS

if (!SUPABASE_SERVICE_KEY) {
  console.error("❌ ERRO: SUPABASE_SERVICE_ROLE_KEY não definido no .env do notification-service");
  // process.exit(1); // Não descomentar até configurar o .env na VPS
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

// Configurações Geras
const CONFIG = {
  timezone: 'America/Sao_Paulo',
  n8nWebhook: 'https://n8n.studiomlk.com.br/webhook/sincroapp',
  notifications: {
    endOfDay: {
      enabled: true,
      schedule: '0 21 * * *', // 21h todo dia
      title: '🌙 Finalizando o dia',
      minTasks: 1
    },
    personalDay: {
      enabled: true,
      schedule: '0 8 * * *', // 8h todo dia
      title: '✨ Vibração do seu Dia'
    },
    overdueTasks: {
      enabled: true,
      schedule: '0 10,15 * * *', // 10h e 15h
      title: '⏰ Tarefas Atrasadas',
      minDays: 2
    }
  }
};

// ========================================
// HELPER: CÁLCULO NUMEROLÓGICO
// ========================================

function calculatePersonalDay(birthDateString, targetDate) {
  // Supabase retorna datas como string YYYY-MM-DD ou DD/MM/YYYY dependendo de como foi salvo.
  // Nosso código anterior usava string DD/MM/YYYY. Vamos garantir o parse correto.

  let day, month;

  if (birthDateString.includes('/')) {
    const parts = birthDateString.split('/');
    day = parseInt(parts[0]);
    month = parseInt(parts[1]);
  } else if (birthDateString.includes('-')) {
    const parts = birthDateString.split('-');
    // Assume YYYY-MM-DD
    day = parseInt(parts[2]);
    month = parseInt(parts[1]);
  } else {
    return 0;
  }

  // Reduz data de nascimento
  const birthDaySum = String(day).split('').reduce((a, b) => a + parseInt(b), 0);
  const birthMonthSum = String(month).split('').reduce((a, b) => a + parseInt(b), 0);

  // Reduz data alvo
  const targetDay = targetDate.getDate();
  const targetMonth = targetDate.getMonth() + 1;
  const targetYear = targetDate.getFullYear();

  const targetDaySum = String(targetDay).split('').reduce((a, b) => a + parseInt(b), 0);
  const targetMonthSum = String(targetMonth).split('').reduce((a, b) => a + parseInt(b), 0);
  const targetYearSum = String(targetYear).split('').reduce((a, b) => a + parseInt(b), 0);

  // Soma total
  let total = birthDaySum + birthMonthSum + targetDaySum + targetMonthSum + targetYearSum;

  // Reduz até número de 1 dígito (exceto 11, 22, 33)
  while (total > 9 && total !== 11 && total !== 22 && total !== 33) {
    total = String(total).split('').reduce((a, b) => a + parseInt(b), 0);
  }

  return total;
}

function getPersonalDayDescription(dayNumber) {
  const descriptions = {
    1: 'Dia de novos começos e iniciativa. Aproveite para iniciar projetos!',
    2: 'Dia de cooperação e sensibilidade. Foque em relacionamentos.',
    3: 'Dia criativo e comunicativo. Expresse-se!',
    4: 'Dia de organização e trabalho. Hora de estruturar.',
    5: 'Dia de mudanças e aventuras. Aceite o novo!',
    6: 'Dia de responsabilidade e família. Cuide dos seus.',
    7: 'Dia de introspecção e espiritualidade. Reflita.',
    8: 'Dia de poder e realizações materiais. Foque em resultados.',
    9: 'Dia de conclusão e compaixão. Finalize ciclos.',
    11: 'Dia de intuição e inspiração. Confie em sua voz interior.',
    22: 'Dia de grandes realizações. Construa algo duradouro.',
    33: 'Dia de serviço e amor universal. Ajude os outros.'
  };

  return descriptions[dayNumber] || 'Dia especial. Veja o que a numerologia diz!';
}

// ========================================
// FUNÇÕES DE NOTIFICAÇÃO
// ========================================

async function sendNotification(userId, tokens, title, body, data = {}) {
  if (!tokens || tokens.length === 0) {
    return { success: 0, failed: 0 };
  }

  const message = {
    notification: { title, body },
    data: {
      ...data,
      timestamp: new Date().toISOString()
    },
    tokens: Array.isArray(tokens) ? tokens : [tokens]
  };

  try {
    const response = await messaging.sendMulticast(message);

    // Remove tokens inválidos (NO SUPABASE)
    if (response.failureCount > 0) {
      const tokensToRemove = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          tokensToRemove.push(tokens[idx]);
        }
      });

      if (tokensToRemove.length > 0) {
        // Lógica para remover do Array no PostgreSQL (Supabase)
        // Precisamos buscar os tokens atuais, filtrar e atualizar.
        // Ou usar uma função RPC se existir. Faremos leitura + update por simplicidade aqui.

        // ATTENTION: Race conditions possible, but tolerable for token cleanup
        const { data: userData } = await supabase.schema('sincroapp').from('users').select('fcm_tokens').eq('uid', userId).single();
        if (userData && userData.fcm_tokens) {
          const newTokens = userData.fcm_tokens.filter(t => !tokensToRemove.includes(t));
          await supabase.schema('sincroapp').from('users').update({ fcm_tokens: newTokens }).eq('uid', userId);
          console.log(`🗑️ Removidos ${tokensToRemove.length} tokens inválidos para usuário ${userId}`);
        }
      }
    }

    return {
      success: response.successCount,
      failed: response.failureCount
    };

  } catch (error) {
    console.error(`❌ Erro ao enviar notificação para ${userId}:`, error.message);
    return { success: 0, failed: tokens.length };
  }
}

async function notifyN8n(event, data) {
  try {
    await axios.post(CONFIG.n8nWebhook, {
      event,
      timestamp: new Date().toISOString(),
      ...data
    });
  } catch (error) {
    console.error(`❌ Erro ao notificar n8n:`, error.message);
  }
}

// ========================================
// JOB 1: NOTIFICAÇÃO DE FIM DE DIA
// ========================================

async function sendEndOfDayNotifications() {
  if (!CONFIG.notifications.endOfDay.enabled) return;

  console.log('\n🌙 ===== INICIANDO NOTIFICAÇÕES DE FIM DE DIA (SUPABASE) =====');
  const startTime = Date.now();

  let totalSent = 0;
  let totalFailed = 0;

  try {
    // 1. Buscar todos os usuários
    const { data: users, error } = await supabase.schema('sincroapp').from('users').select('*');
    if (error) throw error;

    console.log(`📊 Total de usuários: ${users.length}`);

    for (const user of users) {
      // Mapeamento de campos Supabase (snake_case)
      const userId = user.uid;
      const fcmTokens = user.fcm_tokens; // Note: Ensure column name matches schema (fcm_tokens or fcmTokens)

      if (!fcmTokens || fcmTokens.length === 0) continue;

      // Buscar tarefas pendentes do dia
      const today = new Date();
      today.setHours(23, 59, 59, 999); // Final do dia para comparação <=

      // 'due_date' no banco deve ser Timestamp/Date
      const { count, error: taskError } = await supabase
        .schema('sincroapp')
        .from('tasks')
        .select('*', { count: 'exact', head: true }) // Count only
        .eq('user_id', userId) // Use 'user_id' FK (check schema, might be 'user_id' or 'uid')
        .eq('completed', false)
        .lte('due_date', today.toISOString());

      if (taskError) {
        console.error(`Erro ao buscar tarefas de ${userId}:`, taskError.message);
        continue;
      }

      const pendingCount = count || 0;

      if (pendingCount >= CONFIG.notifications.endOfDay.minTasks) {
        const body = `Você tem ${pendingCount} tarefa${pendingCount > 1 ? 's' : ''} pendente${pendingCount > 1 ? 's' : ''}. Que tal revisar antes de dormir?`;

        const result = await sendNotification(
          userId,
          fcmTokens,
          CONFIG.notifications.endOfDay.title,
          body,
          { type: 'end_of_day', route: '/tasks', pendingCount: String(pendingCount) }
        );

        totalSent += result.success;
        totalFailed += result.failed;
      }
    }

    const duration = ((Date.now() - startTime) / 1000).toFixed(2);
    console.log(`✅ Fim de dia concluído: ${totalSent} enviadas, ${totalFailed} falhas (${duration}s)`);

    await notifyN8n('daily_notifications_sent', {
      type: 'end_of_day',
      sent: totalSent,
      failed: totalFailed,
      duration
    });

  } catch (error) {
    console.error('❌ Erro nas notificações de fim de dia:', error);
  }
}

// ========================================
// JOB 2: NOTIFICAÇÃO DE DIA PESSOAL
// ========================================

async function sendPersonalDayNotifications() {
  if (!CONFIG.notifications.personalDay.enabled) return;

  console.log('\n✨ ===== INICIANDO NOTIFICAÇÕES DE DIA PESSOAL (SUPABASE) =====');
  const startTime = Date.now();

  let totalSent = 0;
  let totalFailed = 0;
  const today = new Date();

  try {
    const { data: users, error } = await supabase.schema('sincroapp').from('users').select('*');
    if (error) throw error;

    for (const user of users) {
      const fcmTokens = user.fcm_tokens;
      const birthDate = user.birth_date; // Assuming 'birth_date' column

      if (!fcmTokens || fcmTokens.length === 0) continue;
      if (!birthDate) continue;

      const personalDay = calculatePersonalDay(birthDate, today);
      const description = getPersonalDayDescription(personalDay);

      const result = await sendNotification(
        user.uid,
        fcmTokens,
        `${CONFIG.notifications.personalDay.title}: ${personalDay}`,
        description,
        {
          type: 'personal_day',
          route: '/numerology',
          personalDay: String(personalDay)
        }
      );

      totalSent += result.success;
      totalFailed += result.failed;
    }

    const duration = ((Date.now() - startTime) / 1000).toFixed(2);
    console.log(`✅ Dia pessoal concluído: ${totalSent} enviadas`);

    await notifyN8n('daily_notifications_sent', {
      type: 'personal_day',
      sent: totalSent,
      failed: totalFailed,
      duration
    });

  } catch (error) {
    console.error('❌ Erro nas notificações de dia pessoal:', error);
  }
}

// ========================================
// JOB 3: NOTIFICAÇÃO DE TAREFAS ATRASADAS
// ========================================

async function sendOverdueTasksNotifications() {
  if (!CONFIG.notifications.overdueTasks.enabled) return;

  console.log('\n⏰ ===== INICIANDO NOTIFICAÇÕES DE TAREFAS ATRASADAS (SUPABASE) =====');
  const startTime = Date.now();

  let totalSent = 0;
  let totalFailed = 0;

  try {
    const { data: users, error } = await supabase.schema('sincroapp').from('users').select('*');
    if (error) throw error;

    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - CONFIG.notifications.overdueTasks.minDays);

    for (const user of users) {
      const fcmTokens = user.fcm_tokens;
      if (!fcmTokens || fcmTokens.length === 0) continue;

      const { count, error: taskError } = await supabase
        .schema('sincroapp')
        .from('tasks')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', user.uid)
        .eq('completed', false)
        .lte('due_date', cutoffDate.toISOString());

      if (taskError) continue;

      const overdueCount = count || 0;

      if (overdueCount > 0) {
        const body = `Você tem ${overdueCount} tarefa${overdueCount > 1 ? 's' : ''} atrasada${overdueCount > 1 ? 's' : ''} há mais de ${CONFIG.notifications.overdueTasks.minDays} dias.`;

        const result = await sendNotification(
          user.uid,
          fcmTokens,
          CONFIG.notifications.overdueTasks.title,
          body,
          { type: 'overdue_tasks', route: '/tasks', overdueCount: String(overdueCount) }
        );

        totalSent += result.success;
        totalFailed += result.failed;
      }
    }

    console.log(`✅ Tarefas atrasadas concluído: ${totalSent} enviadas`);

  } catch (error) {
    console.error('❌ Erro nas notificações de tarefas atrasadas:', error);
  }
}

// ========================================
// AGENDAMENTO
// ========================================

console.log('🚀 SincroApp Notification Service iniciado (Supabase Edition)');
console.log(`📅 Timezone: ${CONFIG.timezone}`);

if (CONFIG.notifications.endOfDay.enabled) {
  cron.schedule(CONFIG.notifications.endOfDay.schedule, sendEndOfDayNotifications, {
    timezone: CONFIG.timezone
  });
}
if (CONFIG.notifications.personalDay.enabled) {
  cron.schedule(CONFIG.notifications.personalDay.schedule, sendPersonalDayNotifications, {
    timezone: CONFIG.timezone
  });
}
if (CONFIG.notifications.overdueTasks.enabled) {
  cron.schedule(CONFIG.notifications.overdueTasks.schedule, sendOverdueTasksNotifications, {
    timezone: CONFIG.timezone
  });
}

console.log('\n✨ Serviço pronto e aguardando testes...\n');
