# SincroApp — CLAUDE.md

## Projeto
App Flutter multiplataforma (iOS, Android, Web) de produtividade + numerologia cabalística.
Stack: Flutter 3.x · Supabase (self-hosted) · Firebase Auth/Messaging · Vertex AI (Gemini) · Node.js backend (PM2, porta 4545) · Nginx · VPS.
Repo: https://github.com/gmalickovski/sincroapp_flutter.git
Versão atual: `pubspec.yaml` / `package.json` (v1.7.x).

---

## Arquitetura
```
lib/
  common/          # widgets, constants (app_colors.dart), utils
  features/        # por feature (auth, dashboard, goals, journal, tasks, ai…)
server/            # backend Node.js
.github/workflows/ # deploy-web.yml (CI/CD)
.agent/rules/      # regras detalhadas de stack e design
```

---

## Stack Rules

### Flutter
- UI 60fps. Lógica pesada → `Isolate` ou backend.
- Separar UI de lógica. Tratar estados: `loading` / `data` / `error`.
- Sem `hardcoded width`. Usar `Flex`, `Expanded`, `MediaQuery`.
- Sempre `SafeArea` na tela principal.
- Todo elemento clicável: mínimo **48×48dp**.
- Streams/Controllers/Timers → `dispose()` obrigatório.

### Supabase
- RLS obrigatório em **todas** as tabelas (`auth.uid()`).
- Nunca `SELECT *` — selecionar só campos necessários.
- Paginação obrigatória em listas (`limit` + `offset`).
- Redimensionar/comprimir imagens no client antes do upload.
- Realtime com parcimônia; preferir fetch-on-demand para dados estáticos.

### Stripe / Payments
- Liberação de premium **somente** via webhook do Stripe no backend.
- Nunca confiar no cliente para liberar acesso.
- Usar `idempotency_key`.

### n8n / AI
- Fire-and-forget: App envia e libera UI. n8n processa e atualiza DB.
- Validar header secreto nos webhooks n8n.
- App deve lidar com n8n offline (retry policy).

---

## Design System

**Tema:** Dark Mode only. Fundo `#111827` · Cards `#1F2937` · Primary `#7C3AED`.

| Token | Valor |
|---|---|
| Background | `#111827` |
| Surface (cards) | `#1F2937` |
| Border | `#4B5563` |
| Primary | `#7C3AED` (purple-600) |
| Secondary | `#A78BFA` (purple-400) |
| Text Primary | `#FFFFFF` |
| Text Secondary | `#D1D5DB` |
| Text Tertiary | `#9CA3AF` |
| Task | `#3B82F6` · Goal `#EC4899` · Journal `#14B8A6` |

**Grid 8pt:** Todo espaçamento múltiplo de 8. Padrão: `16px`. Mobile margin `16px`, Web max-width `1280px`.
**Shapes:** Cards `BorderRadius.circular(16)` · Inputs/Botões `BorderRadius.circular(12)`.
**Tipografia:** Poppins (400/600/700). Body mínimo `16px` (evita zoom iOS).
**Contraste:** Texto branco em fundos escuros. Texto `#111827` em pills claras (amarelo/ciano). Nunca cinza sobre cinza escuro.

---

## Segurança (CRÍTICO)
- **NUNCA** commitar chaves/secrets/tokens no código.
- Secrets via variáveis de ambiente (`.env` no `.gitignore`).
- `.env` no Flutter via `flutter_dotenv`.
- Client: somente `ANON_KEY`. Server: `SERVICE_ROLE`, `STRIPE_SECRET`.
- Sem I/O síncrono. Usar `async/await`, `Future`, `Stream`.

---

## Git — Conventional Commits

```
tipo(escopo): descrição breve
```

| Tipo | Versão | Uso |
|---|---|---|
| `feat:` | MINOR | Nova funcionalidade |
| `fix:` | PATCH | Correção de bug |
| `perf:` | PATCH | Performance |
| `refactor:` | — | Sem feature/fix |
| `chore:` | — | Manutenção, build |
| `docs:` | — | Documentação |
| `sec:` | PATCH | Segurança (prioritário) |
| `feat!:` / `BREAKING CHANGE:` | MAJOR | Quebra de compatibilidade |

---

## Fluxo de Deploy (dia a dia)

```bash
# 1. Commitar mudanças
git add .
git commit -m "feat|fix|chore: descrição"

# 2. Gerar release (bump versão + tag + changelog)
npm run release

# 3. Push com tags → dispara GitHub Actions
git push --follow-tags
```

**O que `npm run release` faz:** lê commits → define bump (MAJOR/MINOR/PATCH) → atualiza `package.json`, `server/package.json`, `pubspec.yaml` → atualiza `CHANGELOG.md` → cria commit `chore(release): X.Y.Z` → cria tag `vX.Y.Z`.

**GitHub Actions** (`.github/workflows/deploy-web.yml`): dispara em push de tag `v*` → `flutter build web --release --base-href /app/` → SCP para VPS → `git pull` + `npm install` + PM2 restart + `nginx reload`.

**VPS:** `/var/www/webapp/sincroapp_flutter` · SSH porta `2222` · Backend porta `4545`.
**Secrets no GitHub:** `VPS_HOST`, `VPS_USERNAME`, `VPS_SSH_KEY`, `ENV_FILE`.

---

## Skills Úteis
- `/commit` — formata commit com Conventional Commits
- `/simplify` — revisa código alterado para qualidade/reuso
- `/schedule` — cria tarefa agendada

---

## Regras Detalhadas
Ver `.agent/rules/` para detalhes completos:
- `01-security-core.md` — segurança e VPS
- `02-stack-rules.md` — Flutter, Supabase, n8n, Stripe
- `03-design-rules.md` — UI/UX, grid, tipografia
- `04-branding.md` — cores, componentes, contraste
