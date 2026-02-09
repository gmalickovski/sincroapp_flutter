# Guia de Configuração SincroFlow + Vector Store (N8N)

Para dar "superpoderes" de memória ao seu agente, vamos conectá-lo à sua base vetorial no Supabase.

## 1. Arquivos Atualizados
-   `n8n/SINCROFLOW_SYSTEM_MESSAGE.txt`: Atualizado para instruir o agente a *buscar* informações na base em vez de ler um texto fixo.

## 2. Configurando o Nó "AI Agent"

### A. System Message (Mensagem do Sistema)
1.  Copie o conteúdo de `n8n/SINCROFLOW_SYSTEM_MESSAGE.txt`.
2.  Cole no campo **System Message** do seu Agente.

### B. User Message (Mensagem do Usuário)
1.  Mantenha o conteúdo de `n8n/SINCROFLOW_USER_MESSAGE.txt` no campo **User Message**.

---

## 3. Configurando o Nó "Postgres PGVector Store" (Tool)

### A. Campos Principais
*   **Operation Mode:** `Retrieve Documents (As Tool for AI Agent)`
*   **Name:** `sincroflow_knowledge`
*   **Description:**
    ```text
    Use esta ferramenta para buscar estratégias do SincroFlow, significados de numerologia e conselhos baseados no Modo do Dia (Foco, Fluxo, etc) e Dia Pessoal.
    ```
*   **Table Name:** `knowledge_base`
*   **Limit:** `4`
*   **Include Metadata:** `ON` (Ligado)

### B. Configurando o "Metadata Filter" (CRÍTICO)

Baseado nos dados que você me mostrou, esta é a configuração EXATA para isolar o SincroFlow:

Na seção **Metadata Filter**, preencha os campos assim:

*   **Name:** `source`
*   **Value:** `SINCROFLOW_KNOWLEDGE.md`

*(Isso garante que o agente só lerá linhas onde a coluna metadata contém `source: "SINCROFLOW_KNOWLEDGE.md"`, ignorando todo o resto).*

### C. Opções de Colunas (Column Names)
Selecione "Column Names" em "Add Option" e confirme:
*   **Vector Column Name:** `embedding`
*   **Content Column Name:** `content`
*   **Metadata Column Name:** `metadata`

---

## 4. Testando
Ao executar, o agente buscará estritamente as estratégias do seu arquivo SincroFlow, ignorando outros dados da tabela.
