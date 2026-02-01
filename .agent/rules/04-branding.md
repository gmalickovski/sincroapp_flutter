# SINCROAPP BRANDING & IDENTITY (v2.1)

Diretrizes Visuais para o Agente Antigravity: Estética Dark, Grid de 8pt e Numerologia.

## 1. CONCEITO VISUAL (MOODBOARD) 🔮

- **Estilo**: "Spiritual Tech" / "Mystical Modern".
- **Core Vibe**: Autoconhecimento profundo encontra produtividade prática.
- **Tema Padrão**: Dark Mode Nativo (**Obrigatório**). O app não possui modo claro.
- **Sensação**: Imersiva, misteriosa, porém limpa e organizada.

## 2. PALETA DE CORES (TOKENS) 🎨

Contraste WCAG AA obrigatório para textos.

### Base (Dark UI)
- **Background (Fundo Tela)**: `#111827` (Gray-900).
- **Surface (Cards/Modais)**: `#1F2937` (Gray-800) - Usar com `BorderRadius.circular(16)`.
- **Surface Light (Hover/Active)**: `#374151` (Gray-700).
- **Border/Divider**: `#4B5563` (Gray-600).

### Marca (Brand Colors)
- **Primary (Ação/Destaque)**: `#7C3AED` (Purple-600) - Contraste seguro sobre Surface e Background.
- **Secondary (Links/Suporte)**: `#A78BFA` (Purple-400).

### Tipografia (Texto)
- **Primary Text**: `#FFFFFF` (White) - Títulos.
- **Secondary Text**: `#D1D5DB` (Gray-300) - Corpo.
- **Tertiary Text**: `#9CA3AF` (Gray-400) - Hints/Labels.

### Semântica Funcional (Status)
- **Success**: `#10B981` (Green-500).
- **Error**: `Colors.redAccent`.
- **Task (Normal)**: `#3B82F6` (Blue-500).
- **Task (Meta/Jornada)**: `#EC4899` (Pink-500).
- **Journal (Diário)**: `#14B8A6` (Teal-500).

## 3. SISTEMA DE LAYOUT & GRID (8pt RULE) 📐

**Regra Suprema**: Todo espaçamento, padding e margem deve ser múltiplo de 8.

- **Paddings Internos (Cards)**: 16px (padrão) ou 24px (cards grandes).
- **Gap (Entre Elementos)**: 8px (relacionados), 16px (distintos), 32px (seções).
- **Margem Lateral (Tela)**: 16px (Mobile), 24px (Tablet), Max-width 1280px (Web).

## 4. SISTEMA NUMEROLÓGICO (VIBRATION SYSTEM) 🔢

As cores dos números (Pills) seguem um gradiente de energia específico:

| Vibração | Cor | Significado Visual |
| :--- | :--- | :--- |
| **1** | Vermelho | Ação, Início |
| **2** | Laranja | Parceria, Emoção |
| **3** | Amarelo | Criatividade, Luz |
| **4** | Verde | Terra, Estrutura |
| **5** | Azul Claro | Ar, Movimento |
| **6** | Índigo | Lar, Cuidado |
| **7** | Roxo | Mística, Introspecção |
| **8** | Rosa Escuro | Poder, Material |
| **9** | Dourado | Conclusão, Sabedoria |
| **11** | Lilás | Iluminação (Mestre) |
| **22** | Índigo Escuro | Construção (Mestre) |

## 5. TIPOGRAFIA (GOOGLE FONTS: INTER) ✍️

**Altura de Linha (Line-Height)**: 1.5 para textos longos, 1.2 para títulos.

- **Display Large (32px, Bold)**: Títulos de telas (Dashboard).
- **Display Medium (28px, Bold)**: Destaques numéricos.
- **Headline Medium (20px, SemiBold)**: Títulos de Cards.
- **Body Large (16px, Regular)**: Leitura confortável (Diário). **Nunca usar <16px em inputs**.
- **Body Medium (14px, Regular)**: Descrições secundárias.
- **Label Small (12px, Medium)**: Tags, Datas.

