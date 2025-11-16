/**
 * SincroApp - Notification Service
 * Serviço standalone para envio de notificações push (FCM)
 * Roda na VPS junto com o sistema web
 * 
 * Funcionalidades:
 * 1. Notificações diárias de fim de dia (21h BRT)
 * 2. Notificações de dia pessoal (8h BRT)
 * 3. Lembretes de tarefas vencidas
 * 4. Insights baseados em numerologia
 */

const admin = require('firebase-admin');
const cron = require('node-cron');
const axios = require('axios');

// ========================================
// CONFIGURAÇÃO
// ========================================

// Carrega service account (baixe do Firebase Console)
const serviceAccount = require('./serviceAccountKey.json');

// Inicializa Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://sincroapp-e9cda.firebaseio.com'
});

const db = admin.firestore();
const messaging = admin.messaging();

// Configurações
const CONFIG = {
  timezone: 'America/Sao_Paulo',
  n8nWebhook: 'https://n8n.studiomlk.com.br/webhook/sincroapp',
  notifications: {
    endOfDay: {
      enabled: true,
      schedule: '0 21 * * *', // 21h todo dia
      title: '🌙 Finalizando o dia',
      minTasks: 1 // Só notifica se tiver pelo menos 1 tarefa pendente
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
      minDays: 2 // Só notifica se atrasado por 2+ dias
    }
  }
};

// ========================================
// HELPER: CÁLCULO NUMEROLÓGICO
// ========================================

/**
 * Calcula o Dia Pessoal para uma data específica
 */
