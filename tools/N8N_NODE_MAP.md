# Mapa de Atualização de Nós (V6) 🗺️

Com base na sua imagem e nos arquivos atualizados, aqui está exatamente qual arquivo copiar para cada nó do seu Workflow.

---

## 🟢 1. Cabeça (Início)

| Nó na Imagem | Arquivo na pasta `tools/` | O que fazer |
| :--- | :--- | :--- |
| **Parsing Router JSON** | `tools/n8n_parse_router_json.js` | Copiar conteúdo para "JavaScript Code". |
| **Router LLM (AI Agent)** | `tools/router_system_prompt.md` | Copiar conteúdo para "System Message". |

> **⚠️ Importante**: No **Router LLM**, além do System Message, você precisa colar a "Expressão de Histórico" no campo `Text`. (Veja arquivo `N8N_UPDATED_CODES_BATCH.md`).

---

## 🔵 2. Ramo Superior (Numerologia)

| Nó na Imagem | Arquivo na pasta `tools/` | O que fazer |
| :--- | :--- | :--- |
| **Code Numerology** | `tools/numerology_engine.js` | Copiar conteúdo para "JavaScript Code". |
| **AI Agent 1** | `tools/worker_numerology_system_prompt.md` | Copiar conteúdo para "System Message". |

---

## 🟠 3. Ramo do Meio (RAG / Dados)

| Nó na Imagem | Arquivo na pasta `tools/` | O que fazer |
| :--- | :--- | :--- |
| **Parse Date Range** | `tools/n8n_data_retrieval_parser.js` | Copiar conteúdo para "JavaScript Code". |
| **Format Tasks Response** | `tools/n8n_data_retrieval_formatter.js` | Copiar conteúdo para "JavaScript Code". |
| **AI Agent 2** | `tools/worker_data_retrieval_prompt.md` | Copiar conteúdo para "System Message". |

---

## 🟣 4. Ramo Inferior (Ação / Chitchat)

| Nó na Imagem | Arquivo na pasta `tools/` | O que fazer |
| :--- | :--- | :--- |
| **Numerology Calculator** | `tools/n8n_numerology_calculator.js` | Copiar conteúdo para "JavaScript Code". |
| **AI Agent 3** | (Sem arquivo externo) | Use a **Expressão de Histórico** do `N8N_UPDATED_CODES_BATCH.md` no campo `Text`. |

---

## ⚫ 5. Final (Cauda)

| Nó na Imagem | Arquivo na pasta `tools/` | O que fazer |
| :--- | :--- | :--- |
| **Final Response** | `tools/n8n_format_response_final.js` | **CRÍTICO**: Copiar este novo código para corrigir balões vazios. |
