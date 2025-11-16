# SincroApp

Aplicativo de autoconhecimento e produtividade que une numerologia, IA e organização pessoal em uma experiência integrada.

## 🌟 Visão Geral

SincroApp combina:
- **Numerologia** - Calcule seu Mapa Numerológico e entenda seus ciclos
- **Inteligência Artificial** - Sugestões personalizadas com Vertex AI (Google Gemini)
- **Produtividade** - Tarefas, metas/jornadas, calendário e diário reflexivo
- **Multiplataforma** - Flutter para Web, iOS e Android

## 🏗️ Tecnologias

- **Frontend**: Flutter 3.x
- **Backend**: Firebase (Firestore, Auth, Functions, App Check)
- **IA**: Vertex AI via Firebase AI SDK
- **Pagamentos**: PagBank (Web), In-App Purchase (Mobile)
- **Notificações**: Firebase Cloud Messaging + Serviço Node.js standalone
- **Hosting**: VPS (Nginx) + Firebase Hosting

## 📁 Estrutura do Projeto

```
sincro_app_flutter/
├── lib/                          # Código Flutter
│   ├── main.dart                 # Entry point
│   ├── app/                      # Rotas e tema
│   ├── common/                   # Constantes e utils
│   ├── features/                 # Features por módulo
│   │   ├── authentication/
│   │   ├── dashboard/
│   │   ├── tasks/
│   │   ├── goals/
│   │   ├── journal/
│   │   ├── calendar/
│   │   └── subscription/         # Sistema de assinaturas
│   ├── models/                   # Data models
│   └── services/                 # Serviços (Firebase, AI, etc)
│
├── web/                          # Landing Page + Web App
│   ├── landing.html              # Landing page principal
│   ├── landing.js                # Scripts da landing
│   ├── firebase-config.js        # Config Firebase
│   ├── index.html                # Flutter web (gerado)
│   └── README.md                 # Doc web
│
├── functions/                    # Firebase Cloud Functions
│   ├── index.js                  # Functions (webhooks, notificações, pagamento)
│   └── package.json
│
├── notification-service/         # Serviço de notificações standalone
│   ├── index.js                  # Cron jobs FCM
│   ├── package.json
│   └── README.md
│
├── android/                      # Código nativo Android
├── ios/                          # Código nativo iOS
├── test/                         # Testes unitários
│
├── firebase.json                 # Config Firebase
├── firestore.rules               # Regras de segurança Firestore
├── nginx.conf                    # Config Nginx para VPS
├── deploy.sh                     # Script de deploy
│
├── VPS_DEPLOY_GUIDE.md           # Guia de deploy VPS
├── IMPLEMENTACAO_WEB_RESUMO.md   # Resumo implementação web
└── README.md                     # Este arquivo
```

## 🚀 Quick Start

### Pré-requisitos

- Flutter 3.x
- Node.js 20+
- Firebase CLI
- Conta Firebase (projeto `sincroapp-e9cda`)

### Instalação

```bash
# 1. Clone o repositório
git clone https://github.com/gmalickovski/sincroapp_flutter.git
cd sincro_app_flutter

# 2. Instale dependências Flutter
flutter pub get

# 3. Instale dependências Functions
cd functions
npm install
cd ..

# 4. Instale dependências Notification Service (opcional)
cd notification-service
npm install
cd ..

# 5. Configure Firebase
firebase login
firebase use sincroapp-e9cda
```

### Desenvolvimento Local

```bash
# Terminal 1: Inicia emuladores Firebase
firebase emulators:start

# Terminal 2: Roda o app Flutter
flutter run -d chrome

# OU servir landing page
cd web
python -m http.server 8000
# Acessar: http://localhost:8000/landing.html
```

### Build para Produção

```bash
# Build Flutter Web
flutter build web --release --web-renderer canvaskit

# Deploy Functions
firebase deploy --only functions

# Deploy completo (via script)
chmod +x deploy.sh
./deploy.sh production
```

## 📱 Plataformas Suportadas

| Plataforma | Status | Detalhes |
|------------|--------|----------|
| Web | ✅ Pronto | Firebase Hosting ou VPS |
| Android | 🚧 Em desenvolvimento | Google Play Store |
| iOS | 🚧 Em desenvolvimento | App Store |

## 💎 Planos e Funcionalidades

