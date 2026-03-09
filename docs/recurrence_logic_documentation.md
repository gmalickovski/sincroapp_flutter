# SincroApp - Nova Lógica de Recorrência (Caminhos e Ciclos)

Este documento detalha o funcionamento atualizado do sistema de tarefas recorrentes no SincroApp. O objetivo central desta mudança foi alinhar o comportamento lógico das repetições com a filosofia do aplicativo de respeitar o "Ritmo" e a "Sincronia" do usuário, removendo a pressão de atrasos irreais e otimizando o uso do banco de dados.

---

## 1. O Problema Anterior

Antes, toda vez que você criava uma tarefa recorrente (ex: "Fazer Exercícios" todo dia), o backend (ou o Flutter) interpretava isso apenas de uma forma: como uma tarefa comum que se repete.
O problema dessa abordagem era:
*   Se você passasse 3 dias sem abrir o app ou esquecesse de focar naquela tarefa, elas acumulavam na sua agenda como **"Atrasadas"**.
*   Para um compromisso real (ex: Pagar o Aluguel), isso faz sentido. Mas para hábitos e ciclos naturais de energia (um "Ritual"), isso gera frustração. Rituais pertencem àquele dia; se não foram feitos hoje, a vida segue, amanhã é um novo ciclo.
*   Além disso, repetições infinitas poderiam poluir o banco de dados do Supabase preenchendo o banco com instâncias futuras que talvez você nunca venha a completar.

---

## 2. A Nova Abordagem: Dualidade de Recorrência

Para solucionar isso, o sistema agora divide as recorrências em duas categorias fundamentais (`recurrence_category`). Quando você cria uma tarefa que se repete, você obrigatoriamente escolhe a sua *Natureza*:

### A. Fixar na Agenda (Commitment / Agendamento)
*   **Aparência na UI:** O botão tem o ícone de um calendário (`Icons.event_available`).
*   **Como funciona:** Exatamente como o modelo tradicional. Se você programa para toda Segunda-Feira e não clica em concluir, ela ficará vermelha com o selo de "Atrasada". 
*   **Onde é exibida:** Aparece em todas as visualizações (Agenda, Trilha, Filtros) rigidamente atrelada ao relógio linear.
*   **Banco de Dados:** Cada ocorrência é uma **própria entidade materializada** e gera expectativa temporal. *(No futuro, os Cron Jobs/Trigger functions farão o provisionamento de novas instâncias fixas)*

### B. Fluir na Trilha (Flow / Ritual)
*   **Aparência na UI:** O botão tem o ícone de sincronia (`Icons.sync`).
*   **Como funciona:** Funciona como um **Ciclo Dinâmico** (ou "Template"). Se uma tarefa está desenhada para acontecer toda Terça-Feira, ela **não gera instâncias futuras no banco de dados**. 
*   Em vez disso, ela existe apenas como um "molde". Quando você abre a tela "Foco do Dia" ou "Trilha de Ação", o próprio aplicativo (no celular) olha para esse molde e diz: *"Hoje é Terça, vou exibir esse Ritual"*.
*   **Zero Atrasos:** Se a terça-feira terminar e você não a concluiu, o app não te pune. No dia seguinte, ela simplesmente não aparece na tela (pois não é terça). Ela nunca fica com o status de "Atrasada".

---

## 3. Funcionamento Técnico (Como Magia Acontece na Tela)

A mágica está dentro do arquivo `foco_do_dia_screen.dart`, especificamente no método `_filterTasks` e na função `_doesRecurrenceMatch`.

1.  **A Base (Início do Flow):** Diferente dos compromissos fixos que salvam um `dueDate` (Data de Vencimento), os rituais ("Fluir na Trilha") salvam apenas uma `startDate` (Data de Início) e a regra de recorrência, deixando o `dueDate` nulo. Eles funcionam como uma planta arquitetônica, um projeto, não uma casa construída.
2.  **Avaliação Preditiva:** Ao abrir o app, o Flutter pega a data que o usuário está olhando (ex: "Hoje"). Para cada tarefa do tipo `flow`, ele cruza a `startDate` com a regra de frequência (ex: diário, semanal) usando a fórmula `_doesRecurrenceMatch`.
3.  **Projeção Holográfica:** Se a data atual for compatível com a regra (ex: o resto da divisão dos dias passados pelo intervalo é zero), o Flutter **cria uma Cópia Virtual (na memória RAM temporária)** daquela tarefa para o dia de hoje.
4.  **Ação de Conclusão (O 'OnToggle'):** 
    *   Sempre que você olhar aquela tarefa virtual e der um check nela (Concluir), o aplicativo não conclui o "Molde" matriz.
    *   Em vez disso, ele cria uma Gêmea Verdadeira. Ele manda o Supabase guardar de graça uma **nova tarefa real** marcada como `flow_instance`, com a data de conclusão preenchida. Ele atrela o ID dessa instância filha ao "Molde Pai". Esta instância serve como **Histórico Permanente** da sua conquista (você ganha as moedas/exp, ela conta pro Journal, fica verde para sempre no passado).
    *   **Desfazer o Check:** Se você se arrepender e desmarcar o checkbox, em vez de voltar ela para pendente (pois isso sujaria o banco), o app simplesmente deleta essa *instância filha* do banco, e você volta a ver apenas o *Molde Holográfico* piscando.
5.  **Hibernação (Limpeza Automática):** Se o dia acabar e você não tiver concluído a instância projetada, à meia-noite ela sofre "hibernação". O aplicativo filtra ativamente para que `flow_instance` (ou o molde base `flow`) não apareça na lista de tarefas "Atrasadas". O dia de ontem passou, o fluxo não foi seguido, mas o Rio (Flow) continuará correndo amanhã.

---

## 4. O Banco de Dados (Resumo)

Foi adicionada a coluna `recurrence_category` à tabela `tasks`.

**Valores possíveis da `recurrence_category`:**
1.  **`commitment`** (Padão antigo) - Tarefa recorrente obrigatória que atrasa.
2.  **`flow`** - A tarefa "Molde / Matriz". Ela guarda as coordenadas (frequencia, tipo), mas ela em si **nunca é listada sozinha como uma tarefa para se fazer**.
3.  **`flow_instance`** - O histórico. É a gravação em pedra de que no dia X, você completou o ritual do Molde Y. Ela não se repete.

---

## 5. Próximos Passos & Notas de Refinamento

Atualmente a lógica está toda contida de forma eficiente na visualização do cliente (no Flutter). 
Isso traz imensas vantagens de economia de chamadas pro Servidor, entretanto:

*   Se houver **Notificações Push Reais** atreladas à hora exata de um Ritual (ex: Tocar alarme às 20h para "Meditar"), como a tarefa é virtual, precisamos garantir que o sistema de alarmes do seu Edge Function/Cron saiba ler o "Molde" `flow` para disparar os pushes simuladamente sem precisar criar tickets no banco de dados. *(Isto fica para uma próxima iteração backend caso pushes de tempo crítico em tarefas Flow sejam um requisito de vida ou morte).*
