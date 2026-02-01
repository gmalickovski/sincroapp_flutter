# SINCROAPP STACK RULES (FLUTTER, SUPABASE, N8N)

## 1. FLUTTER & WEB (FRONTEND)

- **NON-BLOCKING UI**: A UI deve rodar a 60fps. Processamento pesado vai para Isolate ou Backend.

### STATE MANAGEMENT
- **Separe UI de Lógica**: Widgets apenas renderizam.
- **Trate estados de Future**: `loading`, `data`, `error`. Nunca deixe o usuário sem feedback visual.

### WEB (HTML/TAILWIND)
- **Mobile First**: Classes base para mobile, `md:`/`lg:` para desktop.
- **Use classes utilitárias**: Evite CSS customizado pesado.

## 2. SUPABASE (SELF-HOSTED)

- **RLS (ROW LEVEL SECURITY)**: Obrigatório em **TODAS** as tabelas. Validação via `auth.uid()`.
- **STORAGE**: Redimensione/comprima imagens no client (Flutter) **ANTES** do upload para poupar banda da VPS.
- **REALTIME**: Use com parcimônia para economizar CPU. Prefira "fetch on demand" para dados estáticos.

## 3. N8N & AI (AUTOMATION)

- **FIRE-AND-FORGET**: O App envia dados e **NÃO** espera a IA processar.
- **Fluxo**: App -> Webhook n8n -> (App libera UI) -> n8n processa -> n8n atualiza DB.
- **ROBUSTEZ**: O App deve lidar com a possibilidade do n8n estar offline (retry policies).
- **SEGURANÇA WEBHOOK**: Valide headers secretos no n8n para garantir que a requisição veio do seu App.

## 4. STRIPE (PAYMENTS)

- **FONTE DA VERDADE**: Liberação de Premium **APENAS** via Webhook do Stripe processado no Backend.
- **FRONTEND**: O retorno do App é apenas informativo. Nunca confie no cliente para liberar acesso.
- **IDEMPOTÊNCIA**: Use `idempotency_key` para evitar cobranças duplas.
