# Sistema de Administração e Planos - SincroApp

## Visão Geral

Sistema completo de gerenciamento de usuários, planos de assinatura e painel administrativo implementado no SincroApp.

## 📋 Estrutura de Planos

### 1. **Sincro Essencial (Gratuito)**
- ✅ Acesso completo a Tarefas, Journal, Calendário
- ✅ Dashboard padrão (widgets fixos)
- ⚠️ **Limitações:**
  - Máximo de 5 metas ativas
  - 10 sugestões de IA (total, não renova)
  - Numerologia básica apenas

### 2. **Sincro Pro (Plus) - R$ 19,90/mês**
- ✅ Tudo do plano gratuito
- ✅ **Metas ilimitadas**
- ✅ **100 sugestões de IA por mês**
- ✅ Numerologia avançada (Bússola, análises detalhadas)
- ✅ Customização do Dashboard (reordenar, ocultar cards)
- ✅ Filtros avançados e tags

### 3. **Sincro Sinergia (Premium) - R$ 39,90/mês**
- ✅ Tudo do plano Plus
- ✅ **Sugestões de IA ilimitadas**
- ✅ Integrações (Google Calendar, Notion - futuro)
- ✅ Colaboração (futuro)
- ✅ Backup automático na nuvem
- ✅ Histórico de versões do Journal

## 🎯 Arquivos Criados

### Modelos
- `lib/models/subscription_model.dart` - Enum de planos, status, limites e lógica
- `lib/models/admin_stats_model.dart` - Modelo de estatísticas para dashboard admin

### Serviços
- `lib/services/firestore_service.dart` - Métodos admin adicionados:
  - `getAllUsers()` - Lista todos os usuários
  - `searchUsers(String)` - Busca por email/nome
  - `updateUserSubscription()` - Atualiza plano de usuário
  - `deleteUserData()` - Deleta usuário (GDPR compliance)
  - `getAdminStats()` - Estatísticas gerais
  - `getAdminStatsStream()` - Stream de estatísticas em tempo real

### Interface Admin
- `lib/features/admin/presentation/admin_screen.dart` - Tela principal com proteção de acesso
- `lib/features/admin/presentation/tabs/admin_dashboard_tab.dart` - Dashboard com estatísticas
- `lib/features/admin/presentation/tabs/admin_users_tab.dart` - Gerenciamento de usuários
- `lib/features/admin/presentation/widgets/user_edit_dialog.dart` - Edição de planos

### Atualizações em Arquivos Existentes
- `lib/models/user_model.dart` - Campo `subscription` adicionado + helpers
- `lib/common/widgets/dashboard_sidebar.dart` - Item "Admin" (apenas para admins)

## 🔐 Como Acessar o Painel Admin

1. **Marcar usuário como admin no Firestore:**
   ```
   users/{uid}/isAdmin = true
   ```

2. **Acessar pelo menu lateral:**
   - O item "Admin" aparece automaticamente acima de "Configurações"
   - Apenas visível para usuários com `isAdmin = true`

3. **Proteção de acesso:**
   - Mesmo se alguém tentar navegar diretamente, a tela verifica `isAdmin`
   - Usuários não-admin veem mensagem de "Acesso Restrito"

## 📊 Dashboard Admin - Recursos

### Tab "Dashboard"
- **Cards principais:**
  - Total de usuários
  - MRR (Monthly Recurring Revenue)
  - ARR (Annual Recurring Revenue)
  - Taxa de conversão (free → paid)

- **Distribuição por plano:**
  - Barra de progresso visual para cada plano
  - Porcentagens e contagens

- **Status de assinaturas:**
  - Assinaturas ativas
  - Assinaturas expiradas

- **Atualização em tempo real** via Stream

### Tab "Usuários"
- **Busca:**
  - Campo de texto para buscar por nome ou email
  - Busca instantânea (on-change)

- **Filtros:**
  - Todos / Gratuito / Plus / Premium
  - Chips clicáveis

- **Lista de usuários:**
  - Avatar, nome, email
  - Badge do plano (colorido por tipo)
  - Badge "EXPIRADA" para assinaturas vencidas
  - Badge "ADMIN" para administradores

- **Ações por usuário:**
  - ✏️ Editar (abre dialog)
  - 🗑️ Deletar (com confirmação)

- **Pull to refresh**

## ✏️ Edição de Usuário

Dialog completo com:
- **Dropdown de plano:**
  - Sincro Essencial / Sincro Pro / Sincro Sinergia
  
