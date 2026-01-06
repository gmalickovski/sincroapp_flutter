-- ============================================
-- SINCRO APP - DATABASE MIGRATIONS
-- Sistema de Compartilhamento Colaborativo
-- Data: 06/01/2026
-- Versão: 1.0
-- ============================================

-- ============================================
-- SPRINT 1: USERNAME FOUNDATION
-- ============================================

-- --------------------------------------------
-- 1. Adicionar campo username na tabela users
-- --------------------------------------------

ALTER TABLE sincroapp.users 
ADD COLUMN username VARCHAR(30);

-- Adicionar campo shared_with na tabela tasks (array de usernames)
ALTER TABLE sincroapp.tasks
ADD COLUMN shared_with TEXT[] DEFAULT '{}';

-- Criar índice para busca rápida de username
CREATE INDEX idx_users_username ON sincroapp.users(username);

-- Adicionar constraint de unicidade
ALTER TABLE sincroapp.users 
ADD CONSTRAINT username_unique UNIQUE (username);

-- Adicionar validação de formato (opcional, mas recomendado)
-- Formato: apenas letras minúsculas, números, underline (_) e ponto (.)
-- Comprimento: 3 a 30 caracteres
ALTER TABLE sincroapp.users 
ADD CONSTRAINT username_format CHECK (
  username IS NULL OR 
  username ~ '^[a-z0-9_.]{3,30}$'
);

-- Comentário descritivo
COMMENT ON COLUMN sincroapp.users.username IS 
'Username único do usuário, usado para compartilhamento. Formato: 3-30 caracteres, apenas [a-z0-9_.]';


-- --------------------------------------------
-- 2. Tabela de Histórico de Username (OPCIONAL)
-- --------------------------------------------
-- Útil para auditoria e rastreamento de mudanças

CREATE TABLE sincroapp.username_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES sincroapp.users(uid) ON DELETE CASCADE,
  old_username VARCHAR(30),
  new_username VARCHAR(30),
  changed_at TIMESTAMP DEFAULT NOW(),
  changed_reason TEXT
);

CREATE INDEX idx_username_history_user ON sincroapp.username_history(user_id);

COMMENT ON TABLE sincroapp.username_history IS 
'Histórico de alterações de username para auditoria';


-- --------------------------------------------
-- 2.1. Tabela de Contatos do Usuário (NOVO)
-- --------------------------------------------

CREATE TYPE sincroapp.contact_status AS ENUM ('active', 'blocked', 'pending');

CREATE TABLE sincroapp.user_contacts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES sincroapp.users(uid) ON DELETE CASCADE,
  contact_user_id UUID NOT NULL REFERENCES sincroapp.users(uid) ON DELETE CASCADE,
  status sincroapp.contact_status DEFAULT 'active',
  created_at TIMESTAMP DEFAULT NOW(),
  
  -- Evitar auto-adicionar
  CONSTRAINT no_self_contact CHECK (user_id != contact_user_id),
  -- Evitar duplicatas (par único)
  UNIQUE(user_id, contact_user_id)
);

CREATE INDEX idx_user_contacts_user ON sincroapp.user_contacts(user_id);
CREATE INDEX idx_user_contacts_contact ON sincroapp.user_contacts(contact_user_id);

COMMENT ON TABLE sincroapp.user_contacts IS 
'Lista de contatos do usuário para acesso rápido e bloqueios';

-- ============================================
-- SPRINT 2: SHARING SYSTEM BACKEND
-- ============================================

-- --------------------------------------------
-- 3. Criar ENUMs para Tipos e Permissões
-- --------------------------------------------

-- Tipo de item compartilhável
CREATE TYPE sincroapp.shared_item_type AS ENUM (
  'goal',
  'task', 
  'event',
  'milestone'
);

-- Nível de permissão
CREATE TYPE sincroapp.permission_level AS ENUM (
  'view',    -- Apenas visualizar
  'edit',    -- Pode editar
  'owner'    -- Dono (controle total)
);


-- --------------------------------------------
-- 4. Tabela Principal de Compartilhamento
-- --------------------------------------------

CREATE TABLE sincroapp.shared_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Tipo e ID do item compartilhado
  item_type sincroapp.shared_item_type NOT NULL,
  item_id UUID NOT NULL,
  
  -- Usuários envolvidos
  owner_id UUID NOT NULL REFERENCES sincroapp.users(uid) ON DELETE CASCADE,
  shared_with_user_id UUID NOT NULL REFERENCES sincroapp.users(uid) ON DELETE CASCADE,
  
  -- Permissão concedida
  permission sincroapp.permission_level DEFAULT 'view',
  
  -- Metadados
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  
  -- Evitar duplicatas: mesmo item não pode ser compartilhado 2x com a mesma pessoa
  UNIQUE(item_type, item_id, shared_with_user_id)
);

