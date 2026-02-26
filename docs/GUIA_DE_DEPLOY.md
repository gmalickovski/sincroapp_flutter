# Guia Prático: Controle de Versão e Deploy Automático - SincroApp

Este documento detalha o fluxo de desenvolvimento, como gerar novas versões (releases) do sistema e como essas atualizações chegam até a o servidor (VPS) de produção. 

Este guia é feito para que qualquer novo desenvolvedor compreenda a estrutura do SincroApp.

---

## 1. O Padrão de Commits (Conventional Commits)

Nós utilizamos um padrão rigoroso para mensagens de *commit* chamado **Conventional Commits**. Esse padrão não serve apenas para deixar o histórico bonito; ele é **lido por um script** (`standard-version`) que toma decisões automatizadas sobre qual deve ser o número da próxima versão e o que escrever no arquivo de Notas de Atualização (`CHANGELOG.md`).

A estrutura de um commit é: `tipo(escopo opcional): descrição breve`

### Tipos mais comuns e o que eles fazem:
- **`feat:`** (Feature): Você desenvolveu uma funcionalidade nova. 
  - *Efeito:* Isso gera um aumento na versão "MINOR" (ex: de 1.4.3 para 1.5.0).
  - *Exemplo:* `feat(toolbar): adiciona setas de rolagem nos filtros`
- **`fix:`** (Bug Fix): Você corrigiu um erro no sistema. 
  - *Efeito:* Isso gera um aumento na versão "PATCH" (ex: de 1.4.3 para 1.4.4).
  - *Exemplo:* `fix(ui): resolve sobreposição de elementos no calendário`
- **`chore:`** (Tarefas de manutenção): Alterações que não afetam o código fonte de produção, como atualizar dependências, scripts internos ou ferramentas de build.
  - *Efeito:* Geralmente não muda a versão.
  - *Exemplo:* `chore: atualiza pacotes do flutter`
- **`docs:`** Alterações exclusivas em documentações (como este arquivo).
- **`style:`** Formatação de código, ponto e vírgula faltando, indentação (nenhuma mudança lógica).
- **`refactor:`** Refatoração de código que não corrige um bug nem adiciona uma nova feature, apenas melhora a estrutura ou legibilidade do código existente.
- **`perf:`** Melhorias de performance.
- **`test:`** Adição ou correção de testes automatizados.

### Quebras de Compatibilidade (Breaking Changes)
Se você colocar uma exclamação após o tipo (ex: **`feat!:`** ou **`fix!:`**), ou escrever `BREAKING CHANGE:` no rodapé do commit, o sistema entenderá que é uma mudança estrutural pesada (ex: mudou todo o banco de dados).
- *Efeito:* Isso gera um aumento na versão "MAJOR" (ex: de 1.5.0 para 2.0.0).

---

## 2. O Versionamento Semântico (SemVer)

O sistema de numeração de atualizações estruturais que utilizamos mundialmente na tecnologia é o **Semantic Versioning (SemVer)**. Ele segue o formato `X.Y.Z` (Exemplo: `1.5.0`). Cada número tem um significado exato de como o sistema cresceu ou mudou:

- **MAJOR (O Primeiro número - `X`.Y.Z)**: Usado quando você faz **mudanças incompatíveis** na API ou na estrutura principal do SincroApp. Exemplos: recriar tabelas base do banco de dados, mudar como a assinatura VIP funciona inteira, remover o suporte a contas antigas. 
  - *Como acionar no commit:* `feat!: refaz sistema vip`
  - *Transição comum:* Versão `1.5.0` vai direto para `2.0.0`.

- **MINOR (O número do Meio - X.`Y`.Z)**: Usado quando você **adiciona funcionalidades novas**, sem quebrar nada que já existia. Uma nova aba no app, integração do numerólogo com data de nascimento, um novo botão que leva a uma página nativa que não existia. O app continua agindo e recebendo dados na moral de tudo que já funcionava antes. 
  - *Como acionar no commit:* `feat: adiciona numerologia de hoje`
  - *Transição comum:* Versão `1.4.3` vai para `1.5.0` (O Z sempre reseta pra `0` quando o Y sobe).

- **PATCH (O Último número - X.Y.`Z`)**: Usado apenas para **correções de falhas (Bugs)** compatíveis com as versões antigas, e coisas de manutenção diária que não devem quebrar e nem colocar de fato novas Features à vida. Modificar a cor de um botão `fix(ui): muda cor do foco`, ajustar um typo do nome de um Widget, etc. 
  - *Como acionar no commit:* `fix: nome do btn corrigido`
  - *Transição:* Versão `1.5.0` vai para `1.5.1`.

---

## 2. O Processo de Release (Nova Versão)

