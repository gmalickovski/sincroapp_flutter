# Correção App Check 400 na Tela de Login

## Problema Resolvido

**Erro**: `POST exchangeRecaptchaV3Token 400 (Bad Request)` ao tentar fazer login no Flutter Web

**Causa**: App Check estava sendo ativado no `main.dart` ANTES do usuário fazer login. App Check com reCAPTCHA v3 requer usuário autenticado, causando erro 400 na tela de login.

## Solução Implementada

1. **Removido** App Check do `lib/main.dart`
2. **Movido** ativação de App Check para `lib/features/authentication/data/auth_repository.dart`
3. App Check agora é ativado **APENAS APÓS login/registro bem-sucedido**

## Deploy na VPS

### 1. Fazer Pull das Mudanças

```bash
cd /var/www/webapp/sincroapp_flutter
git pull origin main
```

### 2. Rebuild Flutter Web

```bash
# Limpar build anterior
flutter clean

# Reconstruir para web
flutter build web --release --web-renderer html --base-href /app/

# Copiar landing para build
cp web/landing.html web/landing.js web/firebase-config.js build/web/
```

### 3. Aplicar Config Nginx (já está correta)

```bash
sudo bash deploy/reset-nginx.sh
```

### 4. Testar Login

```bash
# 1. Abrir navegador em modo anônimo
# 2. Acessar: https://sincroapp.com.br
# 3. Clicar em "Entrar"
# 4. Fazer login com email/senha
# 5. Verificar console do navegador:
#    ✅ DEVE aparecer: "🔧 Ativando App Check pós-login..."
#    ✅ DEVE aparecer: "✅ App Check ativado com sucesso"
#    ❌ NÃO DEVE aparecer: "400 (Bad Request)"
```

## Comportamento Esperado

### Antes do Login (Tela de Login)
- **SEM** App Check ativo
- **SEM** erros 400
- Usuário pode fazer login normalmente

### Após Login Bem-Sucedido
- **App Check é ativado automaticamente**
- Token reCAPTCHA v3 é obtido com sucesso
- Firestore, Functions, etc. usam App Check normalmente

## Arquivos Modificados

- `lib/main.dart`: Removida ativação de App Check
- `lib/features/authentication/data/auth_repository.dart`: Adicionada ativação pós-login

## Commit

```
8010b51 - fix(app-check): mover ativação para após login
```

## Verificação Pós-Deploy

### Console Navegador (Login Page) - ANTES DO LOGIN
```
✅ Nenhum erro de App Check
✅ Nenhum POST para exchangeRecaptchaV3Token
✅ Página carrega sem erros
```

### Console Navegador (Após Login)
```
✅ "🔧 Ativando App Check pós-login..."
✅ "✅ App Check ativado com sucesso"
✅ POST exchangeRecaptchaV3Token retorna 200 OK
```

### Se Ainda Aparecer Erro 400

1. **Limpar cache completo do navegador**
   ```
   Ctrl+Shift+Delete → Limpar tudo
   ```

2. **Testar em janela anônima nova**

3. **Verificar build deployado**
   ```bash
   # Confirmar que arquivos foram atualizados
   ls -lh /var/www/webapp/sincroapp_flutter/build/web/main.dart.js
   
   # Deve mostrar data/hora recente (após rebuild)
   ```

4. **Verificar que não há service worker cacheado**
   ```
   DevTools → Application → Service Workers → Unregister
   ```

## Notas Importantes

- **Landing Page**: Continua SEM App Check (correto)
- **Flutter App**: App Check ativado APENAS pós-autenticação
- **Debug Mode**: Usa AndroidProvider.debug e AppleProvider.debug
- **Release Mode**: Usa Play Integrity (Android) e App Attest (iOS)
- **Web**: Sempre usa reCAPTCHA v3 com site key `6LeC__ArAAAAAJUbYkba086MP-cCJBolbjLcm_uU`

## Troubleshooting

### "App Check ainda dá erro 400"
→ Limpar cache + rebuild + redeploy

### "App Check não ativa após login"
→ Verificar logs no console: deve aparecer "🔧 Ativando App Check pós-login..."

### "Firestore dá erro após login"
→ Aguardar alguns segundos para App Check ativar completamente

## Resumo

**Problema**: App Check ativado antes do login → erro 400  
**Solução**: App Check ativado APÓS login → sem erros  
**Deploy**: `git pull` → `flutter build web` → `reset-nginx.sh`  
**Teste**: Login deve funcionar sem erro 400 no console
