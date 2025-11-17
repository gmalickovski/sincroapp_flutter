# ⚠️ FIREBASE APP CHECK - CONFIGURAÇÃO OBRIGATÓRIA

## 🚨 PROBLEMA ATUAL
Erro 400 em `exchangeRecaptchaV3Token` indica que o **Firebase App Check não reconhece o token reCAPTCHA v3**.

### Logs do Erro:
```
POST https://content-firebaseappcheck.googleapis.com/v1/projects/sincroapp-529cc/apps/1:1011842661481:web:e85b3aa24464e12ae2b6f8:exchangeRecaptchaV3Token 400 (Bad Request)
AppCheck: 400 error. Attempts allowed again after 00m:01s (appCheck/initial-throttle).
```

---

## ✅ SOLUÇÃO: Configurar Firebase Console

### 1. Acesse o Firebase Console
https://console.firebase.google.com/project/sincroapp-529cc/appcheck

### 2. Registrar o App Web com reCAPTCHA v3

**IMPORTANTE:** O app **NÃO PODE** ser registrado antes no App Check. Se já estiver, **delete o registro existente** e recrie.

#### Passo a Passo:

1. **Clique em "Adicionar app"** ou selecione o app web `1:1011842661481:web:e85b3aa24464e12ae2b6f8`

2. **Escolha "reCAPTCHA v3"** como provedor

3. **Insira a Site Key reCAPTCHA v3:**
   ```
   6LeC__ArAAAAAJUbYkba086MP-cCJBolbjLcm_uU
   ```

4. **Configure TTL do Token** (opcional):
   - Recomendado: **1 hora** (3600 segundos)
   - Padrão: 1 hora
   - Mínimo: 30 minutos
   - Máximo: 7 dias

5. **CRÍTICO: Adicione os domínios autorizados:**
   - `sincroapp.com.br`
   - `www.sincroapp.com.br`
   - `localhost` (para desenvolvimento local)

6. **Salve a configuração**

---

### 3. Verificar Site Key no Google reCAPTCHA

Acesse: https://www.google.com/recaptcha/admin

1. **Selecione o site** com a chave `6LeC__ArAAAAAJUbYkba086MP-cCJBolbjLcm_uU`

2. **Verifique "Domínios"** - devem incluir:
   - `sincroapp.com.br`
   - `www.sincroapp.com.br`

3. **Tipo:** Deve ser **reCAPTCHA v3**

4. Se os domínios não estiverem listados, **adicione-os** e salve

---

### 4. Ativar App Check Enforcement (IMPORTANTE)

**⚠️ CUIDADO:** Só ative após confirmar que o app está registrado corretamente!

No Firebase Console > App Check:

1. Acesse a aba **"Apps"**
2. Localize seu app web
3. Clique em **"Gerenciar"** ou **"..."** (três pontos)
4. Vá para **"Produtos do Firebase"** (aba lateral)
5. **Cloud Firestore:** Clique em **"Aplicar"** → **"Ativar aplicação obrigatória"**
6. **Firebase Authentication:** Clique em **"Aplicar"** → **"Ativar aplicação obrigatória"**
7. **Cloud Functions:** Clique em **"Aplicar"** → **"Ativar aplicação obrigatória"**
8. **Vertex AI (firebase_ai):** Clique em **"Aplicar"** → **"Ativar aplicação obrigatória"**

**Opção alternativa:** Use **"Monitorar"** em vez de "Aplicar" para testar sem bloquear requests inválidos.

---

### 5. Verificar Configuração

Após salvar no Firebase Console, **aguarde 5-10 minutos** para propagação.

Teste no navegador (incognito):
1. Abra: https://sincroapp.com.br/app/#/login
2. Abra DevTools > Console
3. Procure por:
   ```
   ✅ App Check ativado em MODO PRODUÇÃO
   ✅ Token App Check obtido com sucesso no startup
   ```
4. **NÃO DEVE APARECER:**
   ```
   ❌ POST exchangeRecaptchaV3Token 400
   ❌ appCheck/initial-throttle
   ```

---

## 📋 CHECKLIST DE VALIDAÇÃO

Antes de fazer deploy:

- [ ] App web registrado no Firebase Console > App Check
- [ ] Provedor: **reCAPTCHA v3**
- [ ] Site Key: `6LeC__ArAAAAAJUbYkba086MP-cCJBolbjLcm_uU`
- [ ] Domínios autorizados no Firebase: `sincroapp.com.br`, `www.sincroapp.com.br`
- [ ] Domínios autorizados no Google reCAPTCHA Console
- [ ] App Check enforcement **ATIVADO** para Firestore, Auth, Functions, Vertex AI
- [ ] Build Flutter contém a Site Key correta:
  ```bash
  flutter build web --release --base-href /app/ \
    --dart-define=RECAPTCHA_V3_SITE_KEY=6LeC__ArAAAAAJUbYkba086MP-cCJBolbjLcm_uU
  ```
- [ ] Teste em incognito: Login funciona sem 400 errors
- [ ] Dashboard carrega dados do Firestore sem throttle
- [ ] IA funciona sem 400 errors

---

## 🔍 DEBUG: Modo de Teste (Localhost)

Para testar **localmente** com debug tokens:

1. No Firebase Console > App Check > Apps > Web App
2. Clique em **"Gerenciar tokens de depuração"**
3. Copie o token exibido no console do browser ao acessar `http://localhost:PORT`
4. Adicione o token na lista de **"Tokens de depuração"**
5. O token é salvo no localStorage do navegador

**No código:** O modo `kDebugMode` já usa `AndroidProvider.debug` e `AppleProvider.debug` - não precisa alterar.

---

## 🛠️ COMANDOS ÚTEIS

### Rebuild do app com Site Key correta:
```bash
cd /c/dev/sincro_app_flutter
flutter clean
flutter pub get
flutter build web --release \
  --base-href /app/ \
  --dart-define=RECAPTCHA_V3_SITE_KEY=6LeC__ArAAAAAJUbYkba086MP-cCJBolbjLcm_uU
```

### Deploy no VPS:
```bash
ssh root@VPS_IP
cd /var/www/webapp/sincroapp_flutter/deploy
./update.sh
```

---

## 📚 REFERÊNCIAS

- [Firebase App Check - Flutter](https://firebase.google.com/docs/app-check/flutter/default-providers)
- [reCAPTCHA v3 Documentation](https://developers.google.com/recaptcha/docs/v3)
- [Firebase Console - App Check](https://console.firebase.google.com/project/sincroapp-529cc/appcheck)
- [Google reCAPTCHA Admin](https://www.google.com/recaptcha/admin)

---

## ⚡ RESUMO DO FIX

**Causa raiz:** Firebase Console não reconhece o app web porque **não foi registrado na seção App Check**.

**Solução:** Registrar o app web no Firebase Console > App Check com:
- Provedor: **reCAPTCHA v3**
- Site Key: `6LeC__ArAAAAAJUbYkba086MP-cCJBolbjLcm_uU`
- Domínios: `sincroapp.com.br`, `www.sincroapp.com.br`

**Código já está correto** - não precisa alterar `main.dart`.

---

## ✅ PRÓXIMOS PASSOS

1. **VOCÊ:** Acesse Firebase Console e registre o app conforme instruções acima
2. **AGUARDE:** 5-10 minutos para propagação
3. **TESTE:** Acesse https://sincroapp.com.br/app/#/login em incognito
4. **VALIDE:** Login deve funcionar sem 400 errors
5. **NOTIFIQUE:** Confirme quando estiver funcionando para ativar enforcement
