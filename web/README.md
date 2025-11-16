# SincroApp Web - Landing Page & Flutter App

Este diretório contém a landing page e o app Flutter compilado para web.

## Estrutura

```
web/
├── landing.html           # Landing page principal
├── landing.js             # Scripts da landing (auth, navegação, UI)
├── firebase-config.js     # Configuração e inicialização do Firebase
├── index.html             # Flutter app (gerado pelo build)
├── flutter_bootstrap.js   # Bootstrap do Flutter (gerado)
├── manifest.json          # PWA manifest
├── favicon.png            # Favicon
└── icons/                 # Ícones do PWA
```

## Recursos da Landing Page

### 1. **Autenticação Firebase**
- Login/Registro via Google Auth
- Detecção automática de ambiente (localhost vs produção)
- App Check configurado (debug token para localhost, reCAPTCHA v3 para produção)
- Criação automática de documento do usuário no Firestore

### 2. **Seleção de Planos**
- 3 planos: Essencial (grátis), Despertar (R$ 19,90), Sinergia (R$ 39,90)
- Botões de upgrade integrados com Cloud Functions
- Redirecionamento para checkout PagBank (web)
- Mensagens de "Em Breve" para mobile

### 3. **Integração com Firebase Functions**
- `startWebCheckout`: Inicia processo de pagamento
- `sendPushNotification`: Envia notificações push
- `pagbankWebhook`: Processa callbacks de pagamento

### 4. **UI/UX**
- Design responsivo (mobile-first)
- Animações com AOS (Animate On Scroll)
- Smooth scroll navigation
- FAQ accordion
- Loading states

## Como Usar Localmente

### 1. Configurar Firebase

Certifique-se de que o arquivo `firebase-config.js` tem as credenciais corretas do projeto:

```javascript
const firebaseConfig = {
  apiKey: "AIzaSyBDHpEm3FyKfOnzjJ6xLz8hLQV8DZrPqA0",
  authDomain: "sincroapp-e9cda.firebaseapp.com",
  projectId: "sincroapp-e9cda",
  // ...
};
```

### 2. Iniciar Emuladores Firebase (Opcional)

Para desenvolvimento local completo:

```bash
# Na raiz do projeto
firebase emulators:start
```

Isso iniciará:
- Firestore Emulator → `localhost:8081`
- Auth Emulator → `localhost:9098`
- Functions Emulator → `localhost:5002`

### 3. Servir Landing Page

Opção A - Servidor Python (simples):
```bash
cd web
python -m http.server 8000
```

Opção B - Live Server (VS Code):
1. Instale extensão "Live Server"
2. Clique direito em `landing.html` → "Open with Live Server"

Opção C - Firebase Hosting (mais próximo da produção):
```bash
firebase serve --only hosting
```

### 4. Acessar

Abra o navegador em:
- Landing Page: `http://localhost:8000/landing.html`
- Flutter App: `http://localhost:8000/` (após build)

## Debug App Check

Quando rodar localmente pela primeira vez:

1. Abra o console do navegador (F12)
2. Procure por: `Firebase App Check debug token: XXXX-XXXX-...`
3. Copie o token
4. Vá em: https://console.firebase.google.com/project/sincroapp-e9cda/appcheck
5. Adicione o token em "Debug tokens"

Isso permite que requisições locais passem pelo App Check.

## Build do Flutter Web

Para gerar a versão de produção do app Flutter:

```bash
# Na raiz do projeto
flutter build web --release --web-renderer canvaskit

# Os arquivos serão gerados em build/web/
# Copie-os para web/ se necessário
```

## Deploy para Produção

### Via Firebase Hosting

```bash
# Build
flutter build web --release

# Deploy
firebase deploy --only hosting
```

### Via VPS (Nginx)

Veja o guia completo em `VPS_DEPLOY_GUIDE.md`.

## Fluxo de Autenticação

```
1. Usuário clica em "Começar Grátis" ou "Entrar"
   ↓
2. Popup do Google Auth (Firebase)
   ↓
3. Callback com credenciais
   ↓
4. Verifica se usuário existe no Firestore
   ↓
   ├─ SIM → Redireciona para app
   └─ NÃO → Cria documento do usuário → Redireciona para app
```

