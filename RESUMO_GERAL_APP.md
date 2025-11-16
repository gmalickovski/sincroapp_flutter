# SincroApp - Resumo Geral do Aplicativo

---

## 📱 PARTE 1: OBJETIVO PRINCIPAL DO APP

### Para que ele serve?

O **SincroApp** é um **aplicativo de produtividade e autoconhecimento** que integra **Numerologia Cabalística** ao gerenciamento diário de tarefas, metas e reflexões pessoais. Ele combina ciência da vibração energética (números pessoais) com ferramentas práticas de organização para ajudar usuários a:

1. **Planejar o dia de forma estratégica** — com base no Dia Pessoal numerológico
2. **Criar e acompanhar metas (Jornadas)** — com marcos sugeridos por IA
3. **Refletir através do Diário de Bordo** — registrando insights e emoções
4. **Visualizar padrões de energia** — calendário integrado com vibrações diárias
5. **Receber orientações personalizadas** — via assistente IA treinado em numerologia

### Qual é o seu intuito?

Ajudar pessoas a **sincronizarem suas ações com suas energias pessoais**, maximizando produtividade e bem-estar através do autoconhecimento numerológico. O app busca transformar dados abstratos (números) em **insights práticos** que guiam decisões diárias.

### Qual dor ele resolve?

#### Dores principais que o SincroApp resolve:

**1. Falta de autoconhecimento profundo**
- Muitas pessoas não sabem quais são seus talentos naturais, desafios kármicos ou ciclos de vida.
- **Solução:** Mapa numerológico completo com 20+ métricas (Destino, Expressão, Missão, Ciclos de Vida, Débitos Kármicos, etc.)

**2. Desalinhamento entre planejamento e energia pessoal**
- Planejar tarefas sem considerar as vibrações do dia pode gerar frustração.
- **Solução:** Bússola de Atividades que sugere o que potencializar ou evitar em cada Dia Pessoal (1-9, 11, 22).

**3. Metas genéricas sem contexto numerológico**
- Objetivos criados sem levar em conta o momento de vida (Ciclo, Momento Decisivo).
- **Solução:** Sistema de Jornadas com sugestões de marcos contextualizadas pela IA numerológica.

**4. Dificuldade em manter consistência e reflexão**
- Falta de espaço para registrar insights diários e acompanhar padrões emocionais.
- **Solução:** Diário de Bordo integrado ao calendário, com vibração do dia e marcadores visuais.

**5. Ferramentas dispersas e sem personalização**
- Usuários precisam de múltiplos apps: to-do list, diário, calendário, relatórios de autoconhecimento.
- **Solução:** Tudo em um só lugar, com Dashboard customizável e integrado.

---

## 🎨 PARTE 2: INFORMAÇÕES DE DESIGN E LAYOUT

### Paleta de Cores

O design segue uma **estética dark moderna** com acentos em roxo/violeta, remetendo à espiritualidade e intuição.

#### Cores Principais (definidas em `lib/common/constants/app_colors.dart`):

| Cor | Código Hex | Uso Específico |
|-----|------------|----------------|
| **Background** | `#111827` (gray-900) | Fundo principal do app |
| **Card Background** | `#1F2937` (gray-800) | Fundo de cards, modais e elementos elevados |
| **Border** | `#4B5563` (gray-600) | Bordas de inputs, separadores, divisórias |
| **Primary Text** | `#FFFFFF` (white) | Texto principal, títulos |
| **Secondary Text** | `#D1D5DB` (gray-300) | Labels, subtítulos secundários |
| **Tertiary Text** | `#9CA3AF` (gray-400) | Textos auxiliares, hints |
| **Primary Accent** | `#7C3AED` (purple-600) | Botões primários, destaques principais |
| **Secondary Accent** | `#A78BFA` (purple-400) | Links, botões secundários |
| **Primary** | `#7C3AED` | Cor principal de branding (roxo vibrante) |

