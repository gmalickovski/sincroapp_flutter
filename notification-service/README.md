# SincroApp Notification Service

Serviço standalone para envio de notificações push via Firebase Cloud Messaging (FCM).

## Recursos

- 🌙 **Notificações de Fim de Dia** (21h) - Lembra tarefas pendentes
- ✨ **Notificações de Dia Pessoal** (8h) - Envia vibração numerológica do dia
- ⏰ **Alertas de Tarefas Atrasadas** (10h e 15h) - Notifica sobre tarefas muito atrasadas
- 🔄 **Limpeza Automática** - Remove tokens FCM inválidos
- 📡 **Integração n8n** - Envia eventos para automações externas

## Pré-requisitos

- Node.js 20+
- Conta Firebase com projeto configurado
- Service Account JSON do Firebase
- PM2 (opcional, para produção)

## Instalação

### 1. Baixar Service Account Key

1. Acesse: https://console.firebase.google.com/project/sincroapp-e9cda/settings/serviceaccounts/adminsdk
2. Clique em "Gerar nova chave privada"
3. Salve o arquivo como `serviceAccountKey.json` nesta pasta

### 2. Instalar Dependências

```bash
cd notification-service
npm install
```

### 3. Configurar (Opcional)

Edite `index.js` para ajustar horários e configurações:

```javascript
const CONFIG = {
  timezone: 'America/Sao_Paulo',
  n8nWebhook: 'https://n8n.studiomlk.com.br/webhook/sincroapp',
  notifications: {
    endOfDay: {
      enabled: true,
      schedule: '0 21 * * *', // Cron: 21h todo dia
      // ...
    },
    // ...
  }
};
```

## Uso

### Desenvolvimento (Local)

```bash
# Executar diretamente
npm start

# Ou com hot reload (nodemon)
npm run dev
```

### Produção (PM2)

```bash
# Iniciar
npm run pm2:start

# Ver logs
npm run pm2:logs

# Reiniciar
npm run pm2:restart

# Parar
npm run pm2:stop

# Remover
npm run pm2:delete
```

### Configurar PM2 para iniciar com sistema

```bash
pm2 startup
pm2 save
```

## Estrutura de Notificações

### 1. Fim de Dia (21h)

```json
{
  "notification": {
    "title": "🌙 Finalizando o dia",
    "body": "Você tem 3 tarefas pendentes. Que tal revisar antes de dormir?"
  },
  "data": {
    "type": "end_of_day",
    "route": "/tasks",
    "pendingCount": "3"
  }
}
```

### 2. Dia Pessoal (8h)

```json
{
  "notification": {
    "title": "✨ Vibração do seu Dia: 7",
    "body": "Dia de introspecção e espiritualidade. Reflita."
  },
  "data": {
    "type": "personal_day",
    "route": "/numerology",
    "personalDay": "7"
  }
}
```

### 3. Tarefas Atrasadas (10h e 15h)

```json
{
  "notification": {
    "title": "⏰ Tarefas Atrasadas",
    "body": "Você tem 5 tarefas atrasadas há mais de 2 dias."
  },
  "data": {
    "type": "overdue_tasks",
    "route": "/tasks",
    "overdueCount": "5"
  }
}
```

## Logs

### Ver logs em tempo real

```bash
# PM2
pm2 logs sincroapp-notifications

# Direto
npm start
```

### Exemplo de saída

```
🚀 SincroApp Notification Service iniciado
📅 Timezone: America/Sao_Paulo
📋 Jobs configurados:
  ✅ Fim de dia: 0 21 * * *
  ✅ Dia pessoal: 0 8 * * *
  ✅ Tarefas atrasadas: 0 10,15 * * *

✨ Serviço pronto e aguardando agendamentos...

🌙 ===== INICIANDO NOTIFICAÇÕES DE FIM DE DIA =====
📊 Total de usuários: 150
✅ Fim de dia concluído: 87 enviadas, 3 falhas (2.34s)
✅ Webhook n8n notificado: daily_notifications_sent
```

