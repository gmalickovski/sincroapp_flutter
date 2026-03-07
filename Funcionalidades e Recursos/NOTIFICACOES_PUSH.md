# 🔔 Sistema de Notificações Push — SincroApp

> Documentação completa do sistema de notificações push profissional e escalável.
> Última atualização: 2026-03-06 | Status: ✅ **Operacional**

---

## Visão Geral

O SincroApp utiliza um sistema **event-driven** para notificações push, rodando 100% dentro da infraestrutura do **Supabase self-hosted** (Edge Functions + pg_cron), sem dependência do servidor VPS para notificações.

### Stack de Tecnologias

| Componente | Tecnologia | Função |
|---|---|---|
| **Banco de Dados** | Supabase PostgreSQL (self-hosted) | Armazena tarefas, lembretes agendados, tokens FCM |
| **Agendamento** | `pg_cron` + `pg_net` | Executa jobs a cada minuto/hora/dia |
| **Lógica** | Supabase Edge Functions (Deno) | Processa lembretes e envia pushes |
| **Push Delivery** | Firebase Cloud Messaging (FCM) HTTP v1 | Entrega push para Android, iOS, Web, Desktop |
| **Client** | Flutter (`firebase_messaging`) | Recebe push e exibe notificações locais |

### Infraestrutura

| Recurso | Valor |
|---|---|
| **Supabase URL** | `https://supabase.studiomlk.com.br` |
| **Firebase Project ID** | `sincroapp-a0636` |
| **VPS** | Self-hosted com Docker Compose |
| **Edge Functions Path** | `/var/www/app/supabase/volumes/functions/` |

---

## Arquitetura Geral

```mermaid
graph TD
    subgraph "📱 Flutter App"
        A["Usuário cria/edita tarefa"] -->|"Salva reminder_offsets + due_date"| B["Supabase: sincroapp.tasks"]
        AA["App inicia"] -->|"Registra FCM token"| CC["Supabase: user_push_tokens"]
    end
    
    subgraph "🗄️ Supabase Database"
        B -->|"Trigger automático"| D["Postgres Function:<br/>sync_task_reminders()"]
        D -->|"Calcula fire_at e insere"| E["sincroapp.task_reminders"]
    end
    
    subgraph "⏱️ pg_cron Jobs"
        F["Job 1: send-task-reminders<br/>* * * * * (cada 1 min)"]
        G["Job 2: morning-notification<br/>30 11 * * * (08:30 BRT)"]
        H["Job 3: evening-review<br/>0 23 * * * (20:00 BRT)"]
        I["Job 4: cleanup-old-reminders<br/>0 3 * * * (03:00 UTC)"]
    end
    
    subgraph "⚡ Edge Functions (Deno)"
        F -->|"pg_net HTTP POST"| J["send-task-reminders/"]
        G -->|"pg_net HTTP POST"| K["morning-notification/"]
        H -->|"pg_net HTTP POST"| L["evening-review/"]
    end
    
    J -->|"Query fire_at <= now()"| E
    J -->|"Busca tokens"| CC
    K -->|"Busca tokens"| CC
    L -->|"Query tarefas pendentes"| B
    L -->|"Busca tokens"| CC
    
    J & K & L -->|"FCM HTTP v1 API<br/>(JWT OAuth2)"| M["Firebase Cloud Messaging"]
    M -->|"Push nativo"| N["📱 Android / iOS / Web / Desktop"]
    
    style J fill:#4CAF50,color:#fff
    style K fill:#FF9800,color:#fff
    style L fill:#2196F3,color:#fff
    style D fill:#9C27B0,color:#fff
    style I fill:#607D8B,color:#fff
```

---

## Tabelas do Banco de Dados

### `sincroapp.tasks` (Campos relevantes para notificações)

| Coluna | Tipo | Descrição |
|---|---|---|
| `id` | uuid | ID da tarefa |
| `user_id` | uuid | Dono da tarefa |
| `text` | text | Texto da tarefa |
| `due_date` | timestamptz | Data/hora do agendamento |
| `completed` | boolean | Se está concluída |
| `reminder_offsets` | jsonb | Array de minutos antes do due_date: `[0, 10, 30]` |
| `reminder_at` | timestamptz | Legado: horário fixo do lembrete |
| `journey_title` | text | Título da jornada (para contexto no push) |

> **Colunas removidas:** `reminder_hour`, `reminder_minute`, `shared_from_user_id`, `reminder_sent` (não eram mais usadas)

### `sincroapp.task_reminders` ⭐ Nova

| Coluna | Tipo | Descrição |
|---|---|---|
| `id` | uuid | ID do lembrete (PK, auto-gerado) |
| `task_id` | uuid | FK → tasks.id (CASCADE DELETE) |
| `user_id` | uuid | Dono (denormalizado para performance) |
| `offset_minutes` | integer | Offset em minutos (0 = na hora exata) |
| `fire_at` | timestamptz | **Horário exato de disparo** (pré-calculado) |
| `sent` | boolean | Se já foi enviado (default: false) |
| `sent_at` | timestamptz | Quando foi enviado |