#### Cores de Marcadores do Calendário:

| Tipo | Cor | Código Hex |
|------|-----|------------|
| **Tarefas Normais** | Azul | `#3B82F6` (blue-500) |
| **Tarefas de Metas** | Rosa | `#EC4899` (pink-500) |
| **Entradas de Diário** | Teal/Turquesa | `#14B8A6` (teal-500) |

#### Cores das Pills de Vibração (Dia Pessoal 1-9, 11, 22):

As pills de vibração seguem um **degradê de energia**:
- **1** (Vermelho) → Ação, liderança
- **2** (Laranja) → Cooperação, diplomacia
- **3** (Amarelo) → Criatividade, comunicação
- **4** (Verde) → Estrutura, trabalho
- **5** (Azul claro) → Liberdade, aventura
- **6** (Índigo) → Família, responsabilidade
- **7** (Roxo) → Espiritualidade, análise
- **8** (Rosa escuro) → Poder, finanças
- **9** (Dourado) → Sabedoria, conclusão
- **11** (Lilás) → Número Mestre — Iluminação
- **22** (Índigo escuro) → Número Mestre — Construção

*(Implementado em `lib/common/widgets/vibration_pill.dart`)*

---

### Estilo de Fontes

O app utiliza **Google Fonts** para tipografia consistente e moderna.

#### Fontes principais:

- **Não especificado explicitamente no código**, mas pela estrutura, usa a fonte padrão do Flutter (`Roboto` no Android, `San Francisco` no iOS).
- **Pesos usados:**
  - `FontWeight.bold` — Títulos principais (Dashboard, telas)
  - `FontWeight.w600` — Subtítulos e labels importantes
  - `FontWeight.normal` — Texto corrido, descrições

#### Hierarquia de tamanhos:

| Elemento | Tamanho (px) | Peso | Uso |
|----------|--------------|------|-----|
| **Título de Tela** | 28-32 | Bold | Dashboard, GoalsScreen, JournalScreen |
| **Subtítulos de Card** | 18-20 | Bold | Títulos de InfoCard, BussolaCard |
| **Texto Principal** | 14-16 | Normal | Conteúdo de cards, descrições |
| **Labels** | 12-14 | Normal/Medium | Labels de input, badges |
| **Hints** | 12-13 | Normal | Placeholders, textos auxiliares |

---

### Estilo Geral do App

#### Características visuais:

1. **Dark Mode Nativo**
   - Todo o app é em modo escuro por padrão
   - Contraste alto para legibilidade (white text on dark backgrounds)

2. **Cards com Elevação Sutil**
   - Backgrounds em `#1F2937` (gray-800)
   - Bordas arredondadas (8-16px de `borderRadius`)
   - Sombras suaves para profundidade

3. **Espaçamento Generoso**
   - Padding de 16px em mobile
   - Padding de 40px em desktop/tablet
   - Margens consistentes entre elementos (8-16px)

4. **Layout Responsivo**
   - Breakpoint para desktop: **800px** (usado na maioria das telas)
   - Breakpoint para tablet: **768px** (usado no CalendarScreen)
   - Grid adaptativo com `flutter_staggered_grid_view` no Dashboard

5. **Componentes Reutilizáveis**
   - `InfoCard` — Card padrão com título, descrição curta e modal detalhado
   - `BussolaCard` — Card especial para sugestões de atividades
   - `CustomTextField` — Input padronizado com bordas e hints
   - `CustomButton` — Botão primário roxo
   - `VibrationPill` — Pill colorida com número do Dia Pessoal

6. **Animações e Transições**
   - `AnimationController` para expansão/colapso de elementos
   - `Hero` animations em navegação (não implementado extensivamente, mas preparado)
   - `ReorderableListView` para reorganizar cards do dashboard

