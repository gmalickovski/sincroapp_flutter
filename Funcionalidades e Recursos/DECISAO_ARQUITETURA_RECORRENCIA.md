# Decisão de Arquitetura: Lógica de Recorrência no Backend

## Contexto
Implementamos a lógica de recorrência de tarefas (criar a tarefa de amanhã ao concluir a de hoje) e o cálculo de numerologia (Dia Pessoal) diretamente no Banco de Dados (Supabase) via **Triggers e Functions PL/pgSQL**.

## Análise Comparativa de Estratégias

### 1. Database Triggers (A abordagem atual)
**Como funciona:** O próprio banco de dados "percebe" o update e executa a função interna.
*   **✅ Prós:**
    *   **Atomicidade:** A transação é "tudo ou nada". Não existe risco de a tarefa ser marcada como concluída e a nova *não* ser criada por falha de rede.
    *   **Performance:** Zero latência de rede. O cálculo ocorre em milissegundos dentro da CPU do banco.
    *   **Resiliência:** Se o seu servidor Node.js ou seu n8n cairem, a recorrência continua funcionando. O banco é a única peça crítica.
*   **❌ Contras:**
    *   **Manutenção:** Lógica em PL/pgSQL (SQL) é mais difícil de escrever e testar do que em JavaScript/Dart.
    *   **Acoplamento:** A regra de negócio fica "presa" ao banco de dados específico (PostgreSQL).

### 2. Edge Functions / Serverless (Padrão "Moderno/Big Tech")
**Como funciona:** O banco dispara um evento para uma função serverless (ex: AWS Lambda ou Supabase Edge Function em JS/TS) que processa e devolve o dado.
*   **✅ Prós:**
    *   **Desacoplamento:** A lógica fica em código (TypeScript), fácil de testar, versionar e mudar de banco se precisar.
    *   **Escalabilidade:** Para cálculos muito pesados (ex: IA), não sobrecarrega o banco.
*   **❌ Contras:**
    *   **Complexidade:** Exige configuração de ambiente serverless (Supabase Functions).
    *   **Custo/Start:** Cold starts (tempo de inatividade) podem atrasar a execução.

### 3. Webhooks / Round-Trip (A sua pergunta)
**Como funciona:** O banco avisa um servidor externo (n8n/Node), que calcula e manda um `INSERT` de volta.
*   **✅ Prós:** Fácil visualização em fluxos (n8n).
*   **❌ Contras (Por que evitamos):**
    *   **Latência:** O dado viaja Ida e Volta pela rede.
    *   **Pontos de Falha:** Se a internet oscilar ou o n8n travar no meio, você fica com o banco inconsistente (tarefa concluída, mas a nova não existe).
    *   **Race Conditions:** Risco de conflitos se o usuário editar a tarefa enquanto o webhook viaja.

## Veredito para o Sincro App (Self-Hosted)

Para operações de **Integridade de Dados Crítica** (como garantir que uma tarefa recorrente sempre exista), a abordagem via **SQL Trigger (Opção 1)** é a mais segura e eficiente para sua infraestrutura atual.

Ela garante que o sistema seja robusto: "Se está no banco, está correto".

A estratégia das "Grandes Empresas" para algo simples assim (soma de datas e cópia de linhas) também costuma ser feita próxima ao dado (Stored Procedures) ou em camadas muito rápidas de serviço. Usar Webhooks (Opção 3) para lógica de negócio "core" é considerado anti-padrão (bad practice) devido à fragilidade.

**Recomendação:** Mantenha o Trigger SQL. É a solução "Enterprise Grade" para consistência.