-- Comentários
COMMENT ON TABLE sincroapp.shared_items IS 
'Tabela unificada para compartilhamento de Goals, Tasks, Events e Milestones';

COMMENT ON COLUMN sincroapp.shared_items.item_type IS 
'Tipo do item: goal, task, event ou milestone';

COMMENT ON COLUMN sincroapp.shared_items.permission IS 
'Nível de acesso: view (visualizar), edit (editar), owner (dono)';


-- --------------------------------------------
-- 5. Índices de Performance
-- --------------------------------------------

-- Buscar itens compartilhados POR um usuário (owner)
CREATE INDEX idx_shared_items_owner 
ON sincroapp.shared_items(owner_id);

-- Buscar itens compartilhados COM um usuário (shared_with)
CREATE INDEX idx_shared_items_shared_with 
ON sincroapp.shared_items(shared_with_user_id);

-- Buscar compartilhamentos de um item específico
CREATE INDEX idx_shared_items_item 
ON sincroapp.shared_items(item_type, item_id);

-- Índice composto para consultas comuns
CREATE INDEX idx_shared_items_user_type 
ON sincroapp.shared_items(shared_with_user_id, item_type);


-- --------------------------------------------
-- 6. Trigger para atualizar updated_at
-- --------------------------------------------

CREATE OR REPLACE FUNCTION sincroapp.update_shared_items_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_shared_items_timestamp
BEFORE UPDATE ON sincroapp.shared_items
FOR EACH ROW
EXECUTE FUNCTION sincroapp.update_shared_items_timestamp();


-- ============================================
-- FUNÇÕES AUXILIARES (OPCIONAL)
-- ============================================

-- --------------------------------------------
-- 7. Função para verificar se username existe
-- --------------------------------------------

CREATE OR REPLACE FUNCTION sincroapp.username_exists(p_username VARCHAR)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM sincroapp.users 
    WHERE username = LOWER(p_username)
  );
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION sincroapp.username_exists IS 
'Verifica se um username já está em uso (case-insensitive)';


-- --------------------------------------------
-- 8. Função para buscar usuário por username
-- --------------------------------------------

CREATE OR REPLACE FUNCTION sincroapp.get_user_by_username(p_username VARCHAR)
RETURNS TABLE (
  uid UUID,
  email VARCHAR,
  username VARCHAR,
  full_name VARCHAR
) AS $$
BEGIN
  RETURN QUERY
  SELECT u.uid, u.email, u.username, u.full_name
  FROM sincroapp.users u
  WHERE u.username = LOWER(p_username);
END;
$$ LANGUAGE plpgsql;


-- ============================================
-- POLÍTICA DE SEGURANÇA (RLS - Row Level Security)
-- ============================================

-- Habilitar RLS na tabela shared_items
ALTER TABLE sincroapp.shared_items ENABLE ROW LEVEL SECURITY;

-- Política: Usuários podem ver itens que compartilharam OU que foram compartilhados com eles
CREATE POLICY shared_items_select_policy ON sincroapp.shared_items
FOR SELECT
USING (
  owner_id = auth.uid() OR 
  shared_with_user_id = auth.uid()
);

-- Política: Apenas o dono pode criar compartilhamentos
CREATE POLICY shared_items_insert_policy ON sincroapp.shared_items
FOR INSERT
WITH CHECK (owner_id = auth.uid());

-- Política: Apenas o dono pode deletar compartilhamentos
CREATE POLICY shared_items_delete_policy ON sincroapp.shared_items
FOR DELETE
USING (owner_id = auth.uid());

-- Política: Apenas o dono pode atualizar permissões
CREATE POLICY shared_items_update_policy ON sincroapp.shared_items
FOR UPDATE
USING (owner_id = auth.uid());


-- ============================================
-- DADOS DE TESTE (OPCIONAL - DESENVOLVIMENTO)
-- ============================================

-- Descomentar para popular com dados de exemplo
/*
-- Exemplo: Adicionar usernames para usuários existentes
UPDATE sincroapp.users 
SET username = 'joao_silva' 
WHERE email = 'joao@example.com';

UPDATE sincroapp.users 
SET username = 'maria_santos' 
WHERE email = 'maria@example.com';
*/


-- ============================================
-- VERIFICAÇÃO PÓS-MIGRAÇÃO
-- ============================================

