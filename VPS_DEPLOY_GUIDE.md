# SincroApp - Guia de Deploy VPS

Este documento descreve como configurar a VPS para hospedar o SincroApp Web, Firebase Functions e sistema de notificações.

## Arquitetura

```
VPS (Nginx + Node.js + PM2)
├── Landing Page (landing.html) → Porta 80/443
├── Flutter Web App (build/web/) → Porta 80/443
├── Firebase Functions → Firebase Hosting/Cloud Functions
└── Sistema de Notificações → Serviço Node.js local (opcional)
```

## Pré-requisitos

- VPS com Ubuntu 20.04+ (recomendado: 2GB RAM, 2 vCPU)
- Node.js 20+
- Nginx
- Certbot (para SSL/HTTPS)
- Firebase CLI
- PM2 (process manager)

## Passo 1: Preparar VPS

```bash
# Atualizar sistema
sudo apt update && sudo apt upgrade -y

# Instalar Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Instalar Nginx
sudo apt install -y nginx

# Instalar Certbot para SSL
sudo apt install -y certbot python3-certbot-nginx

# Instalar PM2 globalmente
sudo npm install -g pm2

# Instalar Firebase CLI
sudo npm install -g firebase-tools
```

## Passo 2: Configurar Nginx

Crie o arquivo `/etc/nginx/sites-available/sincroapp`:

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name seu-dominio.com www.seu-dominio.com;

    # Redireciona HTTP para HTTPS (será configurado pelo Certbot)
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name seu-dominio.com www.seu-dominio.com;

    # SSL será configurado pelo Certbot
    # ssl_certificate /etc/letsencrypt/live/seu-dominio.com/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/seu-dominio.com/privkey.pem;

    # Raiz do projeto
    root /var/www/sincroapp;
    index landing.html index.html;

    # Landing page
    location = / {
        try_files /landing.html =404;
    }

    # App Flutter (rota /app)
    location /app {
        alias /var/www/sincroapp/build/web;
        try_files $uri $uri/ /app/index.html;
    }

    # Assets estáticos
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Configurações de segurança
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Compressão Gzip
    gzip on;
    gzip_vary on;
    gzip_min_length 10240;
    gzip_proxied any;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/json application/javascript;
}
```

Ative o site:

```bash
sudo ln -s /etc/nginx/sites-available/sincroapp /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

## Passo 3: Configurar SSL com Let's Encrypt

```bash
sudo certbot --nginx -d seu-dominio.com -d www.seu-dominio.com
```

O Certbot irá:
- Obter certificado SSL
- Configurar automaticamente o Nginx
- Configurar renovação automática

## Passo 4: Deploy do Projeto

### 4.1 Build do Flutter Web

No seu ambiente de desenvolvimento:

```bash
cd /caminho/para/sincro_app_flutter

# Build otimizado para produção
flutter build web --release --web-renderer canvaskit

# Compactar build
tar -czf sincroapp-web.tar.gz build/web web/landing.html web/landing.js web/firebase-config.js
```

### 4.2 Transferir para VPS

```bash
# Upload via SCP
scp sincroapp-web.tar.gz user@seu-dominio.com:/tmp/

# Na VPS
ssh user@seu-dominio.com
cd /var/www
sudo mkdir -p sincroapp
sudo tar -xzf /tmp/sincroapp-web.tar.gz -C sincroapp
sudo chown -R www-data:www-data sincroapp
```

## Passo 5: Deploy Firebase Functions

### 5.1 Configurar Firebase

```bash
cd /caminho/para/sincro_app_flutter

# Login no Firebase
firebase login

# Selecionar projeto
firebase use sincroapp-e9cda

# Deploy das functions
firebase deploy --only functions
```

### 5.2 Configurar variáveis de ambiente

```bash
# Configurar token do PagBank (quando disponível)
firebase functions:config:set pagbank.token="SEU_TOKEN_AQUI"

# Configurar URL do n8n
firebase functions:config:set n8n.webhook="https://n8n.studiomlk.com.br/webhook/sincroapp"
```

