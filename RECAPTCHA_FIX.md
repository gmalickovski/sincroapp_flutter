# 🔴 SOLUÇÃO DEFINITIVA: reCAPTCHA WAF → Site Key

## 🎯 PROBLEMA REAL IDENTIFICADO

A imagem mostra que a chave atual é do tipo:
```
Tipo de chave: Web Application Firewall (WAF)
```

**Isso está ERRADO!** App Check precisa de:
```
Tipo de chave: Site (reCAPTCHA v3)
```

---

## ✅ SOLUÇÃO COMPLETA

### 1. Criar NOVA Site Key (reCAPTCHA v3)

**Acesse:** https://www.google.com/recaptcha/admin/create

#### Configuração:

1. **Rótulo:** `sincroapp-check-web` (ou qualquer nome descritivo)

2. **Tipo de reCAPTCHA:** 
   - ✅ Selecione: **"reCAPTCHA v3"**
   - ❌ NÃO selecione: "Web Application Firewall (WAF)"
   - ❌ NÃO selecione: "reCAPTCHA v2"

3. **Domínios:**
   ```
   sincroapp.com.br
   www.sincroapp.com.br
   localhost
   ```

4. **Aceite os termos** e clique em **"Enviar"**

5. **COPIE as chaves geradas:**
   ```
   Site Key:   6LeXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX (NOVA)
   Secret Key: 6LeXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX (NOVA)
   ```

---

### 2. Atualizar Firebase Console App Check

**Acesse:** https://console.firebase.google.com/project/sincroapp-529cc/appcheck

1. Clique no app web `1:1011842661481:web:e85b3aa24464e12ae2b6f8`
2. Clique em **"Editar"** ou **"..."** → **"Configurações"**
3. **Substitua a Site Key antiga pela NOVA**
4. Salve

---

### 3. Atualizar Código Flutter

Abra o arquivo que define a constante `kReCaptchaSiteKey` e **substitua**:

**DE:**
```dart
const String kReCaptchaSiteKey = String.fromEnvironment(
  'RECAPTCHA_V3_SITE_KEY',
  defaultValue: '6LeC__ArAAAAAJUbYkba086MP-cCJBolbjLcm_uU', // ← ANTIGA (WAF)
);
```

**PARA:**
```dart
const String kReCaptchaSiteKey = String.fromEnvironment(
  'RECAPTCHA_V3_SITE_KEY',
  defaultValue: '6LeXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX', // ← NOVA (Site v3)
);
```

---

### 4. Rebuild e Deploy

```bash
# 1. Build local com nova site key
cd /c/dev/sincro_app_flutter

flutter clean
flutter pub get
flutter build web --release \
  --base-href /app/ \
  --dart-define=RECAPTCHA_V3_SITE_KEY=6LeXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

# 2. Commit e push
git add lib/main.dart
git commit -m "fix: Atualizar reCAPTCHA Site Key (WAF → v3)"
git push origin main

# 3. Deploy no VPS
ssh root@VPS_IP
cd /var/www/webapp/sincroapp_flutter/deploy
./update.sh
```

---

### 5. Atualizar deploy/update.sh

Editar a linha que define a variável `RECAPTCHA_V3_SITE_KEY`:

**DE:**
```bash
RECAPTCHA_V3_SITE_KEY="${RECAPTCHA_V3_SITE_KEY:-6LeC__ArAAAAAJUbYkba086MP-cCJBolbjLcm_uU}"
```

**PARA:**
```bash
RECAPTCHA_V3_SITE_KEY="${RECAPTCHA_V3_SITE_KEY:-6LeXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX}"
```

---

## 🧪 TESTE

Após deploy:

```bash
# 1. Abrir navegador incognito
# 2. Acessar: https://sincroapp.com.br/app/#/login
# 3. Abrir DevTools > Console
```

**✅ DEVE APARECER:**
```
✅ App Check ativado em MODO PRODUÇÃO
✅ Token App Check obtido com sucesso no startup
```

**❌ NÃO DEVE APARECER:**
```
POST exchangeRecaptchaV3Token 400
appCheck/initial-throttle
```

---

## 📝 DIFERENÇA: WAF vs Site (v3)

### WAF (Web Application Firewall):
- Usado em **edge layers** (Cloudflare, Akamai)
- Valida requests ANTES de chegarem ao servidor
- **NÃO FUNCIONA** com Firebase App Check diretamente

### Site (reCAPTCHA v3):
- Usado em **aplicações web** normais
- Integra com Firebase App Check
- Google analisa comportamento do usuário
- Score de 0.0 (bot) a 1.0 (humano)

---

## ⚠️ IMPORTANTE

Após criar a NOVA chave:

1. **NÃO DELETE a chave antiga WAF** - pode ser útil no futuro
2. A NOVA chave Site v3 pode coexistir com a WAF
3. Aguarde **5-10 minutos** após salvar no Firebase Console
4. O Nginx **NÃO interfere** - ele só roteia requests HTTP

---

## 🔗 LINKS ÚTEIS

- [Criar nova chave reCAPTCHA](https://www.google.com/recaptcha/admin/create)
- [Firebase Console - App Check](https://console.firebase.google.com/project/sincroapp-529cc/appcheck)
- [Diferença entre WAF e Site](https://cloud.google.com/recaptcha-enterprise/docs/choose-key-type)
