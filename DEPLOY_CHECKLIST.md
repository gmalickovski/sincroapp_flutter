# 🚀 Checklist de Deploy SincroApp

## 📋 Pré-Deploy

### Ambiente de Desenvolvimento
- [ ] Flutter instalado e atualizado (`flutter --version`)
- [ ] Node.js 20+ instalado (`node --version`)
- [ ] Firebase CLI instalado (`firebase --version`)
- [ ] Git configurado
- [ ] VS Code ou IDE de preferência configurada

### Credenciais e Acessos
- [ ] Logado no Firebase (`firebase login`)
- [ ] Projeto Firebase selecionado (`firebase use sincroapp-e9cda`)
- [ ] Service Account Key baixado (para notification service)
- [ ] Token PagBank obtido (quando disponível)
- [ ] Acesso SSH à VPS configurado
- [ ] Domínio registrado e DNS apontado para VPS

## 🏗️ Build e Testes

### Flutter App
- [ ] Dependências instaladas (`flutter pub get`)
- [ ] Código sem erros (`flutter analyze`)
- [ ] Testes passando (`flutter test`)
- [ ] Build web funciona (`flutter build web --release`)

### Firebase Functions
- [ ] Dependências instaladas (`cd functions && npm install`)
- [ ] Código sem erros (ESLint)
- [ ] Testes locais com emulators (`firebase emulators:start`)
- [ ] Variáveis de ambiente configuradas (`firebase functions:config:get`)

### Landing Page
- [ ] `firebase-config.js` com credenciais corretas
- [ ] `landing.html` testado localmente
- [ ] Scripts `landing.js` sem erros
- [ ] Responsividade testada (mobile, tablet, desktop)

## 🔐 Segurança

### Firebase
- [ ] Firestore Rules revisadas e testadas
- [ ] App Check configurado (debug tokens registrados)
- [ ] Auth providers habilitados (Google OAuth)
- [ ] Security Rules não permitem acesso público não intencional

### VPS
- [ ] SSH configurado com chave (sem senha)
- [ ] Firewall ativo (UFW) com portas corretas
- [ ] Usuário não-root criado (se aplicável)
- [ ] Fail2ban configurado (opcional)

## 🌐 Infraestrutura VPS

### Servidor
- [ ] Ubuntu 20.04+ instalado e atualizado
- [ ] Node.js 20+ instalado
- [ ] Nginx instalado
- [ ] PM2 instalado globalmente
- [ ] Certbot instalado

### Configuração
- [ ] Nginx configurado (`/etc/nginx/sites-available/sincroapp`)
- [ ] Symlink criado (`/etc/nginx/sites-enabled/sincroapp`)
- [ ] Nginx testado (`sudo nginx -t`)
- [ ] Nginx reiniciado (`sudo systemctl restart nginx`)

### SSL/HTTPS
- [ ] Certbot executado (`sudo certbot --nginx -d seu-dominio.com`)
- [ ] Certificado SSL válido
- [ ] HTTP redireciona para HTTPS
- [ ] Renovação automática configurada

## 📦 Deploy