### Sincro Essencial (Grátis)
- ✅ Até 1 meta/jornada ativa
- ✅ Tarefas ilimitadas
- ✅ Diário reflexivo
- ✅ Numerologia básica
- ❌ Sem assistente IA

### Sincro Despertar (R$ 19,90/mês)
- ✅ Até 5 metas/jornadas
- ✅ Tudo do Essencial
- ✅ Mapa numerológico completo
- ✅ 30 requisições IA/mês
- ✅ Customização do dashboard

### Sincro Sinergia (R$ 39,90/mês)
- ✅ Metas ilimitadas
- ✅ Tudo do Despertar
- ✅ IA ilimitada
- ✅ Insights diários personalizados
- ✅ Integração Google Calendar
- ✅ Suporte prioritário

## 🔐 Segurança

- **Firebase Auth** - Google OAuth
- **App Check** - Proteção contra bots
- **Firestore Rules** - Regras de segurança detalhadas
- **HTTPS** - SSL via Let's Encrypt
- **GDPR Compliance** - Função de exclusão de dados

## 🔔 Sistema de Notificações

O sistema de notificações funciona de duas formas:

1. **Cloud Functions** (Firebase) - Triggers automáticos
2. **Notification Service** (VPS) - Cron jobs agendados

### Notificações Implementadas

- **Dia Pessoal** (8h) - Vibração numerológica do dia
- **Fim de Dia** (21h) - Lembra tarefas pendentes
- **Tarefas Atrasadas** (10h e 15h) - Alertas de atraso

Ver `notification-service/README.md` para detalhes.

## 🌐 Deploy

### Opção 1: Firebase Hosting (Recomendado para prototipagem)

```bash
firebase deploy
```

### Opção 2: VPS com Nginx (Produção)

Ver guia completo em `VPS_DEPLOY_GUIDE.md`

**Resumo:**
1. Configurar VPS (Ubuntu 20.04+)
2. Instalar Nginx + Node.js + PM2
3. Configurar SSL (Certbot)
4. Deploy do código
5. Iniciar notification service

## 📊 Monitoramento

- **Firebase Console**: https://console.firebase.google.com/project/sincroapp-e9cda
- **Logs Functions**: `firebase functions:log`
- **Logs PM2**: `pm2 logs sincroapp-notifications`
- **n8n Webhook**: https://n8n.studiomlk.com.br/webhook/sincroapp

## 🧪 Testes

```bash
# Testes unitários
flutter test

# Testes de integração (quando implementados)
flutter test integration_test
```

## 📚 Documentação Adicional

- [VPS Deploy Guide](VPS_DEPLOY_GUIDE.md) - Setup completo da VPS
- [Web README](web/README.md) - Landing page e Firebase web
- [Notification Service README](notification-service/README.md) - Sistema de notificações
- [Implementação Web Resumo](IMPLEMENTACAO_WEB_RESUMO.md) - Resumo da implementação web

## 🛠️ Configuração de Ambiente

### Variáveis de Ambiente (Firebase Functions)

```bash
# Token PagBank
firebase functions:config:set pagbank.token="SEU_TOKEN"

# Webhook n8n
firebase functions:config:set n8n.webhook="https://n8n.studiomlk.com.br/webhook/sincroapp"

# reCAPTCHA v3
firebase functions:config:set recaptcha.sitekey="6LeC__ArAAAAAJUbYkba086MP-cCJBolbjLcm_uU"
```

### Service Account (Notification Service)

1. Baixe em: https://console.firebase.google.com/project/sincroapp-e9cda/settings/serviceaccounts/adminsdk
2. Salve como `notification-service/serviceAccountKey.json`

## 🤝 Contribuindo

1. Fork o projeto
2. Crie uma branch (`git checkout -b feature/NovaFuncionalidade`)
3. Commit suas mudanças (`git commit -m 'Adiciona nova funcionalidade'`)
4. Push para a branch (`git push origin feature/NovaFuncionalidade`)
5. Abra um Pull Request

## 📝 Licença

Este projeto é proprietário. Todos os direitos reservados.

## 👤 Autor

**gmalickovski**
- GitHub: [@gmalickovski](https://github.com/gmalickovski)
- Projeto: sincroapp_flutter

## 📞 Suporte

- **Email**: contato@sincroapp.com
- **Issues**: [GitHub Issues](https://github.com/gmalickovski/sincroapp_flutter/issues)

---

**✨ Transforme autoconhecimento em ação prática com SincroApp!**
