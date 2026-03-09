-- ATUALIZAÇÃO RECORRÊNCIAS (08/03/2026)
-- Adiciona a distinção entre Compromisso (Agenda) e Fluxo (Trilha)
-- E adiciona a Data de Início (start_date) para os Fluxos.

-- 1. Criação da Categoria de Recorrência (Fixar na Agenda vs Fluir na Trilha)
ALTER TABLE sincroapp.tasks 
ADD COLUMN IF NOT EXISTS recurrence_category TEXT DEFAULT 'commitment';

-- 2. Adiciona restrição para aceitar apenas os valores corretos
ALTER TABLE sincroapp.tasks
DROP CONSTRAINT IF EXISTS check_recurrence_category; -- Remove caso já exista para evitar erros

ALTER TABLE sincroapp.tasks
ADD CONSTRAINT check_recurrence_category 
CHECK (recurrence_category IN ('commitment', 'flow', 'flow_instance'));

-- 3. Adiciona a coluna start_date para controlar o início dos Rituais (Flows)
ALTER TABLE sincroapp.tasks 
ADD COLUMN IF NOT EXISTS start_date TIMESTAMPTZ;

-- NOTA PARA O INÍCIO:
-- Para as tarefas "Flow", a exibição baseia-se na 'start_date'.
-- Se 'start_date' for nulo, o sistema no Flutter usará o 'created_at' como fallback provisório,
-- garantindo que nenhuma tarefa quebre.
