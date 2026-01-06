# Sistema de Compartilhamento - Sprint 1: Username & Mentions

## 🎯 Objetivo
Implementar sistema de menções `@usuario` em tarefas, com reconhecimento automático no texto e seleção via modal.

---

## Sprint 1: Backend & Username Setup

### 1.1 Modelo de Dados
- [ ] **UserModel** - Adicionar campo `username`
  - Arquivo: `lib/models/user_model.dart`
  - Adicionar: `final String? username;`
  - Atualizar: construtores, `copyWith`, `toJson`, `fromJson`

### 1.2 Serviço de Backend
- [ ] **SupabaseService** - Métodos de Username
  - Arquivo: `lib/services/supabase_service.dart`
  - Novo método: `Future<bool> isUsernameAvailable(String username)`
  - Novo método: `Future<UserModel?> getUserByUsername(String username)`
  - Novo método: `Future<List<UserModel>> searchUsersByUsername(String query, {int limit = 10})`
  - Atualizar: `_mapUserFromSupabase()` para incluir `username`
  - Atualizar: `updateUserData()` para aceitar `username`

### 1.3 Validação de Username
- [ ] **Username Validator**
  - Criar: `lib/common/utils/username_validator.dart`
  - Regex: `^[a-z0-9_.]{3,30}$`
  - Método: `isValidFormat(String username)`
  - Método: `sanitize(String username)` - converter para lowercase
  - Mensagens de erro customizadas

---

## Sprint 2: Contact Picker Modal

### 2.1 Estrutura de Contatos
- [ ] **ContactModel**
  - Criar: `lib/models/contact_model.dart`
  - Campos: `userId`, `username`, `displayName` (nome completo)
  - Método: `fromUserModel(UserModel user)`

### 2.2 Modal de Seleção
- [ ] **ContactPickerModal**
  - Criar: `lib/common/widgets/contact_picker_modal.dart`
  - Design: Similar a TagPickerModal/GoalPickerModal
  - Header: "Adicionar Contato" + ícone de fechar
  - Campo de busca: TextField com ícone de lupa
  - Lista de resultados: Scroll infinito com autocomplete
  - Estado vazio: "Digite @ ou nome de usuário"
  - Estado de carregamento: Spinner
  - Item de contato: Avatar (inicial) + @username + nome completo
  - Botão de seleção: Checkmark quando selecionado
  - Footer: Contador "X contatos selecionados"

### 2.3 Integração com Backend
- [ ] **Contact Search Service**
  - Debounce de 300ms para evitar buscas excessivas
  - Cache local de resultados recentes
  - Limitar a 10 resultados por busca

---

## Sprint 3: Mention Recognition System

### 3.1 Text Field com Mentions
- [ ] **MentionTextField**
  - Criar: `lib/common/widgets/mention_text_field.dart`
  - Baseado em: `RichTextField` ou usar pacote `flutter_mentions`
  - Detectar: `@` como trigger para autocomplete
  - Exibir: Dropdown de sugestões abaixo do cursor
  - Estilizar: `@usuario` em **azul** no texto
  - Callback: `onMentionAdded(String username)`
  - Callback: `onMentionRemoved(String username)`

### 3.2 Mention Parser
- [ ] **Mention Parser Utility**
  - Criar: `lib/common/utils/mention_parser.dart`
  - Método: `List<String> extractMentions(String text)` - extrair todos @usuarios do texto
  - Método: `String highlightMentions(String text)` - HTML/RichText com mentions coloridas
  - Método: `bool hasMentions(String text)`

### 3.3 Cor do Sistema (Azul)
- [ ] **Definir Cor de Contatos**
  - Arquivo: `lib/common/constants/app_colors.dart`
  - Adicionar: `static const Color contact = Color(0xFF64B5F6);` (Azul claro/médio)
  - OU usar: `Colors.lightBlue.shade400` (similar a DateTime = amber, Goal = cyan)

---

## Sprint 4: Integração com Task System

### 4.1 TaskModel - Compartilhamento
- [ ] **Atualizar TaskModel**
  - Arquivo: `lib/models/task_model.dart`
  - Adicionar: `final List<String> sharedWithUsernames;` (lista de @usuarios)
  - Atualizar: `toJson`, `fromJson`, `copyWith`

### 4.2 TaskInputModal - UI
- [ ] **Adicionar Botão de Contatos**
  - Arquivo: `lib/features/tasks/presentation/widgets/task_input_modal.dart`
  - Localização: Row com ícones (Schedule, Goal, Tag, **+ Contact**)
  - Ícone: `Icons.person_add_outlined` ou `Icons.contacts_outlined` (azul quando ativo)
  - Posição: Após Tags, antes de fechar modal
  - Badge: Mostrar número de contatos se > 0 (ex: "3")

- [ ] **TextField com Mention Recognition**
  - Substituir: TextField atual por `MentionTextField`
  - Trigger `@`: Abrir autocomplete inline
  - Ao selecionar: Inserir `@usuario` no texto
  - Salvar: Parsear texto e extrair mentions antes de salvar

- [ ] **Modal de Contatos (Fallback)**
  - Botão abre `ContactPickerModal`
  - Ao selecionar: Inserir `@usuario` no final do texto atual
  - Feedback visual: Contador atualizado