> **Cada offset = 1 row.** Se uma tarefa tem `reminder_offsets: [0, 10, 30]`, a trigger cria 3 rows, cada uma com `fire_at = due_date - offset_minutes`.

**Indexes:**
- `idx_task_reminders_fire_at` → Busca rápida de lembretes vencidos
- `idx_task_reminders_task_id` → Join com tasks
- `idx_task_reminders_user_id` → Busca por usuário

### `sincroapp.user_push_tokens`

| Coluna | Tipo | Descrição |
|---|---|---|
| `user_id` | uuid | ID do usuário |
| `fcm_token` | text | Token FCM do dispositivo |

---

## Trigger: `sync_task_reminders()`

Trigger automático na tabela `tasks` (INSERT e UPDATE) que:

1. **Deleta** lembretes antigos não enviados da tarefa
2. **Calcula** `fire_at` para cada offset: `due_date - (offset * interval '1 minute')`
3. **Insere** novos rows em `task_reminders`
4. **Ignora** tarefas sem `due_date` ou sem `reminder_offsets`

```mermaid
flowchart LR
    A["INSERT/UPDATE<br/>tasks"] --> B{"Tem due_date<br/>e reminder_offsets?"}
    B -->|Não| C["Nada acontece"]
    B -->|Sim| D["DELETE reminders<br/>não enviados"]
    D --> E["INSERT novos reminders<br/>com fire_at calculado"]
```

---

## pg_cron Jobs (4 Agendamentos)

| Job | Schedule (UTC) | Horário BRT | Função |
|---|---|---|---|
| **1** | `* * * * *` | Cada 1 minuto | `send-task-reminders` — Busca lembretes vencidos e envia push |
| **2** | `30 11 * * *` | 08:30 | `morning-notification` — Push matinal motivacional |
| **3** | `0 23 * * *` | 20:00 | `evening-review` — Push noturno com tarefas pendentes |
| **4** | `0 3 * * *` | 00:00 | Limpeza de lembretes enviados há mais de 7 dias |

**Verificar jobs:**
```sql
SELECT * FROM cron.job;
SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 10;
```

---

## Fluxos Detalhados

### Fluxo 1: Lembrete de Tarefa

```mermaid
sequenceDiagram
    participant U as 📱 Flutter App
    participant DB as 🗄️ Supabase DB
    participant TR as ⚙️ Trigger
    participant CR as ⏱️ pg_cron
    participant EF as ⚡ Edge Function
    participant FCM as 🔥 Firebase

    U->>DB: INSERT/UPDATE task<br/>(reminder_offsets: [0, 10])
    DB->>TR: Trigger: sync_task_reminders()
    TR->>DB: DELETE reminders antigos (sent=false)
    TR->>DB: INSERT 2 rows em task_reminders<br/>fire_at = due_date - 0min<br/>fire_at = due_date - 10min
    
    Note over CR: A cada 60 segundos...
    CR->>EF: HTTP POST /send-task-reminders
    EF->>DB: SELECT * FROM task_reminders<br/>WHERE fire_at <= now() AND sent = false
    EF->>DB: SELECT fcm_token FROM user_push_tokens
    EF->>FCM: POST /v1/projects/sincroapp-a0636/messages:send
    FCM-->>U: 🔔 Push notification!
    EF->>DB: UPDATE task_reminders SET sent = true
```

### Fluxo 2: Notificação Matinal (08:30 BRT)

```mermaid
sequenceDiagram
    participant CR as ⏱️ pg_cron
    participant EF as ⚡ Edge Function
    participant DB as 🗄️ Supabase DB
    participant FCM as 🔥 Firebase
    participant U as 📱 App

    Note over CR: 08:30 BRT (11:30 UTC)
    CR->>EF: HTTP POST /morning-notification
    EF->>DB: SELECT * FROM user_push_tokens
    EF->>FCM: POST para cada token
    FCM-->>U: "Bom dia! ☀️ Confira as energias de hoje"
```

### Fluxo 3: Revisão Noturna (20:00 BRT)

```mermaid
sequenceDiagram
    participant CR as ⏱️ pg_cron
    participant EF as ⚡ Edge Function
    participant DB as 🗄️ Supabase DB
    participant FCM as 🔥 Firebase
    participant U as 📱 App

    Note over CR: 20:00 BRT (23:00 UTC)
    CR->>EF: HTTP POST /evening-review
    EF->>DB: SELECT user_id, COUNT(*) FROM tasks<br/>WHERE completed = false AND due_date = today
    EF->>DB: SELECT fcm_token FROM user_push_tokens
    EF->>FCM: POST para usuários com tarefas pendentes
    FCM-->>U: "Fim de dia 🌙 Você tem 3 tarefas pendentes"
```

---

## Autenticação Firebase (JWT OAuth2)

