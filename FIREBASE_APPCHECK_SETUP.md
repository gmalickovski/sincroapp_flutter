# Firebase App Check - Configuração Correta

## Status Atual (Conforme Firebase Console)

### Web (reCAPTCHA v3)
- **Nome da chave**: `sincroapp-check-web`
- **Site Key**: `6LeC__ArAAAAAJUbYkba086MP-cCJBolbjLcm_uU`
- **Status**: ✅ Registrado
- **Domínios autorizados**:
  - `sincroapp.com.br`
  - `localhost`
  - `127.0.0.1`

### Android
- **Nome da chave**: `SincroApp Android`
- **Package**: `com.example.sincro_app_flutter`
- **Status**: ⚠️ Sem atividade (ainda não configurado no app)

## ⚠️ Problema Identificado

O Firebase Console mostra: **"Desprotegido"**

> "Termine a configuração da chave: solicitar pontuações"
> 
> Para proteger totalmente seu site ou app, termine de configurar a chave. Sua chave está solicitando tokens (execuções), mas não está solicitando pontuações (avaliações).

### Solução

1. No Firebase Console > App Check > reCAPTCHA
2. Clique em "Editar chave reCAPTCHA sincroapp-check-web"
3. Role até **"Tipo de chave"**
4. **DESATIVE** a opção: "Desativar verificação de domínio"
5. Certifique-se de que está marcado: **reCAPTCHA v3** (não WAF, não teste)
6. Clique em "Atualizar chave"

## Configuração no Código

### 1. Firebase Config (landing - `web/firebase-config.js`)

```javascript
// Produção: usa reCAPTCHA v3
const appCheck = firebase.appCheck();
appCheck.activate(
  '6LeC__ArAAAAAJUbYkba086MP-cCJBolbjLcm_uU', // Site key
  true // Auto refresh
);
```

✅ **Status**: Correto (hardcoded, não precisa de env var)

### 2. Flutter App (`lib/main.dart`)

```dart
const String kReCaptchaSiteKey = String.fromEnvironment(
  'RECAPTCHA_V3_SITE_KEY',
  defaultValue: '6LeC__ArAAAAAJUbYkba086MP-cCJBolbjLcm_uU',
);

// Em release:
await FirebaseAppCheck.instance.activate(
  webProvider: ReCaptchaV3Provider(kReCaptchaSiteKey),
  androidProvider: AndroidProvider.playIntegrity,
  appleProvider: AppleProvider.appAttest,
);
```

✅ **Status**: Correto (usa dart-define ou default)

### 3. Build Command (VPS)

```bash
export RECAPTCHA_V3_SITE_KEY="6LeC__ArAAAAAJUbYkba086MP-cCJBolbjLcm_uU"
export DOMAIN="sincroapp.com.br"
export FIREBASE_PROJECT="sincroapp-e9cda"

sudo -E ./deploy/install.sh
```

## Domínios Autorizados

### Firebase Authentication
Certifique-se de adicionar em **Authentication > Settings > Authorized domains**:
- `sincroapp.com.br`
- `www.sincroapp.com.br` (se usar)

### reCAPTCHA v3 Console
No [Google Cloud Console > reCAPTCHA](https://console.cloud.google.com/security/recaptcha):
- Adicione `sincroapp.com.br` aos domínios
- Não precisa de `www` se fizer redirect

## Testando

### Local (Development)
1. O Firebase Config detecta `localhost` automaticamente
2. Usa debug token: `self.FIREBASE_APPCHECK_DEBUG_TOKEN = true`
3. Não faz verificação real

### Produção
1. Acesse `https://sincroapp.com.br`
2. Abra DevTools > Console
3. Procure por: `🚀 Modo PRODUÇÃO: Usando reCAPTCHA v3`
4. **Não deve haver erros** de App Check 403

### Se houver 403/Throttling
```javascript
// No console do navegador:
// 1. Limpar site data
// 2. Ou usar aba anônima
// 3. Aguardar 24h para resetar throttle
```

## Checklist de Deploy

- [x] Site key correta em `firebase-config.js`: `6LeC__ArAAAAAJUbYkba086MP-cCJBolbjLcm_uU`
- [x] Site key correta em `main.dart` (default): `6LeC__ArAAAAAJUbYkba086MP-cCJBolbjLcm_uU`
- [ ] Firebase Console: domínio `sincroapp.com.br` adicionado à chave reCAPTCHA
- [ ] Firebase Console: opção "Desativar verificação de domínio" está **DESATIVADA**
- [ ] Firebase Auth: `sincroapp.com.br` em authorized domains
- [ ] VPS: variável `RECAPTCHA_V3_SITE_KEY` exportada antes do install
- [ ] Build gerado com `--base-href /app/`
- [ ] Nginx servindo landing em `/` e app em `/app/`
- [ ] SSL ativo (certbot/letsencrypt)

## Troubleshooting

### Erro: "App Check token is invalid"
- Verifique se a site key está correta em ambos os lugares
- Certifique-se de que o domínio está autorizado no Firebase Console

### Erro: "403 Forbidden" no App Check
- Limpe cache do navegador
- Use aba anônima
- Aguarde 24h se estiver throttled
- Verifique se domínio está na lista

### Status "Desprotegido" no Console
- Edite a chave reCAPTCHA
- **Desative** "Desativar verificação de domínio"
- Salve e aguarde alguns minutos

## Referências

- [Firebase App Check Docs](https://firebase.google.com/docs/app-check)
- [reCAPTCHA v3 Docs](https://developers.google.com/recaptcha/docs/v3)
- [Firebase JS SDK - App Check](https://firebase.google.com/docs/reference/js/app-check)