Quando terminamos um pacote de tarefas (features, fixes) e queremos gerar uma atualização oficial do sistema, as etapas que acontecem na máquina do desenvolvedor são:

1. **Commit das alterações manuais:** `git commit -m "feat: sua nova feature"`
2. **Gerar Release:** Executar no terminal:
   ```bash
   npm run release
   ```
   **O que esse comando faz nos bastidores?** Ele usa o pacote `standard-version` para:
   - Ler todo o seu histórico desde o último release e ver se há `feat`, `fix`, ou `BREAKING CHANGES`.
   - Bump (aumentar) o número da versão corretamente nos arquivos `package.json`, `server/package.json` e no Flutter `pubspec.yaml`.
   - Gerar um resumo automático para o arquivo `CHANGELOG.md` descrevendo o que mudou.
   - Criar um **Commit de Release** automático agrupando essas alterações (Ex: *chore(release): 1.5.0*).
   - Criar uma **Tag do Git** com a versão exata dessa foto do projeto (Ex: `v1.5.0`).

---

## 3. O Comando de Push e a Tag (Gatilho)

Depois que a versão foi gerada (`npm run release`), precisamos mandar os arquivos do seu computador local para a nuvem do GitHub. 
Repositório remoto: `https://github.com/gmalickovski/sincroapp_flutter.git`

O comando a ser digitado é:
```bash
git push --follow-tags
```

*(Lembrete: nunca digite `--follow-tags--` pois acusa erro de sintaxe no terminal).*

**Por que `--follow-tags`?** 
Um `git push` normal apenas envia os arquivos e histórico. Ao adicionar `--follow-tags`, ele envia os arquivos **E também** empurra a "Etiqueta" (Tag `v1.5.0`) que o script anterior criou. 

**Isso é vital!** O nosso servidor na nuvem (GitHub Actions) está programado para ficar "dormindo" até que ele veja uma tag que comece com "v" chegando. Quando essa Tag chega acompanhando os arquivos, ela aciona o robozinho para colocar a versão no ar.

---

## 4. O Fluxo do GitHub Actions (CI / CD)

O sistema Automático, localizado no arquivo oculto `.github/workflows/deploy-web.yml`, acorda quando a master recebe esse push com a Tag.
O fluxo (Pipeline) faz os seguintes passos em um servidor temporário da Microsoft/GitHub:

1. Baixa o código recente.
2. Instala o Flutter (Canal Estável / stable) e faz `flutter pub get`.
3. Compila a versão Web (`flutter build web --release`).
4. Conecta via **SSH segura** no seu Servidor VPS.

---

## 5. O Servidor VPS (Onde fica a aplicação)

A pipeline acima acessa a nossa VPS via SSH na porta especificada e insere os dados para rodar o app para os clientes. 

As credenciais sensíveis, como o número de IP (`VPS_HOST`) e a chave primária (`VPS_SSH_KEY`), ficam guardadas a sete senhas diretamente dentro das "Secrets" da própria configuração do repositório privado no GitHub, para que nenhum desenvolvedor tenha acesso à senha bruta de produção do servidor. A porta designada geralmente é a **2222**.

**O caminho do seu sistema na VPS:**
A pasta raiz do projeto dentro do computador do Linux de sua VPS é:
`/var/www/webapp/sincroapp_flutter`

**O que o Deploy da VPS faz automaticamente (conforme nosso Workflow)?**
1. **Frontend (App Web):** O robô do GitHub faz o SCP (cópia segura) apenas dos arquivos compilados prontos vindos da pasta `build/web/` e os cola na mesma rota interna do servidor: `/var/www/webapp/sincroapp_flutter/build/web`.
2. **Backend (Node):** Em seguida o robô manda a VPS fazer um `git pull origin main` lá nela para baixar seu último código node.js que mandou com o push, acessa a pasta `server/`, roda o `npm install` e então **Reinicia a PM2** (o programa que mantém nosso node rodando sem cair) subindo um server na porta `4545`. 
3. **Nginx:** Em seu finalização, ele corrige as permissões vitais da Web para rodar arquivos NGINX (o maestro que direciona domínios na internet de fato para rodarem o app e o server e mostrar a telinha na casa do usuário do app web), e por fim recarrega as confugrações. E então pronto... App em Produção Atualizado!

---
## Resumo do Fluxo do Desenvolvedor Diário:

1. Faz as alterações necessárias no sistema.
2. `git add .`
3. `git commit -m "fix/feat/chore: mensagem"`
4. Teste final.
5. `npm run release` -> Cria a tag e anota o Changelog automático.
6. `git push --follow-tags` -> Envia para a nuvem.
7. *Basta ir tomar um café*. O GitHub Actions assumirá o restante e vai empurrá-lo para sua VPS na nuvem em poucos minutos.