7. **Ícones**
   - Material Icons padrão do Flutter
   - Usados de forma semântica (ex: `Icons.explore_outlined` para Destino, `Icons.favorite_border` para Motivação)

---

## ⚙️ PARTE 3: FUNCIONALIDADES

### Funcionalidades Principais (Core Features)

#### 1. **Dashboard Personalizável** ⭐ *Funcionalidade Mais Importante*
- **O que faz:** Tela inicial que exibe cards numerológicos, progresso de metas, tarefas do dia e bússola de atividades.
- **Diferenciais:**
  - **Reordenação drag-and-drop** de cards (planos pagos)
  - **Ocultação de cards** não relevantes (planos pagos)
  - **Grid masonry responsivo** (layout Pinterest-style)
  - **Atualização em tempo real** via Firestore Streams
- **Cards disponíveis:**
  - Progresso das Jornadas (Metas)
  - Foco do Dia (Tarefas)
  - Dia Pessoal / Mês Pessoal / Ano Pessoal (Vibrações)
  - Bússola de Atividades
  - Ciclo de Vida Atual
  - Número de Destino, Expressão, Motivação, Impressão, Missão
  - Talento Oculto, Número Psíquico, Aptidões Profissionais
  - Desafios, Momentos Decisivos
  - Lições Kármicas, Débitos Kármicos, Tendências Ocultas
  - Harmonia Conjugal, Dias Favoráveis
- **Planos:** Customização disponível apenas para **Sincro Desperta** e **Sincro Sinergia**.

---

#### 2. **Sistema de Metas (Jornadas)** ⭐ *Funcionalidade Mais Importante*
- **O que faz:** Permite criar, acompanhar e concluir metas de longo prazo com marcos intermediários.
- **Recursos:**
  - **Sugestões de marcos por IA** — O assistente sugere subtarefas alinhadas ao mapa numerológico do usuário (ex: "Se sua Expressão é 3, sugere marcos criativos")
  - **Progresso visual** com barra colorida
  - **Data-alvo** (opcional)
  - **Emoji** personalizado por meta
  - **Tags** personalizadas
  - **Integração com tarefas** — Tarefas podem ser vinculadas a uma Jornada específica
  - **Limite de metas:**
    - **Sincro Essencial:** Máximo 5 metas ativas
    - **Sincro Desperta/Sinergia:** Ilimitadas
- **IA:** Usa Vertex AI (via `firebase_ai`) para gerar sugestões contextualizadas.

---

#### 3. **Tarefas com Dia Pessoal**
- **O que faz:** Sistema de tarefas diárias com cálculo automático da vibração do dia.
- **Recursos:**
  - **Cálculo do Dia Pessoal** — Cada tarefa recebe automaticamente o número do dia (1-9, 11, 22)
  - **Pills coloridas** indicando a vibração
  - **Bússola de Atividades** sugerindo o que fazer/evitar naquele dia
  - **Recorrência** — Tarefas podem se repetir (diário, semanal, mensal, anual)
  - **Data de vencimento** com seletor de calendário
  - **Horário de lembrete** (notificações push)
  - **Tags** para organização
  - **Vinculação a Metas** — Tarefa pode fazer parte de uma Jornada
  - **Foco do Dia** — Tela dedicada para tarefas do dia atual

---

#### 4. **Diário de Bordo (Journal)**
- **O que faz:** Espaço para registros pessoais diários com contexto numerológico.
- **Recursos:**
  - **Editor de texto rico** (markdown-style)
  - **Vibração do dia** exibida em cada entrada
  - **Mood tracking** (humor em escala 1-5)
  - **Filtros:**
    - Por data
    - Por vibração específica
    - Por humor
  - **Histórico completo** organizado por mês
  - **Busca por conteúdo**
- **Uso:** Ideal para refletir sobre padrões emocionais em diferentes vibrações.

---