### Landing Page e Flutter Web
- [ ] Build Flutter gerado (`build/web/`)
- [ ] Arquivos copiados para VPS (`/var/www/sincroapp/`)
- [ ] Permissões corretas (`chown www-data:www-data`)
- [ ] Landing page acessível (https://seu-dominio.com)
- [ ] Flutter app acessível (https://seu-dominio.com/app)

### Firebase Functions
- [ ] Deploy executado (`firebase deploy --only functions`)
- [ ] Functions ativas no Firebase Console
- [ ] Logs sem erros (`firebase functions:log`)
- [ ] Webhooks testados (n8n recebendo eventos)

### Notification Service
- [ ] Código copiado para VPS (`/var/www/sincroapp/notification-service/`)
- [ ] Service Account Key presente (`serviceAccountKey.json`)
- [ ] Dependências instaladas (`npm install --production`)
- [ ] PM2 iniciado (`pm2 start index.js --name sincroapp-notifications`)
- [ ] PM2 salvo (`pm2 save`)
- [ ] PM2 startup configurado (`pm2 startup`)
- [ ] Logs funcionando (`pm2 logs sincroapp-notifications`)

## ✅ Validação Pós-Deploy

### Landing Page
- [ ] Página carrega sem erros
- [ ] Login com Google funciona
- [ ] Novo usuário criado no Firestore
- [ ] Redirecionamento para app funciona
- [ ] Seleção de plano chama Cloud Function
- [ ] App Check não bloqueia requisições

### Flutter Web App
- [ ] App carrega corretamente
- [ ] Dashboard exibe dados do usuário
- [ ] Tarefas podem ser criadas
- [ ] Metas podem ser criadas (respeitando limites de plano)
- [ ] IA funciona (para planos compatíveis)
- [ ] Navegação entre telas funciona

### Firebase Functions
- [ ] `onNewUserDocumentCreate` dispara (novo usuário)
- [ ] `onUserUpdate` dispara (atualização de plano)
- [ ] `sendPushNotification` funciona (teste manual)
- [ ] `startWebCheckout` retorna URL (mock ou real)
- [ ] `pagbankWebhook` processa corretamente (quando ativo)

### Notificações
- [ ] Serviço PM2 rodando sem erros
- [ ] Cron jobs agendados corretamente
- [ ] Tokens FCM sendo registrados no Firestore
- [ ] Notificações chegam nos dispositivos (teste manual)
- [ ] Tokens inválidos sendo removidos

### Webhooks n8n
- [ ] n8n recebe evento de novo usuário
- [ ] n8n recebe evento de upgrade de plano
- [ ] n8n recebe evento de notificações enviadas
- [ ] n8n recebe evento de conta deletada

## 🔍 Monitoramento

### Logs
- [ ] Logs do Nginx: `/var/log/nginx/sincroapp-*.log`
- [ ] Logs do PM2: `pm2 logs sincroapp-notifications`
- [ ] Logs do Firebase Functions: `firebase functions:log`
- [ ] Logs do navegador (console) sem erros críticos

### Performance
- [ ] Tempo de carregamento < 3s (lighthouse)
- [ ] App Check não adiciona latência perceptível
- [ ] Firestore queries otimizadas (índices criados)
- [ ] Functions respondem em < 2s

### Segurança
- [ ] HTTPS ativo e funcionando
- [ ] Headers de segurança presentes (X-Frame-Options, etc)
- [ ] Firestore Rules testadas (não permite acesso não autorizado)
- [ ] App Check bloqueando requisições sem token válido

## 🐛 Troubleshooting Comum

### Landing Page não carrega
- [ ] Verificar logs Nginx: `sudo tail -f /var/log/nginx/error.log`
- [ ] Verificar permissões: `ls -la /var/www/sincroapp/`
- [ ] Testar Nginx config: `sudo nginx -t`

### Autenticação falha
- [ ] Verificar App Check no console do navegador
- [ ] Registrar debug token no Firebase Console
- [ ] Verificar credenciais em `firebase-config.js`

### Functions não respondem
- [ ] Verificar deploy: `firebase deploy --only functions`
- [ ] Verificar logs: `firebase functions:log`
- [ ] Testar localmente: `firebase emulators:start`

### Notificações não chegam
- [ ] Verificar PM2: `pm2 status`
- [ ] Verificar logs: `pm2 logs sincroapp-notifications`
- [ ] Verificar tokens no Firestore: `users/{uid}/fcmTokens`

## 📊 Métricas de Sucesso

### Semana 1
- [ ] 100% uptime
- [ ] 0 erros críticos
- [ ] Landing page com < 3s de carregamento
- [ ] Pelo menos 1 usuário de teste completo

### Mês 1
- [ ] Sistema de pagamento integrado (PagBank)
- [ ] Notificações funcionando para todos os usuários
- [ ] Feedback positivo de early adopters
- [ ] Analytics configurado (Google Analytics 4)

## 🎯 Próximos Passos Pós-Deploy

### Curto Prazo (1-2 semanas)
- [ ] Integrar API real do PagBank
- [ ] Adicionar Google Analytics 4
- [ ] Implementar sistema de cupons de desconto
- [ ] Criar dashboard de admin

### Médio Prazo (1-3 meses)
- [ ] Lançar apps iOS e Android
- [ ] Implementar In-App Purchase (iOS/Android)
- [ ] Adicionar mais providers de pagamento
- [ ] Sistema de afiliados/referrals

### Longo Prazo (3-6 meses)
- [ ] Integrações (Google Calendar, Notion, etc)
- [ ] Features premium avançadas
- [ ] API pública para desenvolvedores
- [ ] Programa de parceiros

---

**✨ Bom deploy! Marque os itens conforme forem concluídos.**
