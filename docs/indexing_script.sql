-- Otimização de Índices para Streams Supabase
-- Execute estes comandos no seu Supabase SQL Editor para garantir performance imediata com os filtros .eq('user_id', uid)

-- Índice para a tabela Goals
CREATE INDEX IF NOT EXISTS idx_goals_user_id ON sincroapp.goals (user_id);

-- Índice para a tabela Tasks (Geral)
CREATE INDEX IF NOT EXISTS idx_tasks_user_id ON sincroapp.tasks (user_id);

-- Índice para associar Tarefas a Metas (Sub-querys rápidas)
CREATE INDEX IF NOT EXISTS idx_tasks_journey_id ON sincroapp.tasks (journey_id);

-- Índice para a tabela de Anotações (Journals)
CREATE INDEX IF NOT EXISTS idx_journal_entries_user_id ON sincroapp.journal_entries (user_id);

-- Índice para a tabela de Notificações
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON sincroapp.notifications (user_id);