## Configuração de Tokens FCM

Os tokens FCM são armazenados no Firestore:

```
users/{userId}
  └── fcmTokens: ["token1", "token2", ...]
```

### Como o app registra tokens:

No Flutter app (`lib/main.dart` ou serviço dedicado):

```dart
import 'package:firebase_messaging/firebase_messaging.dart';

Future<void> registerFCMToken() async {
  final token = await FirebaseMessaging.instance.getToken();
  
  if (token != null) {
    await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .update({
        'fcmTokens': FieldValue.arrayUnion([token])
      });
  }
}
```

## Troubleshooting

### Tokens não são registrados

1. Verifique se o app Flutter está chamando `registerFCMToken()`
2. Verifique permissões de notificação no dispositivo
3. Veja logs do Firestore: `fcmTokens` deve ser um array

### Notificações não chegam

1. Verifique se o serviço está rodando: `pm2 status`
2. Veja logs: `pm2 logs sincroapp-notifications`
3. Teste manualmente via Firebase Console
4. Verifique se tokens são válidos

### Erros de autenticação

```
Error: Could not load the default credentials
```

**Solução**: Certifique-se de que `serviceAccountKey.json` existe na pasta

### Timezone incorreto

Edite `CONFIG.timezone` para sua região:

```javascript
timezone: 'America/Sao_Paulo', // BRT (UTC-3)
```

Lista completa: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones

## Integrações

### n8n Webhook

Eventos enviados para n8n:

```javascript
{
  event: 'daily_notifications_sent',
  timestamp: '2025-11-15T21:00:00.000Z',
  type: 'end_of_day',
  sent: 87,
  failed: 3,
  duration: '2.34'
}
```

Use para:
- Estatísticas de engajamento
- Alertas se muitas falhas
- Integração com dashboards
- Automações baseadas em horário

## Segurança

- ✅ `serviceAccountKey.json` está no `.gitignore`
- ✅ Tokens inválidos são removidos automaticamente
- ✅ Tratamento de erros para evitar crashes
- ✅ Graceful shutdown (SIGINT, SIGTERM)

## Performance

- Processa ~1000 usuários em ~3 segundos
- Usa batch requests quando possível
- Remove tokens inválidos para otimizar envios futuros
- Logs detalhados para monitoramento

## Monitoramento

### Healthcheck

Adicione endpoint HTTP (opcional):

```javascript
const express = require('express');
const app = express();

app.get('/health', (req, res) => {
  res.json({ status: 'ok', uptime: process.uptime() });
});

app.listen(3001, () => {
  console.log('Healthcheck: http://localhost:3001/health');
});
```

### Métricas PM2

```bash
pm2 monit  # Dashboard interativo
pm2 status # Status resumido
```

## Deploy

### Via PM2 (Recomendado)

```bash
# Na VPS
cd /var/www/sincroapp/notification-service
npm install --production
npm run pm2:start
pm2 save
```

### Via systemd (Alternativa)

Crie `/etc/systemd/system/sincroapp-notifications.service`:

```ini
[Unit]
Description=SincroApp Notification Service
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/var/www/sincroapp/notification-service
ExecStart=/usr/bin/node index.js
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

Ative:

```bash
sudo systemctl enable sincroapp-notifications
sudo systemctl start sincroapp-notifications
sudo systemctl status sincroapp-notifications
```

## TODO

- [ ] Adicionar endpoint HTTP para trigger manual
- [ ] Implementar rate limiting por usuário
- [ ] Adicionar suporte a temas de notificação
- [ ] Criar dashboard web de estatísticas
- [ ] Implementar A/B testing de mensagens
- [ ] Adicionar suporte a imagens/rich media
- [ ] Integrar com analytics (Google Analytics 4)

## Licença

MIT

## Suporte

Para dúvidas:
- **Email**: contato@sincroapp.com
- **GitHub Issues**: [sincroapp_flutter/issues](https://github.com/gmalickovski/sincroapp_flutter/issues)