### 4.3 TaskDetailModal - UI
- [ ] **Adicionar Seção de Contatos**
  - Arquivo: `lib/features/tasks/presentation/widgets/task_detail_modal.dart`
  - Localização: Após Tags, antes do botão Save
  - Design: Similar a Tags (Chips horizontais)
  - Ícone: `Icons.person_outline` (azul)
  - Label: "Compartilhado com"
  - Chips: `@usuario` com ícone de remover (X)
  - Botão "+": Abrir `ContactPickerModal`

- [ ] **Edição de Contatos**
  - Ao adicionar: Atualizar `_sharedWithUsernames`
  - Ao remover: Atualizar lista
  - Integrar com mention parser: Sincronizar com texto

---

## Sprint 5: Backend de Compartilhamento

### 5.1 Tabela de Tarefas Compartilhadas
- [ ] **Adicionar campo em tasks**
  - SQL: `ALTER TABLE sincroapp.tasks ADD COLUMN shared_with_usernames TEXT[];`
  - OU usar: Tabela `shared_items` (abordagem do plano original)
  - Decisão: Array em `tasks` é mais simples para MVP

### 5.2 SupabaseService - Tasks
- [ ] **Atualizar Métodos de Task**
  - `createTask()`: Salvar `shared_with_usernames`
  - `updateTask()`: Atualizar compartilhamentos
  - `getTasksForUser()`: Incluir tarefas compartilhadas comigo
  - Query: `WHERE user_id = uid OR uid = ANY(shared_with_usernames)`

### 5.3 Notificações N8N
- [ ] **Evento de Compartilhamento**
  - Evento: `task_shared`
  - Payload: `{ task_id, task_title, shared_by, shared_with: [@usuarios] }`
  - Trigger: Quando `shared_with_usernames` é modificado

---

## Sprint 6: Verificação & Polish

### 6.1 Testes de UX
- [ ] Criar tarefa com `@usuario` no texto → salva corretamente
- [ ] Abrir modal de contatos → busca funciona
- [ ] Autocomplete `@` → sugestões aparecem
- [ ] TaskDetailModal → chips de contatos aparecem
- [ ] Editar contatos → sincroniza com texto

### 6.2 Edge Cases
- [ ] Username inválido no texto → ignorar ou destacar erro
- [ ] Mention de usuário que não existe → validar antes de salvar
- [ ] Remover mention do texto → remover do array
- [ ] Múltiplas mentions do mesmo usuário → contar como 1

### 6.3 Indicadores Visuais
- [ ] **Task Cards** - Badge "👥 2" quando compartilhada
- [ ] **Task Detail** - Ícone azul no header se compartilhada
- [ ] **Foco do Dia** - Diferenciar tarefas próprias vs compartilhadas

---

## Cores do Sistema (Para Referência)

```dart
// Cores existentes
static const Color primary = Color(0xFF9C27B0);      // Roxo - Principal
static const Color dateTime = Colors.amber;          // Âmbar - Agendamento
static const Color goal = Colors.cyan;               // Ciano - Metas
static const Color tag = Colors.purple;              // Roxo - Tags

// Nova cor
static const Color contact = Color(0xFF64B5F6);      // Azul claro - Contatos
// OU
static const Color contact = Colors.lightBlue.shade400;
```

---

## Ordem de Implementação Recomendada

### Fase A: Fundação (2-3h) ✅ COMPLETA
1. ✅ UserModel + username
2. ✅ SupabaseService (métodos de busca)
3. ✅ Username Validator
4. ✅ Adicionar cor `contact`

### Fase B: Contact Picker (2h) ✅ COMPLETA
5. ✅ ContactModel
6. ✅ ContactPickerModal (UI + busca)
7. ✅ Integração com backend (SupabaseService methods)
   - ✅ Adicionado `user_contacts` table no SQL
   - ✅ Adicionado Gerenciamento de Contatos no Settings

### Fase C: Mentions (3-4h) ✅ COMPLETA
8. ✅ MentionTextField (autocomplete `@`)
   - ✅ Implementado `MentionTextEditingController`
   - ✅ Implementado `MentionInputField` com overlay
9. ✅ Parser de menções (regex)
   - ✅ `UsernameValidator.extractMentionsFromText`

### Fase D: Integração Tasks (3h) ✅ COMPLETA
10. ✅ Atualizar `TaskModel` (campo `sharedWith`)
11. ✅ Adicionar suporte no `TaskInputModal`
    - ✅ Substituído TextField por MentionInputField
    - ✅ Botão de adicionar contato via `ContactPickerModal`
12. ✅ Persistência backend (`addTask`/`updateTask`)
    - ✅ Parse automático de mentions
    - ✅ Persistence na coluna `shared_with` (tasks) e `user_contacts` (settings)DetailModal (seção de contatos)

### Fase E: Backend Final (1-2h)
14. Atualizar Supabase tasks
15. SupabaseService (salvar/carregar)
16. Notificações N8N

### Fase F: Polish (1h)
17. Badges visuais
18. Testes de UX
19. Documentação

---

## Progresso

- [ ] Sprint 1: Backend & Username Setup
- [ ] Sprint 2: Contact Picker Modal
- [ ] Sprint 3: Mention Recognition
- [ ] Sprint 4: Task Integration
- [ ] Sprint 5: Backend Sharing
- [ ] Sprint 6: Polish

---

**Última Atualização:** 06/01/2026  
**Status:** 🚧 Pronto para Fase A
