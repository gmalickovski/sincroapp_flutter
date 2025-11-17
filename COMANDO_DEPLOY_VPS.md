# 🚀 COMANDOS PARA DEPLOY NA VPS - CORREÇÃO FINAL

## ⚠️ PROBLEMA RESOLVIDO
Erro: `MIME type 'text/html' is not executable` ao carregar `flutter_bootstrap.js/`

**Causa:** Nginx retornando HTML em vez de JavaScript devido a trailing slash (`/`) na URL

**Solução:** Regex com rewrite para remover barras finais de assets

---

## 📋 PASSO A PASSO COMPLETO

### **1️⃣ Conectar na VPS**
```bash
ssh root@seu-servidor
```

### **2️⃣ Atualizar Repositório**
```bash
cd /var/www/webapp/sincroapp_flutter
git pull origin main
```

### **3️⃣ Resetar Nginx (MÉTODO AUTOMÁTICO)**
```bash
sudo bash deploy/reset-nginx.sh
```

**Ou MÉTODO MANUAL:**

### **3️⃣ (Alternativa Manual) Editar Nginx Diretamente**
```bash
# Backup
sudo cp /etc/nginx/sites-available/sincroapp.com.br /etc/nginx/sites-available/sincroapp.com.br.bak.$(date +%Y%m%d_%H%M%S)

# Editar
sudo nano /etc/nginx/sites-available/sincroapp.com.br
```

**Procure pela seção:**
```nginx
# Assets JS/CSS do app (DEVE VIR ANTES de location /app/)
location ~* ^/app/.*\.(js|css|wasm|json|map)$ {
    try_files $uri =404;
    expires 1y;
    add_header Cache-Control "public, immutable";
    # Não force Content-Type; deixe o mime.types definir corretamente
}
```

**Substitua por:**
```nginx
# Assets JS/CSS/WASM do app (DEVE VIR ANTES de location /app/)
# CRÍTICO: Remove trailing slashes antes de processar
location ~ ^/app/(.+)\.(js|css|wasm|json|map)/?$ {
    rewrite ^/app/(.*)/$ /app/$1 permanent;
    try_files $uri =404;
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

**Salvar:** Ctrl+O, Enter, Ctrl+X

### **4️⃣ Testar e Recarregar Nginx**
```bash
# Testar configuração
sudo nginx -t

# Se OK, recarregar
sudo systemctl reload nginx

# Verificar status
sudo systemctl status nginx
```

---

## ✅ VALIDAR CONFIGURAÇÃO

### **Verificar location de assets**
```bash
cat /etc/nginx/sites-available/sincroapp.com.br | grep -A 5 "Assets JS/CSS"
```

**Deve mostrar:**
```nginx
# Assets JS/CSS/WASM do app (DEVE VIR ANTES de location /app/)
# CRÍTICO: Remove trailing slashes antes de processar
location ~ ^/app/(.+)\.(js|css|wasm|json|map)/?$ {
    rewrite ^/app/(.*)/$ /app/$1 permanent;
    try_files $uri =404;
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

### **Testar MIME type de assets**
```bash
# Deve retornar Content-Type: application/javascript
curl -I https://sincroapp.com.br/app/flutter_bootstrap.js

# Teste com trailing slash (deve redirecionar 301 e depois 200)
curl -I https://sincroapp.com.br/app/flutter_bootstrap.js/
```

---

## 🧪 TESTAR NO NAVEGADOR

### **1. Limpar cache completo**
- Abrir DevTools (F12)
- Aba Network → Clicar com botão direito → "Clear browser cache"
- Fechar DevTools

### **2. Hard refresh**
- `Ctrl + Shift + R` (Windows/Linux)
- `Cmd + Shift + R` (Mac)

### **3. Testar em janela anônima**
```
1. Ctrl + Shift + N (Chrome) ou Ctrl + Shift + P (Firefox)
2. Acessar: https://sincroapp.com.br
3. Clicar em "Entrar"
4. Deve abrir: https://sincroapp.com.br/app/#/login
5. Tela de login do Flutter deve carregar sem erros
```

### **4. Verificar console (F12)**
**NÃO deve aparecer:**
- ❌ `MIME type 'text/html' is not executable`
- ❌ `Manifest: Syntax error`
- ❌ `AppCheck: Requests throttled`
- ❌ `500 Internal Server Error`

**Deve aparecer:**
- ✅ Flutter carregando normalmente
- ✅ Assets JS/CSS/WASM carregados com status 200

---

## 📊 RESUMO DAS MUDANÇAS

| Aspecto | Antes | Depois |
|---------|-------|--------|
| **Regex assets** | `location ~* ^/app/.*\.(js\|css\|wasm\|json\|map)$` | `location ~ ^/app/(.+)\.(js\|css\|wasm\|json\|map)/?$` |
| **Trailing slash** | Servia HTML | Redirect 301 remove `/` |
| **MIME type** | `text/html` ❌ | `application/javascript` ✅ |
| **Flutter bootstrap** | Erro | Carrega corretamente |

---

## 🆘 TROUBLESHOOTING

### **Nginx não recarrega**
```bash
# Verificar sintaxe
sudo nginx -t

# Forçar restart
sudo systemctl restart nginx

# Ver logs
sudo tail -f /var/log/nginx/error.log
```

### **Ainda aparece erro MIME type**
```bash
# Limpar cache do navegador completamente
# Ou testar com:
curl -v https://sincroapp.com.br/app/flutter_bootstrap.js 2>&1 | grep -i "content-type"

# Deve retornar:
# < content-type: application/javascript
```

### **Assets não carregam**
```bash
# Verificar permissões
ls -la /var/www/webapp/sincroapp_flutter/build/web/

# Deve mostrar:
# -rw-r--r-- www-data www-data flutter_bootstrap.js
# -rw-r--r-- www-data www-data main.dart.js
```

---

## 🎯 COMANDOS RÁPIDOS DE VERIFICAÇÃO

```bash
# Status geral
sudo systemctl status nginx
sudo nginx -t

# Logs em tempo real
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/sincroapp-access.log

# Testar endpoints
curl -I https://sincroapp.com.br                    # Landing (200)
curl -I https://sincroapp.com.br/app/               # Flutter app (200)
curl -I https://sincroapp.com.br/app/flutter_bootstrap.js  # JS asset (200)
```

---

## ✨ APÓS APLICAR

Todos os erros devem estar resolvidos:
- ✅ Landing carrega sem App Check 400
- ✅ `/app/#/login` exibe tela de login do Flutter
- ✅ Assets JS/CSS carregam com MIME type correto
- ✅ Sem erros de MIME type no console
- ✅ Sem erros 500 Internal Server Error

**Sistema 100% funcional!** 🎉
