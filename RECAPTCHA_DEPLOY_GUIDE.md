# 🚀 Deploy reCAPTCHA Enterprise - Guia Rápido

## ✅ O que foi implementado

Para resolver o status **"Desprotegido"** no Firebase Console, implementamos:

1. **Server-side validation** das pontuações reCAPTCHA
2. **Endpoint HTTP** `validateRecaptcha` que gera assessments
3. **Integração na landing** para chamar validação no checkout
4. **Proteção nas Cloud Functions** sensíveis (startWebCheckout)

## 📦 Passos para Deploy na VPS

### 1. Parar PM2 (Serviço de Notificações)

```bash
sudo pm2 stop sincroapp-notifications
sudo pm2 delete sincroapp-notifications
sudo pm2 save
```

### 2. Limpar instalação anterior

```bash
sudo rm -rf /var/www/webapp/sincroapp_flutter
```

### 3. Configurar variáveis de ambiente

```bash
export RECAPTCHA_V3_SITE_KEY="6LeC__ArAAAAAJUbYkba086MP-cCJBolbjLcm_uU"
export DOMAIN="sincroapp.com.br"
export FIREBASE_PROJECT="sincroapp-e9cda"
```

### 4. Clonar repositório atualizado

```bash
cd /tmp
git clone https://github.com/gmalickovski/sincroapp_flutter.git
cd sincroapp_flutter
```

### 5. Executar installer

```bash
sudo -E ./deploy/install.sh
```

O installer irá:
- ✅ Instalar dependências do Flutter
- ✅ Fazer build web com `--base-href /app/`
- ✅ Copiar landing para `build/web/`
- ✅ Instalar dependências das Functions (incluindo `@google-cloud/recaptcha-enterprise`)
- ✅ Fazer deploy das Functions com validação reCAPTCHA
- ✅ Configurar Nginx (landing em `/`, app em `/app/`)
- ✅ Reiniciar PM2 e Nginx

## 🧪 Como Testar

### 1. Verificar deploy das Functions

```bash
firebase functions:list
```

Deve mostrar:
- `validateRecaptcha` (HTTPS)
- `startWebCheckout` (Callable)
- Outras functions...

### 2. Testar endpoint de validação

```bash
curl -X POST https://us-central1-sincroapp-e9cda.cloudfunctions.net/validateRecaptcha \
  -H "Content-Type: application/json" \
  -d '{
    "token": "test-token-aqui",
    "action": "homepage"
  }'
```

Resposta esperada (mesmo com token inválido):
```json
{
  "success": false,
  "score": 0,
  "valid": false,
  "reasons": ["INVALID_REASON"],
  "message": "Verificação falhou - possível bot"
}
```

### 3. Testar na landing page

1. Acesse: `https://sincroapp.com.br`
2. Abra DevTools > Console
3. Clique em um botão de plano (Plus ou Premium)
4. Verifique no console:
   ```
   ✅ Token reCAPTCHA gerado para checkout
   ✅ reCAPTCHA validado. Score: 0.9
   ```

### 4. Verificar Firebase Console

1. Vá para: Firebase Console > App Check > reCAPTCHA
2. Clique na chave `sincroapp-check-web`
3. Aba **"Registros"** ou **"Pontuações"**
4. Deve mostrar:
   - ✅ **Execuções** (tokens gerados)
   - ✅ **Avaliações** (scores calculados)
   - ✅ Status mudou de "Desprotegido" para **"Ativo"**

## 📊 Entendendo os Scores

O reCAPTCHA Enterprise retorna um score de **0.0 a 1.0**:

| Score | Interpretação | Ação Recomendada |
|-------|---------------|------------------|
| 0.9 - 1.0 | Muito provavelmente humano | ✅ Permitir |
| 0.7 - 0.8 | Provavelmente humano | ✅ Permitir |
| 0.5 - 0.6 | Incerto | ⚠️ Monitorar |
| 0.3 - 0.4 | Provavelmente bot | ❌ Bloquear ou CAPTCHA visual |
| 0.0 - 0.2 | Muito provavelmente bot | ❌ Bloquear |

**Threshold atual**: `0.5` (configurado em `functions/index.js`)

## 🔧 Ajustes de Threshold

Se precisar ajustar o limite de aceitação:

```javascript
// functions/index.js - linha ~60
const isHuman = assessment.valid && assessment.score >= 0.5; // Altere 0.5

// functions/index.js - linha ~310 (startWebCheckout)
if (!assessment.valid || assessment.score < 0.5) { // Altere 0.5
```

Deploy após alteração:
```bash
cd functions
firebase deploy --only functions
```

## 🐛 Troubleshooting

### Erro: "Package @google-cloud/recaptcha-enterprise not found"

```bash
cd functions
npm install
firebase deploy --only functions
```

### Functions não estão gerando assessments

Verifique logs:
```bash
firebase functions:log
```

Procure por:
```
✅ reCAPTCHA válido. Score: X.XX
```

### Status continua "Desprotegido"

1. Aguarde 5-10 minutos após o primeiro deploy
2. Teste a landing fazendo checkout de um plano
3. Recarregue a página do Firebase Console
4. Verifique se há avaliações na aba "Registros"

### Landing não está chamando validação

Verifique:
1. `landing.html` carrega o SDK do Firebase Functions
2. Console do browser mostra erros de CORS
3. URL da function está correta: `https://us-central1-sincroapp-e9cda.cloudfunctions.net/validateRecaptcha`

## 📚 Referências

- [reCAPTCHA Enterprise - Assess](https://cloud.google.com/recaptcha-enterprise/docs/create-assessment)
- [reCAPTCHA Enterprise - Node.js](https://cloud.google.com/recaptcha-enterprise/docs/quickstart)
- [Firebase Functions - Callable](https://firebase.google.com/docs/functions/callable)
- [Firebase App Check - Web](https://firebase.google.com/docs/app-check/web/recaptcha-provider)

## ✅ Checklist Final

- [ ] Functions deployed com `@google-cloud/recaptcha-enterprise`
- [ ] Endpoint `validateRecaptcha` acessível via HTTPS
- [ ] Landing chama validação no checkout
- [ ] Firebase Console mostra **avaliações** (não só execuções)
- [ ] Status mudou de "Desprotegido" para "Ativo"
- [ ] Logs das functions mostram scores
- [ ] Threshold configurado apropriadamente (0.5 ou ajustado)
