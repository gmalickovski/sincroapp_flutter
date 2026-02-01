# 🛡️ SincroApp Core Rules (Security & VPS)

> **System Context**: These rules are **MANDATORY** for all modules and agents operating within the SincroApp ecosystem. Failure to comply violates the security and performance integrity of the VPS environment.

## 0. Security Zero-Trust `[CRITICAL]`

**Supreme Rule**: NEVER commit keys, passwords, or tokens to version control.

### 🚫 No Hardcoding
*   **Absolute Ban**: Never write `API_KEY`, `SECRET`, `SERVICE_ROLE`, or passwords directly in source code.
*   **Enforcement**: All secrets must be injected via Environment Variables.

### 📂 Environment Management (.env)
*   **Mechanism**: Use **ONLY** environment variables loaded from `.env` files in the root directory.
    *   **Flutter**: Implementation via `flutter_dotenv`.
    *   **Docker/Nginx**: Injection via `--env-file` or Docker Secrets.
*   **Git Security**: The `.env` file must ALWAYS be included in `.gitignore`.

### 🔐 Segregation of Duties
*   **Client Side (App/Web)**: Permitted to hold **ONLY** public keys (e.g., `ANON_KEY`).
*   **Server Side (n8n/VPS)**: Exclusive holder of administrative keys (e.g., `SERVICE_ROLE`, `STRIPE_SECRET`).

---

## 1. Performance VPS `[RESOURCE EFFICIENCY]`

**Context**: Operations are executed on a resource-constrained VPS. Code optimization is not optional; it is mandatory.

### ⚡ Async First Architecture
*   **⛔ PROHIBITED**: Synchronous I/O operations (e.g., `File.readAsStringSync`, HTTP requests without `await`).
*   **✅ MANDATORY**: Use `async`/`await`, `Future`, and `Stream` for all interactions involving Database, External APIs, or Disk I/O.

### 🧹 Memory Management (Leak Prevention)
*   **Lifecycle**: Every `StreamSubscription`, `Controller`, or `Timer` **MUST** have a corresponding `dispose()` call.
*   **Listeners**: Do not keep listeners active strictly longer than necessary.

### 🗄️ Database Optimization (Supabase)
*   **Selective Queries**: Never execute `SELECT *`. Explicitly select only the required fields.
*   **Pagination**: **MANDATORY** for all list views (`limit` and `offset`). Never load entire tables into application memory.

---

## 2. Git Conventions `[VERSION CONTROL]`

**Standard**: Semantic Commit Messages

| Type | Description |
| :--- | :--- |
| `feat:` | A new feature |
| `fix:` | A bug fix |
| `perf:` | A code change that improves performance |
| `refactor:` | A code change that neither fixes a bug nor adds a feature |
| `sec:` | Security vulnerabilities/fixes **(Priority)** |

> **Requirement**: Commit messages must be clear, objective, and strictly follow this format.