function calculatePersonalDay(birthDate, targetDate) {
  // Parse data de nascimento (formato: dd/mm/yyyy)
  const [day, month, year] = birthDate.split('/').map(Number);
  
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

/**
 * Retorna descrição curta do dia pessoal
 */
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

/**
 * Envia notificação para um usuário
 */
async function sendNotification(userId, tokens, title, body, data = {}) {
  if (!tokens || tokens.length === 0) {
    console.log(`⚠️ Usuário ${userId} sem tokens FCM`);
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
    
    // Remove tokens inválidos
    if (response.failureCount > 0) {
      const tokensToRemove = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          tokensToRemove.push(tokens[idx]);
        }
      });
      
      if (tokensToRemove.length > 0) {
        await db.collection('users').doc(userId).update({
          fcmTokens: admin.firestore.FieldValue.arrayRemove(...tokensToRemove)
        });
        console.log(`🗑️ Removidos ${tokensToRemove.length} tokens inválidos`);
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

/**
 * Notifica webhook n8n sobre evento
 */
async function notifyN8n(event, data) {
  try {
    await axios.post(CONFIG.n8nWebhook, {
      event,
      timestamp: new Date().toISOString(),
      ...data
    });
    console.log(`✅ Webhook n8n notificado: ${event}`);
  } catch (error) {
    console.error(`❌ Erro ao notificar n8n:`, error.message);
  }
}

// ========================================
// JOB 1: NOTIFICAÇÃO DE FIM DE DIA
// ========================================

async function sendEndOfDayNotifications() {
  if (!CONFIG.notifications.endOfDay.enabled) return;
  
  console.log('\n🌙 ===== INICIANDO NOTIFICAÇÕES DE FIM DE DIA =====');
  const startTime = Date.now();
  
  let totalSent = 0;
  let totalFailed = 0;
  
  try {
    const usersSnapshot = await db.collection('users').get();
    console.log(`📊 Total de usuários: ${usersSnapshot.size}`);
    
    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();
      const userId = userDoc.id;
      
      // Verifica se tem tokens
      if (!userData.fcmTokens || userData.fcmTokens.length === 0) continue;
      
      // Busca tarefas pendentes do dia
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      
      const tasksSnapshot = await db.collection('users').doc(userId)
        .collection('tasks')
        .where('completed', '==', false)
        .where('dueDate', '<=', admin.firestore.Timestamp.fromDate(today))
        .get();
      
      const pendingCount = tasksSnapshot.size;
      
      if (pendingCount >= CONFIG.notifications.endOfDay.minTasks) {
        const body = `Você tem ${pendingCount} tarefa${pendingCount > 1 ? 's' : ''} pendente${pendingCount > 1 ? 's' : ''}. Que tal revisar antes de dormir?`;
        
        const result = await sendNotification(
          userId,
          userData.fcmTokens,
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
    
    // Notifica n8n
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
  
  console.log('\n✨ ===== INICIANDO NOTIFICAÇÕES DE DIA PESSOAL =====');
  const startTime = Date.now();
  
  let totalSent = 0;
  let totalFailed = 0;
  const today = new Date();
  
  try {
    const usersSnapshot = await db.collection('users').get();
    console.log(`📊 Total de usuários: ${usersSnapshot.size}`);
    
    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();
      const userId = userDoc.id;
      
      // Verifica se tem tokens e data de nascimento
      if (!userData.fcmTokens || userData.fcmTokens.length === 0) continue;
      if (!userData.dataNasc) continue;
      
      // Calcula dia pessoal
      const personalDay = calculatePersonalDay(userData.dataNasc, today);
      const description = getPersonalDayDescription(personalDay);
      
      const result = await sendNotification(
        userId,
        userData.fcmTokens,
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
    console.log(`✅ Dia pessoal concluído: ${totalSent} enviadas, ${totalFailed} falhas (${duration}s)`);
    
    // Notifica n8n
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
  
  console.log('\n⏰ ===== INICIANDO NOTIFICAÇÕES DE TAREFAS ATRASADAS =====');
  const startTime = Date.now();
  
  let totalSent = 0;
  let totalFailed = 0;
  
  try {
    const usersSnapshot = await db.collection('users').get();
    console.log(`📊 Total de usuários: ${usersSnapshot.size}`);
    
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - CONFIG.notifications.overdueTasks.minDays);
    
    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();
      const userId = userDoc.id;
      
      if (!userData.fcmTokens || userData.fcmTokens.length === 0) continue;
      
      // Busca tarefas muito atrasadas
      const overdueSnapshot = await db.collection('users').doc(userId)
        .collection('tasks')
        .where('completed', '==', false)
        .where('dueDate', '<=', admin.firestore.Timestamp.fromDate(cutoffDate))
        .get();
      
      const overdueCount = overdueSnapshot.size;
      
      if (overdueCount > 0) {
        const body = `Você tem ${overdueCount} tarefa${overdueCount > 1 ? 's' : ''} atrasada${overdueCount > 1 ? 's' : ''} há mais de ${CONFIG.notifications.overdueTasks.minDays} dias.`;
        
        const result = await sendNotification(
          userId,
          userData.fcmTokens,
          CONFIG.notifications.overdueTasks.title,
          body,
          { type: 'overdue_tasks', route: '/tasks', overdueCount: String(overdueCount) }
        );
        
        totalSent += result.success;
        totalFailed += result.failed;
      }
    }
    
    const duration = ((Date.now() - startTime) / 1000).toFixed(2);
    console.log(`✅ Tarefas atrasadas concluído: ${totalSent} enviadas, ${totalFailed} falhas (${duration}s)`);
    
  } catch (error) {
    console.error('❌ Erro nas notificações de tarefas atrasadas:', error);
  }
}

// ========================================
// AGENDAMENTO
// ========================================

console.log('🚀 SincroApp Notification Service iniciado');
console.log(`📅 Timezone: ${CONFIG.timezone}`);
console.log('📋 Jobs configurados:');

// Job 1: Fim de dia (21h)
if (CONFIG.notifications.endOfDay.enabled) {
  cron.schedule(CONFIG.notifications.endOfDay.schedule, sendEndOfDayNotifications, {
    timezone: CONFIG.timezone
  });
  console.log(`  ✅ Fim de dia: ${CONFIG.notifications.endOfDay.schedule}`);
}

// Job 2: Dia pessoal (8h)
if (CONFIG.notifications.personalDay.enabled) {
  cron.schedule(CONFIG.notifications.personalDay.schedule, sendPersonalDayNotifications, {
    timezone: CONFIG.timezone
  });
  console.log(`  ✅ Dia pessoal: ${CONFIG.notifications.personalDay.schedule}`);
}

// Job 3: Tarefas atrasadas (10h e 15h)
if (CONFIG.notifications.overdueTasks.enabled) {
  cron.schedule(CONFIG.notifications.overdueTasks.schedule, sendOverdueTasksNotifications, {
    timezone: CONFIG.timezone
  });
  console.log(`  ✅ Tarefas atrasadas: ${CONFIG.notifications.overdueTasks.schedule}`);
}

console.log('\n✨ Serviço pronto e aguardando agendamentos...\n');

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\n👋 Encerrando serviço de notificações...');
  process.exit(0);
});

process.on('SIGTERM', () => {
  console.log('\n👋 Encerrando serviço de notificações...');
  process.exit(0);
});
