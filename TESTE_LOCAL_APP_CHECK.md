# Teste Local - App Check Corrigido

## ⚠️ IMPORTANTE: Você está testando BUILD ANTIGO

Os erros que você vê são do **build antigo** ainda cacheado. O código novo JÁ FOI COMPILADO localmente em `build/web/`.

## Como Testar CORRETAMENTE

### Opção 1: Testar Localmente (RECOMENDADO)

```bash
# 1. Servir build local
cd C:\dev\sincro_app_flutter
python -m http.server 8000 -d build/web

# 2. Abrir navegador ANÔNIMO
# Não usar navegador normal (tem cache!)

# 3. Acessar
http://localhost:8000/

# 4. Login deve funcionar SEM erro 400
# Console deve mostrar:
# ✅ "🔧 Ativando App Check pós-login..." (APÓS clicar em login)
# ✅ "✅ App Check ativado com sucesso"
# ❌ NÃO deve ter erro 400 ANTES dessas mensagens
```

### Opção 2: Deploy na VPS

```bash
# Na VPS:
cd /var/www/webapp/sincroapp_flutter
git pull origin main

# Rebuild
flutter clean
flutter build web --release --base-href /app/
cp web/landing.html web/landing.js web/firebase-config.js build/web/

# Aplicar config (já está correta)
sudo bash deploy/reset-nginx.sh

# Testar em janela ANÔNIMA
# https://sincroapp.com.br/app/#/login
```

## O que está ERRADO no seu teste atual

Você viu estas mensagens **NESTA ORDEM**:

```
1. POST exchangeRecaptchaV3Token 400 (Bad Request)  ← BUILD ANTIGO
2. 🔧 Ativando App Check pós-login...                ← BUILD NOVO
3. ✅ App Check ativado com sucesso                  ← BUILD NOVO
```

**Isso é IMPOSSÍVEL no código novo!** 

No código novo, a mensagem #2 **NUNCA** apareceria se #1 acontecesse, porque:
- #1 = App Check tentando ativar no main.dart (código antigo)
- #2 = App Check tentando ativar após login (código novo)

Você está vendo **AMBOS** porque há **cache misturado** de builds antigos e novos.

## Solução: LIMPAR TUDO

### No Navegador

1. **Fechar TODOS os tabs do site**
2. **Abrir DevTools** (F12)
3. **Application → Clear Storage → Clear site data**
4. **Fechar navegador completamente**
5. **Abrir janela ANÔNIMA nova**
6. **Testar novamente**

### OU usar curl (sem cache)

```bash
# Verificar se build novo está deployado
curl -s https://sincroapp.com.br/app/ | grep -o "main.dart.js" | head -1

# Se aparecer, o HTML está correto
# Agora testar login via browser anônimo
```

## Comportamento ESPERADO (Código Novo)

### ANTES do Login (Tela de Login)
```
✅ ZERO requisições para exchangeRecaptchaV3Token
✅ ZERO erros de App Check
✅ Página carrega normalmente
```

### DURANTE o Login (Após clicar "Entrar")
```
1. Firebase Auth tenta fazer login
2. Login é bem-sucedido
3. ✅ "🔧 Ativando App Check pós-login..." (PRIMEIRA VEZ)
4. ✅ "✅ App Check ativado com sucesso"
5. POST exchangeRecaptchaV3Token retorna 200 OK (agora sim)
```

### APÓS Login Bem-Sucedido
```
✅ Dashboard carrega
✅ Firestore funciona normalmente
✅ App Check está ativo e funcional
```

## Se AINDA aparecer erro 400

Significa que você **NÃO está rodando o build novo**. Verifique:

1. **Build local está atualizado?**
   ```bash
   ls -lh build/web/main.dart.js
   # Deve mostrar data/hora de HOJE
   ```

2. **Servidor está servindo build correto?**
   ```bash
   # Se usando Python HTTP server:
   # Pare (Ctrl+C) e inicie novamente
   python -m http.server 8000 -d build/web
   ```

3. **Browser está realmente sem cache?**
   - Use janela ANÔNIMA
   - OU limpe cache completo
   - OU use outro browser

## Resumo

**Problema**: Você está testando build antigo (cacheado)  
**Solução**: Limpar cache OU testar localmente com build novo  
**Como confirmar**: ZERO erros 400 ANTES da mensagem "Ativando App Check pós-login"  

Se erro 400 aparecer ANTES dessa mensagem = build antigo!