## 6. COMPONENTES & FORMAS (SHAPE LANGUAGE) 🧩

**Touch Target Mínimo**: 48x48dp para qualquer elemento interativo.

### Cards & Surfaces
**InfoCard / BussolaCard:**
- **Shape**: `BorderRadius.circular(16)`.
- **Background**: `#1F2937`.
- **Padding**: 16px (inset).
- **Elevation**: Sutil (`shadow-sm` na Web / `elevation: 1` no Flutter).

### Inputs (CustomTextField)
- **Shape**: `BorderRadius.circular(12)`.
- **Fill Color**: `#111827` (Darker background).
- **Height**: Mínimo 48px.
- **Text Size**: 16px (evita zoom no iOS).

### Botões (Primary/Secondary)
- **Shape**: `BorderRadius.circular(12)`.
- **Height**: Mínimo 48px (Mobile) / 56px (Large).
- **Color**: `#7C3AED` (Primary).

### Badges / VibrationPill
- **Shape**: `StadiumBorder` (totalmente arredondado) ou `BorderRadius.circular(8)`.
- **Height**: Mínimo 24px (não interativo) ou 32px (interativo).

## 7. ÍCONES E ILUSTRAÇÃO

- **Ícones**: Material Icons (outlined ou rounded).
- **Tamanho Visual**: 24px.
- **Tamanho de Toque**: Envolver em `IconButton` ou `Padding` para atingir 48px totais.
- **Cor Padrão**: `#D1D5DB` (Gray-300).
- **Cor Ativa**: `#7C3AED` (Primary Purple).

## 8. MATRIZ DE CONTRASTE & LEGIBILIDADE (ACESSIBILIDADE) 👁️

**Objetivo**: Evitar combinações de cores que cansam a vista ou tornam o texto ilegível.

### ✅ COMBINAÇÕES PERMITIDAS (SAFE LIST)

Use **APENAS** estas combinações para texto:

**Sobre Background (#111827) ou Surface (#1F2937):**
- **Título**: Primary Text (White).
- **Corpo**: Secondary Text (Gray-300).
- **Hint**: Tertiary Text (Gray-400).

**Sobre Primary Color (#7C3AED - Botões):**
- **Texto/Ícone**: **SEMPRE** White (#FFFFFF). Nunca usar cinza ou preto.

**Sobre Secondary Accent (#A78BFA - Tags/Pills):**
- **Texto**: Dark Gray (#111827). O branco não tem contraste suficiente aqui.

**Sobre Vibration Pills (Cores Coloridas):**
- **Se a cor for escura** (Vermelho, Índigo, Roxo): Use Texto White.
- **Se a cor for clara** (Amarelo, Azul Claro, Dourado): Use Texto Dark (#111827).

### ⛔ COMBINAÇÕES PROIBIDAS (DANGER ZONE)

O Agente deve recusar gerar código com estas combinações:

**"Gray on Gray" de baixo contraste:**
- Nunca usar Tertiary Text (Gray-400) sobre Surface (Gray-800) para textos longos. É ilegível.

**"Color on Color":**
- Nunca colocar texto Roxo sobre fundo Azul Escuro (vibração visual ruim).
- Nunca colocar texto Vermelho sobre fundo Verde (daltonismo).

**Texto Colorido Fino:**
- Evite usar Primary Color (#7C3AED) para textos finos (Thin/Light). Use apenas em Bold ou em ícones.

---

### Resumo para o Agente (Configuração):
- [ ] **Dark Mode Only**: Fundo `#111827`, Cards `#1F2937`.
- [ ] **Shapes**: Cards 16px, Inputs/Buttons 12px.
- [ ] **Grid 8pt**: Margens e paddings sempre múltiplos de 8 (16px default).
- [ ] **Touch**: Nada clicável menor que 48x48px.
- [ ] **Contraste**: Texto Branco em fundos escuros. Texto Preto em fundos claros (Amarelo/Ciano). Nunca cinza sobre cinza escuro.