#### 5. **Calendário Integrado**
- **O que faz:** Visualização mensal de tarefas, metas e entradas de diário.
- **Recursos:**
  - **Marcadores coloridos:**
    - Azul: Tarefas normais
    - Rosa: Tarefas vinculadas a metas
    - Teal: Entradas de diário
  - **Dia Pessoal em cada célula** (número pequeno no canto)
  - **Modal detalhado** ao clicar em um dia, mostrando:
    - Tarefas do dia
    - Vibração completa (descrição)
    - Bússola de Atividades
  - **Navegação por mês/ano**
  - **Integração com Google Calendar** (planejado para planos premium)

---

#### 6. **Assistente IA (Sincro AI)** ⭐ *Funcionalidade Mais Importante*
- **O que faz:** Chatbot baseado em Vertex AI (Gemini 2.5 Flash Lite) especializado em numerologia cabalística.
- **Recursos:**
  - **Prompt contextualizado:**
    - Nome completo, data de nascimento
    - Todos os números do mapa (Destino, Expressão, Missão, Ciclo Atual, Desafios, etc.)
    - Tarefas ativas, metas, entradas de diário recentes
    - Próximos 30 dias de vibrações
  - **Ações executáveis:**
    - `create_task` — Cria tarefa no Firestore
    - `schedule` — Agenda compromisso
    - `set_goal` — Define meta
    - `journal_entry` — Gera entrada de diário
  - **Insights diários** (card especial no dashboard para plano Sinergia)
  - **Limites de uso:**
    - **Sincro Essencial:** Sem acesso
    - **Sincro Desperta:** 100 sugestões/mês
    - **Sincro Sinergia:** Ilimitado
- **Exemplo de uso:** "Sugira tarefas para hoje com base no meu Dia Pessoal 5" → IA retorna JSON com tarefas alinhadas à vibração de liberdade/aventura.

---

#### 7. **Mapa Numerológico Completo**
- **O que faz:** Calcula e exibe 20+ métricas numerológicas baseadas no nome completo e data de nascimento.
- **Métricas calculadas:**
  - **Números Principais:**
    - Destino (Caminho de Vida)
    - Expressão (Dons e Talentos)
    - Motivação (Desejo da Alma)
    - Impressão (Como o mundo te vê)
    - Missão de Vida
    - Talento Oculto
    - Número Psíquico (Dia de nascimento)
    - Dia Natalício (1-31 com descrições únicas)
  - **Aptidões Profissionais** (baseadas na Expressão)
  - **Ciclos de Vida:**
    - Ciclo 1 (Formação — 0 a ~idade)
    - Ciclo 2 (Produtividade — ~idade a ~idade)
    - Ciclo 3 (Colheita — ~idade até fim da vida)
  - **Momentos Decisivos (Pinnacles):**
    - P1, P2, P3, P4 com idades específicas
    - Momento Decisivo Atual
  - **Desafios:**
    - Desafio 1 (Primeira metade da vida)
    - Desafio 2 (Segunda metade da vida)
    - Desafio Principal (Vida toda)
  - **Listas Especiais:**
    - Lições Kármicas (números ausentes no nome)
    - Débitos Kármicos (14, 16, 19 na data de nascimento)
    - Tendências Ocultas (números repetidos no nome)
  - **Harmonia Conjugal:**
    - Compatibilidade com outros números de Missão
    - Categorias: Ideal, Favorável, Desafiador, Passivo
  - **Dias Favoráveis:**
    - Datas do mês que ressoam com seus números principais

- **Planos:**
  - **Sincro Essencial:** Apenas Dia/Mês/Ano Pessoal e Bússola
  - **Sincro Desperta/Sinergia:** Acesso completo a todos os números

---

#### 8. **Bússola de Atividades**
- **O que faz:** Sugere atividades para potencializar e evitar em cada Dia Pessoal (1-9, 11, 22).
- **Exemplo (Dia Pessoal 1):**
  - **Potencializar:**
    - Começar um novo projeto ou curso
    - Tomar a liderança em uma situação
  - **Atenção:**
    - Impaciência e impulsividade
    - Agir sem pensar nas consequências