As Edge Functions usam a **FCM HTTP v1 API** (API moderna) com autenticação JWT:

```mermaid
sequenceDiagram
    participant EF as ⚡ Edge Function
    participant GA as 🔐 Google Auth
    participant FCM as 🔥 FCM API

    EF->>EF: Lê FIREBASE_SERVICE_ACCOUNT (env)
    EF->>EF: Cria JWT (RS256) com:<br/>scope: firebase.messaging<br/>iss: client_email<br/>aud: token_uri
    EF->>GA: POST /token (grant_type=jwt-bearer)
    GA-->>EF: access_token (válido 1h)
    EF->>FCM: POST /v1/projects/sincroapp-a0636/messages:send<br/>Authorization: Bearer {access_token}
    FCM-->>EF: 200 OK (push enviado)
```

> A chave privada RSA do service account é usada para assinar o JWT. Não é necessário nenhum SDK do Firebase — tudo é feito via HTTP puro.

---

## Arquivos do Sistema

### Edge Functions (`/var/www/app/supabase/volumes/functions/`)

| Arquivo | Descrição |
|---|---|
| `send-task-reminders/index.ts` | Processa lembretes vencidos e envia push via FCM |
| `morning-notification/index.ts` | Push matinal para todos os usuários |
| `evening-review/index.ts` | Push noturno para quem tem tarefas pendentes |

### SQL Migrations

| Arquivo | Descrição |
|---|---|
| `20260306_notification_system.sql` | Tabela `task_reminders`, trigger, indexes, RLS, backfill |
| `20260306_pgcron_schedule.sql` | Agendamento pg_cron para as 3 Edge Functions + cleanup |

### Flutter (Client)

| Arquivo | Descrição |
|---|---|
| `lib/features/tasks/models/task_model.dart` | Model com `reminderOffsets` (jsonb array) |
| `lib/services/supabase_service.dart` | Salva/lê offsets + due_date no Supabase |

### Docker (Self-Hosted)

| Arquivo | Descrição |
|---|---|
| `docker-compose.yml` | Serviço `functions` com Firebase env vars |
| `.env` | `FIREBASE_SERVICE_ACCOUNT` e `GOOGLE_PROJECT_ID` |

---

## Variáveis de Ambiente

Configuradas no `.env` do Supabase (`/var/www/app/supabase/.env`):

| Variável | Descrição | Origem |
|---|---|---|
| `GOOGLE_PROJECT_ID` | `sincroapp-a0636` | Firebase Console |
| `FIREBASE_SERVICE_ACCOUNT` | JSON completo do service account | Firebase Console → Configurações → Contas de serviço |

> As variáveis `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` e `SUPABASE_ANON_KEY` são injetadas automaticamente pelo Docker Compose.

---

## Escalabilidade

| Métrica | Capacidade |
|---|---|
| **Usuários simultâneos** | ~1.000.000+ (FCM gerencia fan-out) |
| **Lembretes/minuto** | ~100 por batch (Edge Function limit) |
| **Precisão** | ± 1 minuto (granularidade pg_cron) |
| **Custo quando ocioso** | Zero (event-driven, sem polling) |
| **Resiliência** | Docker auto-restart, pg_cron persistente |

### Comparação: Antes vs Agora

| Aspecto | ❌ Antes (Polling VPS) | ✅ Agora (Event-Driven) |
|---|---|---|
| **Mecanismo** | `setInterval(60s)` no Node.js | pg_cron + Edge Functions |
| **Dependência** | VPS deve estar online | Supabase gerenciado (Docker) |
| **Tracking** | `reminder_sent` (por task) | `task_reminders.sent` (por offset) |
| **Escalabilidade** | ~1.000 users | ~1.000.000+ users |
| **Precisão** | ± 60s + latência de rede | ± 60s (local ao banco) |
| **Custo CPU** | Constante (polling) | Zero quando ocioso |
| **Código removido** | — | ~190 linhas de `index.js` |

---

## Manutenção

### Verificar se está funcionando
```sql
-- Jobs agendados
SELECT * FROM cron.job;

-- Últimas execuções
SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 10;

-- Lembretes pendentes
SELECT * FROM sincroapp.task_reminders WHERE sent = false ORDER BY fire_at;

-- Lembretes enviados recentemente
SELECT * FROM sincroapp.task_reminders WHERE sent = true ORDER BY sent_at DESC LIMIT 10;
```

### Logs da Edge Function
```bash
# Na VPS
docker logs supabase-edge-functions --tail 50 -f
```

### Testar manualmente uma Edge Function
```bash
curl -X POST https://supabase.studiomlk.com.br/functions/v1/send-task-reminders \
  -H "Authorization: Bearer SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{}'
```

### Recriar jobs (se necessário)
```sql
-- Remover todos os jobs
SELECT cron.unschedule(jobid) FROM cron.job;

-- Re-execute o arquivo 20260306_pgcron_schedule.sql
```
