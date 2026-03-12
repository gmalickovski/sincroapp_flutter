# Deploy Scripts - Guia de Uso Rápido

## 🎯 Qual script usar?

```
┌─────────────────────────────────────────────────────────────┐
│ SITUAÇÃO                          │ SCRIPT A USAR           │
├─────────────────────────────────────────────────────────────┤
│ Primeira instalação no servidor   │ install.sh              │
│ Atualizar versão já instalada     │ update.sh               │
│ Deploy rápido do seu computador   │ quick-deploy.sh         │
└─────────────────────────────────────────────────────────────┘
```

## 📦 1. Instalação Inicial (Servidor Novo)

Execute **NO SERVIDOR**:

```bash
# 1. Conectar ao servidor
ssh root@seu-servidor.com

# 2. Baixar o repositório
cd /var/www/webapp
git clone https://github.com/gmalickovski/sincroapp_flutter.git
cd sincroapp_flutter/deploy

# 3. Tornar executável e rodar
chmod +x install.sh
./install.sh
```

**O que acontece:**
- ✅ Instala Node.js, Flutter, Firebase CLI, PM2, Nginx
- ✅ Clona o código do GitHub
- ✅ Faz build do Flutter Web
- ✅ Configura SSL (Let's Encrypt)
- ✅ Inicia todos os serviços

**Tempo estimado:** 10-15 minutos

---

## 🔄 2. Atualização (Sistema Já Instalado)

Execute **NO SERVIDOR**:

```bash
# 1. Conectar ao servidor
ssh root@seu-servidor.com

# 2. Ir para o diretório de deploy
cd /var/www/webapp/sincroapp_flutter/deploy

# 3. Executar atualização
./update.sh
```

**O que acontece:**
- ✅ Cria backup automático
- ✅ Atualiza código do GitHub
- ✅ Atualiza dependências
- ✅ Gera novo build
- ✅ Reinicia serviços
- ✅ Mantém 5 backups mais recentes

**Tempo estimado:** 3-5 minutos

---

## ⚡ 3. Deploy Rápido (Do Seu Computador)

Execute **NO SEU COMPUTADOR** (Windows/Mac/Linux):

```bash
# 1. Ir para a pasta do projeto
cd C:\dev\sincro_app_flutter\deploy  # Windows
# ou
cd ~/dev/sincro_app_flutter/deploy   # Mac/Linux

# 2. Editar configurações (APENAS NA PRIMEIRA VEZ)
# Abrir quick-deploy.sh e alterar:
#   SERVER_HOST="seu-servidor.com"
#   SERVER_USER="root"

# 3. Tornar executável (apenas primeira vez)
chmod +x quick-deploy.sh

# 4. Executar deploy
./quick-deploy.sh
```

**Menu interativo:**
```
Selecione o tipo de deploy:
1) Deploy completo (código + build + restart)
2) Deploy apenas código (sem rebuild)
3) Deploy apenas Flutter Web
4) Deploy apenas Functions
```

**Tempo estimado:** 2-10 minutos (depende da opção)

---

## 🛠️ Comandos Úteis

### Verificar Status

```bash
# Status do Nginx
sudo systemctl status nginx

# Status do PM2
pm2 status

# Logs do Nginx
sudo tail -f /var/log/nginx/error.log

# Monitorar recursos
pm2 monit
```

### Reiniciar Serviços

```bash
# Reiniciar Nginx
sudo systemctl reload nginx

# Reiniciar Servidor Principal
pm2 restart sincroapp-server

# Reiniciar todos os processos PM2
pm2 restart all
```

### Reverter Atualização

```bash
# Listar backups disponíveis
ls -lh /var/backups/sincroapp_flutter/

# Reverter para backup específico
BACKUP_DATE="20251116_143022"
sudo rm -rf /var/www/webapp/sincroapp_flutter
sudo cp -r /var/backups/sincroapp_flutter/backup_$BACKUP_DATE /var/www/webapp/sincroapp_flutter
sudo systemctl reload nginx
pm2 restart sincroapp-server
```

---

## 🔧 Configuração Inicial (Primeira Vez)

### 1. Configurar Firebase

```bash
# No servidor, após install.sh
firebase login --no-localhost

# Deploy das Functions
cd /var/www/webapp/sincroapp_flutter
firebase deploy --only functions
```

### 2. Configurar Variáveis de Ambiente

Edite o arquivo de configuração das Functions:

```bash
# Definir variáveis de ambiente
firebase functions:config:set \
  pagbank.token="SEU_TOKEN_PAGBANK" \
  n8n.webhook_url="https://seu-n8n.com/webhook"

# Fazer deploy novamente
firebase deploy --only functions
```

### 3. Testar a Aplicação

```bash
# Verificar se está no ar
curl -I https://sincroapp.com.br

# Deve retornar: HTTP/2 200
```

---

## ❗ Solução de Problemas

### Problema: Site não carrega

```bash
# 1. Verificar se o build existe
ls -lh /var/www/webapp/sincroapp_flutter/build/web/

# 2. Verificar permissões
sudo chown -R www-data:www-data /var/www/webapp/sincroapp_flutter/build/web
sudo chmod -R 755 /var/www/webapp/sincroapp_flutter/build/web

# 3. Verificar configuração Nginx
sudo nginx -t
sudo systemctl reload nginx

# 4. Ver logs
sudo tail -f /var/log/nginx/error.log
```

### Problema: Notificações não funcionam

```bash
# 1. Verificar logs das Edge Functions (via VPS)
docker logs supabase-edge-functions --tail 50

# 2. Reiniciar o Container das Functions do Supabase
cd /var/www/app/supabase
docker compose restart functions
```

### Problema: Functions não respondem

```bash
# Ver logs no Firebase Console
firebase functions:log

# Fazer redeploy
cd /var/www/webapp/sincroapp_flutter
firebase deploy --only functions --force
```

---

## 📊 Fluxo de Trabalho Recomendado

### Desenvolvimento Local

```bash
# 1. Fazer alterações no código
code .

# 2. Testar localmente
flutter run -d chrome

# 3. Commit e push
git add .
git commit -m "feat: nova funcionalidade"
git push origin main
```

### Deploy para Produção

**Opção A - Do servidor (mais seguro):**
```bash
ssh root@seu-servidor.com
cd /var/www/webapp/sincroapp_flutter/deploy
./update.sh
```

**Opção B - Do seu computador (mais rápido):**
```bash
cd C:\dev\sincro_app_flutter\deploy
./quick-deploy.sh
# Escolher opção 1 (Deploy completo)
```

---

## 🔒 Segurança

### SSL/HTTPS
- ✅ Configurado automaticamente pelo Certbot
- ✅ Renovação automática a cada 90 dias
- ✅ Redirect HTTP → HTTPS ativo

### Firewall
```bash
# Verificar regras ativas
sudo ufw status

# Permitir portas necessárias (já feito pelo install.sh)
sudo ufw allow 22    # SSH
sudo ufw allow 80    # HTTP
sudo ufw allow 443   # HTTPS
```

### Backups
- ✅ Criados automaticamente a cada atualização
- ✅ Salvos em `/var/backups/sincroapp_flutter/`
- ✅ Mantém os 5 mais recentes

---

## 📞 Checklist Pré-Deploy

Antes de fazer deploy em produção:

- [ ] Código testado localmente
- [ ] Commit feito no Git
- [ ] Variáveis de ambiente configuradas no Firebase
- [ ] Backup manual criado (opcional, mas recomendado)
- [ ] Horário de baixo tráfego escolhido

---

## 🎓 Dicas Pro

1. **Use o quick-deploy.sh para deploys rápidos** durante desenvolvimento
2. **Sempre teste em ambiente de homologação** antes de produção
3. **Monitore os logs** após cada deploy
4. **Mantenha backups externos** além dos automáticos
5. **Configure alertas** para monitoramento de uptime

---

## 📄 Arquivos de Configuração

```
deploy/
├── install.sh          # Instalação inicial completa
├── update.sh           # Atualização do sistema
├── quick-deploy.sh     # Deploy rápido do computador
├── README.md           # Documentação completa
└── QUICK_START.md      # Este arquivo (guia rápido)
```

---

## ✅ Próximos Passos

Após a instalação:

1. Configure o Firebase (`firebase login` e `firebase deploy --only functions`)
2. Configure variáveis de ambiente do PagBank e n8n
3. Teste todos os endpoints (web, functions, notificações)
4. Configure monitoramento (Uptime Robot, StatusCake, etc.)
5. Documente suas credenciais em local seguro

**Tudo pronto! 🚀**