## Fluxo de Pagamento (Web)

```
1. Usuário seleciona plano pago
   ↓
2. Verifica se está autenticado
   ↓
   ├─ NÃO → Registra primeiro
   └─ SIM → Continua
   ↓
3. Chama Cloud Function: startWebCheckout
   ↓
4. Function gera URL de checkout PagBank
   ↓
5. Redireciona usuário para PagBank
   ↓
6. Usuário paga
   ↓
7. PagBank chama webhook: pagbankWebhook
   ↓
8. Function atualiza Firestore: subscription.plan = 'plus'/'premium'
   ↓
9. Envia webhook para n8n (notificação)
```

## Variáveis de Ambiente

Configure no Firebase Functions:

```bash
# Token PagBank (quando disponível)
firebase functions:config:set pagbank.token="SEU_TOKEN"

# URL do n8n
firebase functions:config:set n8n.webhook="https://n8n.studiomlk.com.br/webhook/sincroapp"

# reCAPTCHA v3 Site Key (já está hardcoded, mas pode configurar)
firebase functions:config:set recaptcha.sitekey="6LeC__ArAAAAAJUbYkba086MP-cCJBolbjLcm_uU"
```

## Testes

### Testar Autenticação
1. Abra landing.html
2. Clique em "Começar Grátis"
3. Faça login com Google
4. Verifique console: `✅ Usuário autenticado: email@exemplo.com`
5. Verifique Firestore: novo documento em `users/{uid}`

### Testar Seleção de Plano
1. Faça login
2. Clique em "Assinar Agora" (plano Despertar)
3. Verifique console: `Plano selecionado: plus`
4. (Mock) Você verá URL de checkout fictícia

### Testar FAQ
1. Clique em qualquer pergunta
2. Resposta deve expandir com animação
3. Clicar novamente fecha

### Testar Navegação
1. Clique em links do menu (Funcionalidades, Planos, FAQ)
2. Página deve rolar suavemente
3. Item ativo no menu deve mudar de cor

## Segurança

- ✅ HTTPS obrigatório em produção (Certbot/Let's Encrypt)
- ✅ App Check ativo (protege contra bots)
- ✅ Firebase Auth com Google OAuth
- ✅ Firestore Security Rules (ver `firestore.rules`)
- ✅ Headers de segurança no Nginx (ver `VPS_DEPLOY_GUIDE.md`)

## Performance

- Otimizações aplicadas:
  - Gzip compression
  - Cache de assets estáticos (1 ano)
  - Lazy loading de imagens (se houver)
  - Minificação automática pelo Firebase Hosting
  - CDN global (Firebase Hosting)

## Troubleshooting

### "App Check token is invalid"
- Registre o debug token no Firebase Console
- Ou desative App Check temporariamente para testar

### "User not found after login"
- Verifique logs da Function no Firebase Console
- Verifique regras do Firestore
- Teste criação manual no Firestore

### Landing page não carrega Firebase
- Verifique se `firebase-config.js` está sendo carregado
- Verifique console por erros de CORS
- Verifique se CDN do Firebase está acessível

### Animações não funcionam
- Verifique se AOS CDN está carregado
- Verifique console por erros JavaScript
- Tente limpar cache do navegador

## TODO

- [ ] Implementar API real do PagBank (substituir mock)
- [ ] Adicionar screenshots reais do app na landing
- [ ] Implementar sistema de cupons de desconto
- [ ] Adicionar mais FAQs baseado em feedback
- [ ] Implementar chat de suporte (Tawk.to ou similar)
- [ ] A/B testing de CTAs
- [ ] Analytics (Google Analytics 4)
- [ ] Pixel de remarketing (Google Ads, Facebook)

## Suporte

Para dúvidas ou problemas:
- **Email**: contato@sincroapp.com
- **GitHub Issues**: [sincroapp_flutter/issues](https://github.com/gmalickovski/sincroapp_flutter/issues)
