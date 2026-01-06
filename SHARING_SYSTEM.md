# Sistema de Compartilhamento Colaborativo - Sincro App

> **Status:** 🚧 Em Desenvolvimento  
> **Última Atualização:** 06/01/2026  
> **Versão:** 1.0 (Sprint 1 - Username Foundation)

---

## 📋 Índice

- [Visão Geral](#visão-geral)
- [Fase 1: Sistema de Username](#fase-1-sistema-de-username)
- [Fase 2: Sistema de Compartilhamento](#fase-2-sistema-de-compartilhamento)
- [Fase 3: Recursos Avançados](#fase-3-recursos-avançados)
- [Progresso de Implementação](#progresso-de-implementação)
- [Comandos SQL](#comandos-sql)

---

## Visão Geral

Implementar funcionalidade de compartilhamento de **Metas, Tarefas, Eventos e Marcos** entre usuários do Sincro, utilizando **usernames únicos** como identificador de conexão.

### Objetivos Principais

1. ✅ Criar sistema de usernames únicos (@usuario)
2. 🔄 Compartilhar Goals, Tasks, Events, Milestones
3. 🔔 Notificações de compartilhamento
4. 🔒 Controle de permissões (Visualizar/Editar)

---

## Fase 1: Sistema de Username

### 1.1 Banco de Dados (Supabase)

#### Alterações na Tabela `users`

**Campo Adicionado:**
- `username` VARCHAR(30) UNIQUE
- Índice para busca rápida
- Validação de formato (regex)

**Regras de Username:**
- ✅ Formato: apenas letras minúsculas, números, `_` e `.`
- ✅ Comprimento: 3 a 30 caracteres
- ✅ Unicidade: validação no banco (UNIQUE constraint)
- ✅ Exemplos válidos: `joao_silva`, `maria.santos`, `carlos123`

#### Tabela de Auditoria (Opcional)
- `username_history` - Histórico de mudanças de username

---

### 1.2 Backend (SupabaseService)

#### Arquivos Modificados:
- `lib/models/user_model.dart` - Adicionar campo `username`
- `lib/services/supabase_service.dart` - Novos métodos:
  - `isUsernameAvailable(String username)`
  - `getUserByUsername(String username)`

**Exemplo de Validação:**
```dart
final usernameRegex = RegExp(r'^[a-z0-9_.]{3,30}$');

Future<bool> isUsernameAvailable(String username) async {
  final response = await _supabase
      .schema('sincroapp')
      .from('users')
      .select('username')
      .eq('username', username.toLowerCase())
      .maybeSingle();
  return response == null;
}
```

---

### 1.3 Frontend - Fluxo de Registro

#### Nova Tela: `UsernameSetupScreen`

**Localização no Fluxo:**
1. Usuário faz login/registro (Firebase Auth)
2. **→ NOVA TELA: UsernameSetupScreen** ← Inserir aqui
3. User Detail Screen (nome, data de nascimento)
4. Dashboard

**Recursos da Tela:**
- Input com validação em tempo real (debounce 300ms)
- Ícones de status: ✓ disponível | ✗ indisponível | ⏳ verificando
- Sugestões automáticas baseadas no email
- Regras exibidas claramente

**Validações:**
- ✅ Formato correto (regex)
- ✅ Unicidade no banco
- ✅ Comprimento mínimo/máximo

---

### 1.4 Frontend - Settings

**Nova Seção: "Perfil Público"**
```
┌─────────────────────────────────────┐
│ 👤 Perfil Público                   │
├─────────────────────────────────────┤
│ Nome de Usuário                     │
│ @joao_silva                    ✏️   │
│ (usado para compartilhamento)       │
└─────────────────────────────────────┘
```

---

## Fase 2: Sistema de Compartilhamento

### 2.1 Banco de Dados - Tabelas de Compartilhamento

#### Tabela: `shared_items`
**Abordagem Unificada** para todos os tipos de itens:

**Campos:**
- `id` UUID (PK)
- `item_type` ENUM ('goal', 'task', 'event', 'milestone')
- `item_id` UUID (referência ao item)
- `owner_id` UUID (dono do item)
- `shared_with_user_id` UUID (usuário que recebe acesso)
- `permission` ENUM ('view', 'edit', 'owner')
- `created_at`, `updated_at` TIMESTAMP

**Índices:**
- Por owner_id, shared_with_user_id, item

---

### 2.2 Backend - Serviço de Compartilhamento

#### Novo Arquivo: `lib/services/sharing_service.dart`

**Métodos Principais:**
```dart
class SharingService {
  Future<void> shareItem({
    required String itemType,
    required String itemId,
    required String username,
    String permission = 'view',
  });
  
  Future<void> unshareItem({...});
  Future<List<SharedUser>> getSharedUsers({...});
  Future<List<SharedItem>> getSharedWithMe(String userId);
  Future<void> updatePermission({...});
}
```

---

### 2.3 Frontend - UI de Compartilhamento

#### Componente: `ShareButton`
Botão "👥 Compartilhar" no header de Goal/Task Detail

#### Modal: `ShareModal`
```
┌────────────────────────────────────────┐
│  Compartilhar "Minha Meta"        ✕    │
├────────────────────────────────────────┤
│  Adicionar pessoa                      │
│  [🔍 @usuario]          [Adicionar]    │
│                                        │
│  👤 @maria_santos         🗑️           │
│     Pode editar            ▼           │
│                                        │
│  👤 @joao123              🗑️           │
│     Apenas visualizar      ▼           │
└────────────────────────────────────────┘
```

**Recursos:**
- Busca de usuários por username (autocomplete)
- Lista de colaboradores
- Dropdown de permissões
- Remover acesso

#### Indicadores Visuais
```
┌─────────────────────────────────────┐
│ 🎯 Aprender Flutter                 │
│ 👥 Compartilhado com 2              │ ← Badge
│ Progresso: 45%                      │
└─────────────────────────────────────┘
```

---

### 2.4 Notificações (N8N)

**Novos Eventos:**
- `goal_shared` - Meta compartilhada
- `task_shared` - Tarefa compartilhada
- `shared_item_updated` - Item atualizado

**Payload Exemplo:**
```json
{
  "event": "goal_shared",
  "data": {
    "itemType": "goal",
    "itemId": "uuid-123",
    "itemTitle": "Aprender Flutter",
    "sharedBy": {
      "username": "joao_silva",
      "email": "joao@example.com"
    },
    "sharedWith": {
      "username": "maria_santos"
    },
    "permission": "edit"
  }
}
```

---

## Fase 3: Recursos Avançados (Futuro)

### 3.1 Grupos de Compartilhamento
- Criar "times" ou "grupos"
- Compartilhar com grupo inteiro

### 3.2 Comentários e Atividades
- Sistema de comentários em itens
- Feed: "Maria completou a tarefa X"

### 3.3 Link de Convite
- `sincroapp.com.br/join/abc123`
- Acesso via link compartilhável

---

## Progresso de Implementação

### Sprint 1: Username Foundation ⏳
- [ ] SQL Migration (adicionar campo username)
- [ ] Atualizar `UserModel` e `SupabaseService`
- [ ] Criar `UsernameSetupScreen`
- [ ] Integrar no fluxo de registro
- [ ] Adicionar campo nas Settings

### Sprint 2: Backend de Compartilhamento 📅
- [ ] Criar tabela `shared_items`
- [ ] Implementar `SharingService`
- [ ] Testes de API

### Sprint 3: UI de Compartilhamento 📅
- [ ] Criar `ShareModal` componente
- [ ] Adicionar botão em Goal/Task Detail
- [ ] Busca de usuários
- [ ] Indicadores visuais

### Sprint 4: Integrações 📅
- [ ] Notificações N8N
- [ ] Filtros "Minhas" vs "Compartilhadas"
- [ ] Testes end-to-end

---

## Comandos SQL

> Ver arquivo `database_migrations.sql` para comandos completos

---

## Considerações de Segurança

- ✅ Username SEMPRE em lowercase
- ✅ Rate limiting (máx 10 buscas/min)
- ✅ Validar permissões antes de compartilhar
- ✅ Não expor emails em buscas
- ✅ Logs de auditoria

---

## Notas de Desenvolvimento

### Decisões de Design
1. **Username único** - Melhor UX que UIDs
2. **Tabela unificada** - `shared_items` para todos os tipos
3. **Permissões granulares** - view/edit/owner

### Próximas Decisões Necessárias
- [ ] Permitir mudança de username? (limite de 1x/ano?)
- [ ] Implementar "requisições de acesso" ou acesso direto?
- [ ] Privacidade: perfil público vs privado?

---

**Documentação mantida por:** Antigravity AI  
**Repositório:** c:\dev\sincro_app_flutter
