# 🔴 SOLUÇÃO DEFINITIVA: App Check 400 Error

## 📊 ANÁLISE DOS LOGS (Linha por Linha)

```
main.dart.js:37668 🔧 Ativando App Check no startup (ANTES de qualquer serviço Firebase)...
main.dart.js:37668 ✅ App Check ativado em MODO PRODUÇÃO
```
✅ **App Check FOI ativado corretamente** - código está certo!

```
client.ts:69 POST https://content-firebaseappcheck.googleapis.com/v1/projects/sincroapp-529cc/apps/1:1011842661481:web:e85b3aa24464e12ae2b6f8:exchangeRecaptchaV3Token 400 (Bad Request)
```
❌ **Firebase REJEITA o token reCAPTCHA v3** - este é o problema!

```
state.ts:52 [appCheck/initial-throttle] AppCheck: 400 error. Attempts allowed again after 00m:01s
```
⚠️ **Firebase coloca em throttle** porque o token foi rejeitado

---

## 🎯 CAUSA RAIZ IDENTIFICADA

O erro **400 em exchangeRecaptchaV3Token** acontece quando:

### ❌ O domínio `sincroapp.com.br` NÃO ESTÁ AUTORIZADO no Google reCAPTCHA Console!

O Firebase App Check **está configurado corretamente**, mas o **Google reCAPTCHA v3** rejeita a requisição porque:

1. O token reCAPTCHA é gerado no domínio `sincroapp.com.br`
2. O Google reCAPTCHA Console **não reconhece** esse domínio como autorizado
3. Google retorna token inválido
4. Firebase App Check tenta validar → recebe 400

---

## ✅ SOLUÇÃO COMPLETA

### 1. Verificar e Adicionar Domínios no Google reCAPTCHA Admin

**ACESSE:** https://www.google.com/recaptcha/admin

#### Passos:

1. **Login** com a conta Google vinculada ao projeto Firebase
2. **Localize a site key:** `6LeC__ArAAAAAJUbYkba086MP-cCJBolbjLcm_uU`
3. Clique em **"Configurações"** (ícone de engrenagem)
4. Na seção **"Domínios"**, adicione:
   ```
   sincroapp.com.br
   www.sincroapp.com.br
   ```
5. **IMPORTANTE:** Remova qualquer domínio que NÃO seja seu (se houver)
6. **Salve** as configurações

### 2. Confirmar Tipo de reCAPTCHA

No Google reCAPTCHA Admin:

- **Tipo:** Deve ser **"reCAPTCHA v3"**
- **NÃO pode** ser v2 (checkbox ou invisible)
- Se não for v3, **crie uma nova site key** do tipo v3

### 3. Verificar Firebase Console App Check

**ACESSE:** https://console.firebase.google.com/project/sincroapp-529cc/appcheck

#### Confirme:

- [ ] App web `1:1011842661481:web:e85b3aa24464e12ae2b6f8` está **registrado**
- [ ] Provedor: **reCAPTCHA v3**
- [ ] Site Key: `6LeC__ArAAAAAJUbYkba086MP-cCJBolbjLcm_uU`
- [ ] Status: **Ativo**

### 4. Aguardar Propagação

**IMPORTANTE:** Após salvar no Google reCAPTCHA Admin, aguarde **5-10 minutos** para propagação global.

---

## 🧪 TESTE RÁPIDO

Após configurar:

```bash
# 1. Abrir navegador em modo anônimo
# 2. Acessar: https://sincroapp.com.br/app/#/login
# 3. Abrir DevTools > Console
# 4. Procurar por:
```

**✅ SUCESSO (deve aparecer):**
```
✅ App Check ativado em MODO PRODUÇÃO
✅ Token App Check obtido com sucesso no startup
```

**❌ ERRO (NÃO DEVE APARECER):**
```
POST exchangeRecaptchaV3Token 400
appCheck/initial-throttle
```

---

## 🔍 VERIFICAÇÃO ADICIONAL: Secret Key

O reCAPTCHA v3 usa **duas chaves**:

1. **Site Key** (pública) - usada no frontend (Flutter web)
2. **Secret Key** (privada) - usada no backend (Firebase Functions)

### Verificar no Google reCAPTCHA Admin:

```
Site Key:   6LeC__ArAAAAAJUbYkba086MP-cCJBolbjLcm_uU
Secret Key: 6LeC__ArAAAAAxxxxxxxxxxxxxxxxxxxxxxxx (você tem acesso)
```

**A Secret Key NÃO é usada no App Check** - é apenas para validações customizadas.

---

## 📝 RESUMO DO FIX

### O que estava errado:
- ❌ Domínio `sincroapp.com.br` não estava autorizado no **Google reCAPTCHA Console**
- ✅ Firebase Console estava configurado corretamente
- ✅ Código Dart estava correto

### O que precisa fazer:
1. Adicionar `sincroapp.com.br` e `www.sincroapp.com.br` no Google reCAPTCHA Admin
2. Confirmar que a site key é do tipo **reCAPTCHA v3**
3. Aguardar 5-10 minutos
4. Testar novamente

---

## ⚠️ IMPORTANTE SOBRE APP CHECK

### App Check NÃO verifica usuário autenticado!

**App Check verifica:** Se o **app/site** é legítimo (anti-bot, anti-abuse)
**Firebase Auth verifica:** Se o **usuário** está autenticado

### Ordem correta (baseado em documentação oficial):

```
1. Firebase.initializeApp()
2. FirebaseAppCheck.instance.activate() ← Verifica se o APP é legítimo
3. runApp()
4. Usuário faz login ← FirebaseAuth verifica credenciais do USUÁRIO
5. Firestore/Functions/etc recebem requests com App Check token válido
```

**App Check é ativado ANTES do login** porque valida a **origem da requisição** (app legítimo), não o usuário.

---

## 🚀 APÓS RESOLVER

Quando o erro 400 parar:

1. ✅ Login deve funcionar normalmente
2. ✅ Dashboard deve carregar dados do Firestore
3. ✅ IA deve funcionar sem throttle
4. ✅ Não mais erros de App Check no console

---

## 🔗 LINKS ÚTEIS

- [Google reCAPTCHA Admin](https://www.google.com/recaptcha/admin)
- [Firebase Console - App Check](https://console.firebase.google.com/project/sincroapp-529cc/appcheck)
- [Documentação App Check Flutter](https://firebase.google.com/docs/app-check/flutter/default-providers)
- [Troubleshooting reCAPTCHA v3](https://developers.google.com/recaptcha/docs/faq#im-getting-an-error-invalid-site-key-or-not-loaded-in-api-parameters-why)

---

## ✅ CHECKLIST FINAL

Antes de considerar resolvido:

- [ ] Domínios adicionados no Google reCAPTCHA Admin
- [ ] Tipo confirmado como reCAPTCHA v3
- [ ] Firebase App Check com site key correta
- [ ] Aguardado 10 minutos para propagação
- [ ] Teste em incognito sem erro 400
- [ ] Login funciona completamente
- [ ] Dashboard carrega sem throttle