-- Verificar criação do campo username
SELECT column_name, data_type, character_maximum_length
FROM information_schema.columns
WHERE table_schema = 'sincroapp' 
  AND table_name = 'users' 
  AND column_name = 'username';

-- Verificar índices
SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'sincroapp' 
  AND tablename = 'users'
  AND indexname = 'idx_users_username';

-- ============================================
-- SPRINT 3: NOTIFICATION SYSTEM
-- ============================================

-- --------------------------------------------
-- 5. Tipos de Notificação
-- --------------------------------------------

CREATE TYPE sincroapp.notification_type AS ENUM (
  'system',       -- Avisos do sistema
  'mention',      -- "Fulano mencionou você..."
  'share',        -- "Fulano compartilhou uma tarefa..."
  'sincro_alert', -- "Alerta de compatibilidade..."
  'reminder'      -- "Lembrete de tarefa..."
);

-- --------------------------------------------
-- 6. Tabela de Notificações
-- --------------------------------------------

CREATE TABLE sincroapp.notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES sincroapp.users(uid) ON DELETE CASCADE,
  
  type sincroapp.notification_type NOT NULL,
  title VARCHAR(100) NOT NULL,
  body TEXT NOT NULL,
  
  -- Para navegação ao clicar (ex: abrir tarefa específica)
  related_item_id UUID,
  related_item_type VARCHAR(50), -- 'task', 'goal', 'user'
  
  -- Status
  is_read BOOLEAN DEFAULT FALSE,
  read_at TIMESTAMP,
  
  -- Dados extras (ex: scores de numerologia)
  metadata JSONB DEFAULT '{}',
  
  created_at TIMESTAMP DEFAULT NOW()
);

-- Índices
CREATE INDEX idx_notifications_user ON sincroapp.notifications(user_id);
CREATE INDEX idx_notifications_unread ON sincroapp.notifications(user_id) WHERE is_read = FALSE;

-- RLS
ALTER TABLE sincroapp.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY notifications_select_policy ON sincroapp.notifications
FOR SELECT USING (user_id = auth.uid());

CREATE POLICY notifications_update_policy ON sincroapp.notifications
FOR UPDATE USING (user_id = auth.uid());

-- Permitir que qualquer usuário autenticado insira notificações (para envio entre usuários)
CREATE POLICY notifications_insert_policy ON sincroapp.notifications
FOR INSERT WITH CHECK (auth.role() = 'authenticated');


-- Permitir inserção pelo sistema (service role) ou triggers. 
-- Se usuários puderem "notificar" outros diretamente (ex: mention), precisarão de insert permission.
-- Por segurança, geralmente deixamos insert restrito ou validado via Function.
-- Aqui, para simplificar o MVP de mentions, vamos permitir insert autenticado.
CREATE POLICY notifications_insert_generic ON sincroapp.notifications
FOR INSERT WITH CHECK (true); -- Refinar futuramente

COMMENT ON TABLE sincroapp.notifications IS 
'Central de notificações do usuário. O campo metadata armazena detalhes de numerologia.';
  AND table_name = 'shared_items';

-- Verificar políticas RLS
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE schemaname = 'sincroapp'
  AND tablename = 'shared_items';


-- ============================================
-- ROLLBACK (SE NECESSÁRIO)
-- ============================================

-- CUIDADO! Os comandos abaixo REMOVEM todas as alterações
-- Descomente apenas se precisar reverter a migração

/*
-- Remover políticas RLS
DROP POLICY IF EXISTS shared_items_select_policy ON sincroapp.shared_items;
DROP POLICY IF EXISTS shared_items_insert_policy ON sincroapp.shared_items;
DROP POLICY IF EXISTS shared_items_delete_policy ON sincroapp.shared_items;
DROP POLICY IF EXISTS shared_items_update_policy ON sincroapp.shared_items;

-- Remover tabelas
DROP TABLE IF EXISTS sincroapp.shared_items CASCADE;
DROP TABLE IF EXISTS sincroapp.username_history CASCADE;

-- Remover ENUMs
DROP TYPE IF EXISTS sincroapp.permission_level CASCADE;
DROP TYPE IF EXISTS sincroapp.shared_item_type CASCADE;

-- Remover funções
DROP FUNCTION IF EXISTS sincroapp.username_exists CASCADE;
DROP FUNCTION IF EXISTS sincroapp.get_user_by_username CASCADE;
DROP FUNCTION IF EXISTS sincroapp.update_shared_items_timestamp CASCADE;

-- Remover campo username
ALTER TABLE sincroapp.users DROP COLUMN IF EXISTS username CASCADE;
*/


-- ============================================
-- FIM DA MIGRAÇÃO
-- ============================================