- **Dropdown de status:**
  - Ativa / Expirada / Cancelada / Teste (Trial)

- **Seletor de data:**
  - "Válido Até" (opcional)
  - Se não definido = permanente

- **Info box:**
  - Mostra limites do plano selecionado
  - Preço (se aplicável)

- **Persistência automática:**
  - Atualiza Firestore ao salvar
  - Recalcula limite de IA baseado no novo plano

## 🔒 Feature Gating - Como Usar

### No `UserModel`, agora há helpers:

```dart
// Verifica se pode usar IA
if (userData.canUseAI) {
  // Chama serviço de IA
}

// Verifica se pode criar meta
if (userData.canCreateGoal(currentGoalsCount)) {
  // Permite criar
} else {
  // Mostra paywall
}

// Outras verificações
userData.hasAdvancedNumerology // Bússola, relatórios
userData.canCustomizeDashboard // Reordenar cards
userData.hasIntegrations // Sincronizar com Google, etc.
userData.aiSuggestionsRemaining // Quantas sobraram
userData.planDisplayName // "Sincro Pro", etc.
```

### Exemplo de implementação:

```dart
void _showAISuggestions() {
  if (!widget.userData.canUseAI) {
    // Mostra paywall ou mensagem
    _showUpgradeDialog(
      title: 'Limite de IA atingido',
      message: 'Você usou suas ${userData.subscription.aiSuggestionsLimit} sugestões gratuitas. Faça upgrade para continuar!',
    );
    return;
  }
  
  // Continua com IA...
}
```

## 📱 Compliance Legal (GDPR)

### Deletar usuário:
- Método `deleteUserData(uid)` deleta:
  - Todas as tarefas
  - Todas as metas
  - Todas as entradas de journal
  - Todas as tags
  - O documento do usuário

- **Uso em lote** via WriteBatch para performance

### Dados pessoais:
- Nome, email, data de nascimento armazenados
- Foto de perfil (URL do Google/Firebase Auth)
- Possível adicionar campo "consentGDPR" e "dataProtectionConsent" se necessário

## 🎨 Personalização

### Preços dos planos:
Edite em `lib/models/subscription_model.dart`:
```dart
static double getPlanPrice(SubscriptionPlan plan) {
  switch (plan) {
    case SubscriptionPlan.plus:
      return 19.90; // Altere aqui
    case SubscriptionPlan.premium:
      return 39.90; // Altere aqui
  }
}
```

### Limites:
```dart
class PlanLimits {
  static const int freeMaxGoals = 5; // Altere aqui
  static const int freeAiSuggestions = 10; // Altere aqui
  static const int plusAiSuggestions = 100; // Altere aqui
}
```

## 🚀 Próximos Passos Sugeridos

1. **Integração de pagamento:**
   - Stripe, Mercado Pago ou similar
   - Webhook para atualizar `subscription` automaticamente

2. **Migração de usuários existentes:**
   - Script para adicionar campo `subscription` a todos os users
   - Todos começam no plano gratuito

3. **Notificações de expiração:**
   - Cloud Function que verifica `validUntil`
   - Envia email 7 dias antes de expirar

4. **Analytics:**
   - Integrar com Firebase Analytics
   - Eventos: "upgrade_to_plus", "ai_limit_reached", etc.

5. **Paywall screens:**
   - Criar telas de upgrade bonitas
   - Comparativo visual dos planos
   - Call-to-action forte

6. **Sistema de cupons:**
   - Campo `discountCode` em subscription
   - Validação de cupons

## 📝 Notas Importantes

- **Backward compatibility:** Usuários antigos sem campo `subscription` recebem automaticamente o plano gratuito
- **Campo `plano` deprecated:** Mantido por compatibilidade, mas use `userData.subscription.plan`
- **Reset mensal de IA:** Implementado em `SubscriptionModel.needsAiReset` - precisa ser chamado ao usar IA
- **Streams otimizados:** Use `getAdminStatsStream()` no dashboard admin para dados em tempo real

## 🐛 Troubleshooting

**Admin não aparece na sidebar:**
- Verifique `isAdmin = true` no Firestore
- Rebuild do app após mudança

**Erro ao carregar usuários:**
- Verifique índices do Firestore (busca por email/nome)
- Console do Firebase → Firestore → Indexes

**Subscription não salva:**
- Verifique se `toFirestore()` está sendo chamado
- Veja logs com `debugPrint` no FirestoreService

---

**Desenvolvido para o SincroApp** 🔮
Sistema de planos freemium com foco em numerologia e IA