- **Uso:** Exibida no Dashboard e no modal detalhado de cada vibração.

---

#### 9. **Sistema de Autenticação**
- **Recursos:**
  - **Login com Google** (OAuth 2.0)
  - **Email/senha** (Firebase Auth)
  - **Recuperação de senha**
  - **Cadastro com dados numerológicos:**
    - Nome completo para análise
    - Data de nascimento
    - Nome de apresentação
    - Email

---

#### 10. **Painel Administrativo** (apenas para admins)
- **O que faz:** Tela de gerenciamento interno para usuários marcados como `isAdmin = true`.
- **Recursos:**
  - **Dashboard com estatísticas:**
    - Total de usuários
    - MRR (Monthly Recurring Revenue)
    - ARR (Annual Recurring Revenue)
    - Taxa de conversão (free → paid)
    - Distribuição por plano
  - **Gerenciamento de usuários:**
    - Busca por email/nome
    - Filtros por plano
    - Edição de assinatura (plano, status, validade)
    - Exclusão de usuários (GDPR compliance)
  - **Atualização em tempo real** via Firestore Streams

---

### Funcionalidades Secundárias (Supporting Features)

- **Tags personalizadas** para tarefas e metas
- **Filtros avançados** (data, vibração, status, tags)
- **Notificações push:**
  - Vibração do dia (8h da manhã)
  - Lembrete de fim de dia (22h)
  - Lembretes de tarefas com horário
- **Sidebar responsiva** com navegação entre telas
- **Pull-to-refresh** em listas
- **Modo de edição** do dashboard (arrastar, ocultar cards)
- **Modais detalhados** para cada card numerológico (descrição completa, inspiração, tags)

---

## 💎 DIVISÃO DOS PLANOS (Sistema de Assinaturas)

O SincroApp segue um **modelo freemium** com 3 níveis de assinatura:

### **1. Sincro Essencial (Gratuito)**

**Preço:** R$ 0,00  
**Público-alvo:** Usuários iniciantes em numerologia e produtividade

**Funcionalidades incluídas:**
- ✅ Acesso completo a **Tarefas**
- ✅ Acesso completo ao **Diário de Bordo**
- ✅ Acesso completo ao **Calendário**
- ✅ Dashboard padrão (widgets fixos, sem customização)
- ✅ **Vibração do Dia/Mês/Ano** (apenas Dia/Mês/Ano Pessoal)
- ✅ **Bússola de Atividades**

**Limitações:**
- ⚠️ Máximo de **5 metas ativas**
- ⚠️ **Sem acesso ao mapa numerológico completo** (Destino, Expressão, Ciclos, etc.)
- ⚠️ **Sem assistente IA**
- ⚠️ **Sem customização do dashboard** (não pode reordenar ou ocultar cards)
- ⚠️ **Sem integração com Google Calendar**

---

### **2. Sincro Desperta (Plus) — R$ 19,90/mês**

**Preço:** R$ 19,90/mês  
**Público-alvo:** Usuários que querem aprofundar autoconhecimento e produtividade

**Funcionalidades incluídas:**
- ✅ Tudo do plano gratuito
- ✅ **Metas ilimitadas**
- ✅ **Mapa numerológico completo:**
  - Destino, Expressão, Motivação, Impressão, Missão
  - Talento Oculto, Número Psíquico, Aptidões Profissionais
  - Ciclos de Vida, Momentos Decisivos
  - Desafios, Lições Kármicas, Débitos Kármicos
  - Tendências Ocultas, Harmonia Conjugal, Dias Favoráveis
- ✅ **100 sugestões de IA por mês** (marcos de jornadas)
- ✅ **Customização do Dashboard** (reordenar e ocultar cards)
- ✅ **Filtros avançados** e tags