## Passo 6: Sistema de Notificações (Opcional - Local)

Se quiser rodar notificações localmente na VPS ao invés de usar Cloud Functions:

### 6.1 Criar serviço de notificações

Crie `/var/www/sincroapp/notification-service.js`:

```javascript
const admin = require('firebase-admin');
const cron = require('node-cron');

// Inicializa Firebase Admin
const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const messaging = admin.messaging();

// Agenda notificações diárias às 21h
cron.schedule('0 21 * * *', async () => {
  console.log('🔔 Executando envio de notificações diárias...');
  
  try {
    const users = await db.collection('users').get();
    
    for (const userDoc of users.docs) {
      const userData = userDoc.data();
      const userId = userDoc.id;
      
      if (!userData.fcmTokens || userData.fcmTokens.length === 0) continue;
      
      // Verifica tarefas pendentes
      const tasks = await db.collection('users').doc(userId)
        .collection('tasks')
        .where('completed', '==', false)
        .where('dueDate', '<=', new Date())
        .get();
      
      if (!tasks.empty) {
        const message = {
          notification: {
            title: '🌙 Finalizando o dia',
            body: `Você tem ${tasks.size} tarefa(s) pendente(s)`
          },
          tokens: userData.fcmTokens
        };
        
        await messaging.sendMulticast(message);
        console.log(`✅ Notificação enviada para ${userId}`);
      }
    }
  } catch (error) {
    console.error('❌ Erro ao enviar notificações:', error);
  }
});

console.log('✅ Serviço de notificações iniciado');
```

### 6.2 Instalar dependências

```bash
cd /var/www/sincroapp
npm init -y
npm install firebase-admin node-cron
```

### 6.3 Configurar PM2

```bash
# Iniciar serviço
pm2 start notification-service.js --name sincroapp-notifications

# Configurar para iniciar com o sistema
pm2 startup
pm2 save

# Monitorar
pm2 logs sincroapp-notifications
```

## Passo 7: Configurar Firewall

```bash
# UFW (Uncomplicated Firewall)
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw enable
```

## Passo 8: Monitoramento

### 8.1 Logs do Nginx

```bash
# Access logs
sudo tail -f /var/log/nginx/access.log

# Error logs
sudo tail -f /var/log/nginx/error.log
```

### 8.2 Logs das Functions

```bash
# Via Firebase CLI
firebase functions:log

# Ou no Firebase Console
# https://console.firebase.google.com/project/sincroapp-e9cda/functions
```

### 8.3 PM2 (se usar notificações locais)

```bash
pm2 status
pm2 logs sincroapp-notifications
pm2 monit
```

## Manutenção

### Atualizar Flutter Web

```bash
# Build nova versão
flutter build web --release

# Upload e deploy
scp -r build/web/* user@seu-dominio.com:/var/www/sincroapp/build/web/
```

### Atualizar Functions

```bash
firebase deploy --only functions
```

### Renovar SSL (automático, mas pode forçar)

```bash
sudo certbot renew --dry-run
```

## Troubleshooting

### Erro 502 Bad Gateway
- Verifique se Nginx está rodando: `sudo systemctl status nginx`
- Verifique logs: `sudo tail -f /var/log/nginx/error.log`

### Functions não respondem
- Verifique logs: `firebase functions:log`
- Verifique se App Check está configurado corretamente
- Teste localmente: `firebase emulators:start`

### Notificações não chegam
- Verifique tokens FCM no Firestore
- Verifique logs do PM2: `pm2 logs sincroapp-notifications`
- Teste manualmente via Firebase Console

## URLs Importantes

- **Landing Page**: https://seu-dominio.com
- **App Flutter**: https://seu-dominio.com/app
- **Firebase Console**: https://console.firebase.google.com/project/sincroapp-e9cda
- **n8n Webhook**: https://n8n.studiomlk.com.br/webhook/sincroapp

## Contatos

- **Desenvolvedor**: gmalickovski
- **Projeto**: SincroApp
- **Repositório**: sincroapp_flutter
