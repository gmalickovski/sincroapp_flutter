# SINCROAPP DESIGN SYSTEM RULES (v1.0)

Diretrizes de UI/UX para o Agente Antigravity: Consistência, Acessibilidade e Grid de 8pt.

## 1. A REGRA DE OURO: GRID DE 8 PONTOS (SPACING) 📐

**Contexto**: Todo espaçamento, margem, padding e tamanho de elemento deve ser múltiplo de 8 (ou 4 para detalhes finos).
**Por que?** Evita decisões arbitrárias ("números mágicos") e garante alinhamento visual perfeito em todas as telas.

**Escala de Espaçamento (Tailwind / Flutter):**

- **4px (0.25rem / xs)**: Detalhes internos, proximidade extrema.
- **8px (0.5rem / sm)**: Padding padrão de ícones, separação de texto/ícone.
- **16px (1rem / md)**: **PADRÃO**. Margem lateral de containers mobile, padding de botões.
- **24px (1.5rem / lg)**: Separação entre grupos de elementos.
- **32px (2rem / xl)**: Separação entre seções principais.
- **48px+ (3rem / 2xl)**: Espaço para "respiro" em landing pages.

## 2. TIPOGRAFIA & HIERARQUIA ✍️

**Base**: Fonte Sans-Serif (Legibilidade).
**Line-Height**: 1.5 (150%) para corpo de texto, 1.2 (120%) para títulos.

### Escala Tipográfica (Mobile & Web)

**H1 (Título Principal / Hero):**
- **Web**: `text-4xl` a `text-5xl` (36px - 48px). Bold.
- **Flutter**: `headlineLarge` (32px).

**H2 (Seções):**
- **Web**: `text-2xl` a `text-3xl` (24px - 30px). Semi-Bold.
- **Flutter**: `headlineMedium` (24px).

**H3 (Cards / Subseções):**
- **Web**: `text-xl` (20px). Medium.
- **Flutter**: `titleLarge` (20px).

**Body (Texto Corrido):**
- **Web**: `text-base` (16px). Regular. Nunca menor que 16px em inputs para evitar zoom automático no iOS.
- **Flutter**: `bodyLarge` (16px).

**Caption / Labels:**
- **Web**: `text-sm` (14px) ou `text-xs` (12px).
- **Flutter**: `bodySmall` (12px). Use apenas para metadados (datas, legendas).

### Formatação de Texto
- **Parágrafos**: Máximo de 60-70 caracteres por linha para leitura confortável (Web).
- **Listas (Bullets)**: Indentação alinhada visualmente com o texto acima, não com a margem.

## 3. COMPONENTES & INTERAÇÃO (TOUCH TARGETS) 👆

**Mobile First**: Dedos são imprecisos.

### Área de Toque Mínima:
- **Regra Absoluta**: Todo elemento clicável deve ter uma área de toque de, no mínimo, **44x44px (iOS)** ou **48x48dp (Android)**.
- **Dica**: Se o ícone for pequeno (24px), adicione padding transparente para atingir 48px.

### Botões (Buttons):
- **Altura**: Mínimo 48px (Medium) ou 56px (Large).
- **Padding Interno**: Horizontal deve ser maior que vertical (ex: `px-6 py-3`).
- **Hierarquia**:
  - **Primary**: Cor sólida, destaque total (apenas 1 por tela).
  - **Secondary**: Outline (borda) ou tom suave.
  - **Ghost/Text**: Apenas texto, sem fundo (para ações terciárias como "Cancelar").

## 4. LAYOUT & RESPONSIVIDADE 📱💻

**Mobile First**: Projete para a tela pequena, expanda para a grande.

### Flutter (App):
- Evite `hardcoded width`. Use `Flex`, `Expanded`, ou `MediaQuery` para larguras relativas.
- **Safe Area**: Sempre envolva a tela principal em um `SafeArea` para não colidir com o notch/dynamic island.

### Web (Tailwind):
- **Container padrão**: `w-full max-w-7xl mx-auto px-4` (centralizado com respiro lateral).
- **Grid System**:
  - **Mobile**: 1 coluna (`grid-cols-1`).
  - **Tablet**: 2 colunas (`md:grid-cols-2`).
  - **Desktop**: 3 ou 4 colunas (`lg:grid-cols-4`).

## 5. CORES & ACESSIBILIDADE 🎨

- **Contraste (WCAG AA)**: Texto normal deve ter contraste mínimo de 4.5:1 contra o fundo.
- **Estados**:
  - Todo elemento interativo deve ter estados visíveis: Normal, Hover (Web), Pressed/Active, Disabled.
  - **Disabled**: Não use apenas opacidade. Use cinza neutro e bloqueie o cursor (`cursor-not-allowed`).

## 6. SOMBRAS E PROFUNDIDADE (ELEVATION)

- Não use bordas pretas para separar elementos. Use sombras suaves (`shadow-sm`, `shadow-md`) ou cores de fundo levemente diferentes (`bg-gray-50` vs `bg-white`).
- **Flutter**: Use a propriedade `elevation` do Material com parcimônia.

### Checklist Rápido para o Agente:
- [ ] O botão tem pelo menos 48px de altura?
- [ ] O texto principal tem pelo menos 16px?
- [ ] O espaçamento segue a régua de 8pt (8, 16, 24, 32)?
- [ ] Existe feedback visual ao clicar/tocar?