**Limitações:**
- ⚠️ IA limitada a 100 sugestões/mês
- ⚠️ Sem assistente IA completo (chat livre)
- ⚠️ Sem insights diários automáticos

---

### **3. Sincro Sinergia (Premium) — R$ 39,90/mês**

**Preço:** R$ 39,90/mês  
**Público-alvo:** Power users que querem a experiência completa

**Funcionalidades incluídas:**
- ✅ Tudo do plano Plus
- ✅ **Assistente IA ilimitado** (chat completo com Sincro AI)
- ✅ **Insights diários personalizados** (card automático no dashboard)
- ✅ **Integrações futuras:**
  - Google Calendar (em desenvolvimento)
  - Notion (planejado)
- ✅ **Colaboração** (futuro — compartilhar metas com família/amigos)
- ✅ **Backup automático na nuvem**
- ✅ **Histórico de versões do Journal** (futuro)

**Sem limitações.**

---

## 📊 Resumo Comparativo dos Planos

| Funcionalidade | Essencial (Free) | Desperta (Plus) | Sinergia (Premium) |
|----------------|------------------|-----------------|-------------------|
| **Tarefas, Diário, Calendário** | ✅ | ✅ | ✅ |
| **Metas Ativas** | Max 5 | ✅ Ilimitadas | ✅ Ilimitadas |
| **Mapa Numerológico Completo** | ❌ | ✅ | ✅ |
| **Customizar Dashboard** | ❌ | ✅ | ✅ |
| **Sugestões IA (marcos)** | ❌ | ✅ 100/mês | ✅ Ilimitado |
| **Assistente IA (chat)** | ❌ | ❌ | ✅ Ilimitado |
| **Insights Diários** | ❌ | ❌ | ✅ |
| **Integração Google Calendar** | ❌ | ❌ | ✅ (futuro) |
| **Backup/Histórico** | ❌ | ❌ | ✅ (futuro) |
| **Preço** | Grátis | R$ 19,90/mês | R$ 39,90/mês |

---

## 🎯 Funcionalidades Mais Importantes (Top 5)

### **1. Dashboard Personalizável**
- **Por quê:** É o coração do app — centraliza todas as informações e permite ao usuário criar sua própria jornada visual.
- **Impacto:** Diferencial competitivo; nenhum app de numerologia oferece isso.

### **2. Sistema de Metas (Jornadas) com IA**
- **Por quê:** Transforma numerologia em **ações práticas**; a IA sugere marcos baseados no mapa do usuário.
- **Impacto:** Conecta autoconhecimento com produtividade real.

### **3. Assistente IA (Sincro AI)**
- **Por quê:** É o "cérebro" do app — responde perguntas, gera insights e executa ações.
- **Impacto:** Principal motivo de upgrade para plano premium; experiência única no mercado.

### **4. Mapa Numerológico Completo**
- **Por quê:** Fornece **20+ métricas** que revelam padrões profundos de personalidade e destino.
- **Impacto:** Substitui consultas com numerólogos; tudo está acessível no bolso.

### **5. Bússola de Atividades Diária**
- **Por quê:** Guia prático para **maximizar cada Dia Pessoal**; usuário sabe exatamente o que fazer/evitar.
- **Impacto:** Uso diário garantido; cria hábito de consultar o app toda manhã.

---

## 🚀 Diferenciais Técnicos

- **Flutter** — Multiplataforma (iOS, Android, Web)
- **Firebase** — Backend completo (Auth, Firestore, Functions, App Check)
- **Vertex AI** — IA generativa com contexto numerológico profundo
- **Firestore Streams** — Atualização em tempo real sem refresh
- **Arquitetura escalável** — Separação por features (`/lib/features/`)
- **Componentes reutilizáveis** — Design system consistente

---

**Desenvolvido para transformar números em sabedoria prática.** ✨🔮
