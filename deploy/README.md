# Scripts de Deploy - SincroApp Flutter Web

Este diretório contém scripts automatizados para instalação e atualização do sistema SincroApp Flutter Web no servidor.

## 📋 Scripts Disponíveis

### 1. `install.sh` - Instalação Completa
Script para instalação do zero em um servidor limpo.

**O que faz:**
- Instala todas as dependências (Node.js, Flutter, Firebase CLI, PM2, Nginx)
- Clona o repositório do GitHub
- Configura o Nginx com SSL
- Faz build do Flutter Web
- Configura o serviço de notificações
- Configura firewall e permissões

**Uso:**
```bash
# No servidor
sudo bash install.sh
```

### 2. `update.sh` - Atualização do Sistema
Script para atualizar o sistema já instalado com nova versão do código.

**O que faz:**
- Cria backup automático da versão atual
- Atualiza código do GitHub
- Atualiza todas as dependências
- Gera novo build do Flutter Web
- Reinicia todos os serviços
- Mantém histórico de backups

**Uso:**
```bash
# Atualizar da branch main (padrão)
sudo bash update.sh

# Atualizar de uma branch específica
sudo bash update.sh develop
```

## 🚀 Fluxo de Uso

### Primeira Instalação

1. **Prepare o servidor:**
   ```bash
   ssh root@seu-servidor
   mkdir -p /var/www/webapp
   cd /var/www/webapp
   ```

2. **Baixe e execute o script de instalação:**
   ```bash
   # Opção 1: Clone o repositório primeiro
   git clone https://github.com/gmalickovski/sincroapp_flutter.git
   cd sincroapp_flutter/deploy
   sudo bash install.sh

   # Opção 2: Download direto do script
   wget https://raw.githubusercontent.com/gmalickovski/sincroapp_flutter/main/deploy/install.sh
   sudo bash install.sh
   ```

3. **Configure o Firebase:**
   ```bash
   firebase login
   cd /var/www/webapp/sincroapp_flutter
   firebase deploy --only functions
   ```

4. **Acesse a aplicação:**
   ```
   https://sincroapp.com.br
   ```

### Atualizações Subsequentes

1. **Execute o script de atualização:**
   ```bash
   cd /var/www/webapp/sincroapp_flutter/deploy
   sudo bash update.sh
   ```

2. **Opcional - Deploy das Functions (se houver mudanças):**
   ```bash
   cd /var/www/webapp/sincroapp_flutter
   firebase deploy --only functions
   ```

## 🔧 Configurações Importantes

### Variáveis de Ambiente

Antes de executar os scripts, você pode personalizar as seguintes variáveis:

**No `install.sh`:**
```bash
INSTALL_DIR="/var/www/webapp/sincroapp_flutter"  # Diretório de instalação
DOMAIN="sincroapp.com.br"                         # Seu domínio
NODE_VERSION="20"                                 # Versão do Node.js
```

**No `update.sh`:**
```bash
BACKUP_DIR="/var/backups/sincroapp_flutter"  # Diretório de backups
```

### Pré-requisitos

- Ubuntu/Debian Linux (testado em Ubuntu 20.04+)
- Acesso root ou sudo
- Domínio apontando para o servidor (para SSL)
- Portas 80 e 443 abertas no firewall

## 📝 Logs e Monitoramento

### Verificar logs do Nginx
```bash
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/access.log
```

### Verificar logs do PM2 (Serviço de Notificações)
```bash
pm2 logs sincroapp-notifications
pm2 monit
```

### Verificar status dos serviços
```bash
sudo systemctl status nginx
pm2 status
```

## 🔄 Rollback (Reverter Atualização)

Se algo der errado após uma atualização:

```bash
# O script de atualização cria backups automáticos em /var/backups/sincroapp_flutter

# Listar backups disponíveis
ls -lh /var/backups/sincroapp_flutter

# Reverter para um backup específico
BACKUP_DATE="20251116_143022"  # Substitua pela data do backup
sudo rm -rf /var/www/webapp/sincroapp_flutter
sudo cp -r /var/backups/sincroapp_flutter/backup_$BACKUP_DATE /var/www/webapp/sincroapp_flutter
sudo systemctl reload nginx
sudo pm2 restart sincroapp-notifications
```

## 🛡️ Segurança

### SSL/HTTPS
Os scripts configuram SSL automaticamente usando Let's Encrypt/Certbot. O certificado é renovado automaticamente.

### Firewall
O script de instalação configura o UFW (Uncomplicated Firewall) permitindo apenas:
- Porta 22 (SSH)
- Porta 80 (HTTP - redireciona para HTTPS)
- Porta 443 (HTTPS)

### Permissões
Os arquivos web são configurados com as permissões corretas:
- Proprietário: `www-data:www-data`
- Permissões: `755` para diretórios, `644` para arquivos

## 🐛 Solução de Problemas

### Erro: "flutter: command not found"
```bash
export PATH="$PATH:/opt/flutter/bin"
# Ou reinicie o terminal
```

### Erro: "nginx: configuration test failed"
```bash
sudo nginx -t  # Veja o erro detalhado
sudo nano /etc/nginx/sites-available/sincroapp.com.br  # Corrija
sudo systemctl reload nginx
```

### Erro: "PM2: process not found"
```bash
cd /var/www/webapp/sincroapp_flutter/notification-service
pm2 start index.js --name sincroapp-notifications
pm2 save
```

### Site não carrega após atualização
```bash
# Limpar cache do navegador com Ctrl+Shift+R
# Verificar se o build foi gerado
ls -lh /var/www/webapp/sincroapp_flutter/build/web

# Verificar permissões
sudo chown -R www-data:www-data /var/www/webapp/sincroapp_flutter/build/web
```

## 📞 Suporte

Para problemas ou dúvidas:
1. Verifique os logs (Nginx e PM2)
2. Consulte a documentação no README principal
3. Abra uma issue no GitHub

## 📄 Licença

Este projeto segue a mesma licença do projeto principal SincroApp.
