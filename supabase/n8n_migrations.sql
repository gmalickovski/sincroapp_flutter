-- ============================================
-- SINCRO APP - N8N ARCHITECTURE V6 MIGRATION
-- Data: 31/01/2026
-- Objetivo: Suporte a Memória de Longo Prazo e Roteamento Otimizado
-- ============================================

-- 1. Habilitar Extensão Vector (se ainda não existir)
-- Necessário para busca semântica de memórias no futuro
CREATE EXTENSION IF NOT EXISTS vector;

-- 2. Tabela de Memórias do Usuário (Long-Term Memory)
-- Armazena fatos, preferências e histórico relevante
CREATE TABLE IF NOT EXISTS sincroapp.user_memories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES sincroapp.users(uid) ON DELETE CASCADE,
    
    -- O conteúdo da memória (ex: "O usuário prefere reuniões de manhã")
    content TEXT NOT NULL,
    
    -- Categoria para roteamento fácil (user_fact, preference, medical, work)
    category VARCHAR(50) DEFAULT 'general',
    
    -- Embedding para busca semântica (OpenAI text-embedding-3-small usa 1536 dimensões)
    embedding vector(1536),
    
    -- Metadados extras (ex: origem da informação)
    metadata JSONB DEFAULT '{}',
    
    -- Controle temporal
    created_at TIMESTAMP DEFAULT NOW(),
    last_accessed_at TIMESTAMP DEFAULT NOW()
);

-- Índices para busca rápida pelo Router
CREATE INDEX IF NOT EXISTS idx_memories_user ON sincroapp.user_memories(user_id);
CREATE INDEX IF NOT EXISTS idx_memories_category ON sincroapp.user_memories(category);

-- Comentários
COMMENT ON TABLE sincroapp.user_memories IS 'Memória de longo prazo para o Agente IA (Fatos e Preferências)';

-- 3. Índices de Performance para o Workflow B (RAG)
-- Garante que "Quais minhas tarefas de hoje?" seja instantâneo

-- Tarefas: Busca por data (due_date) é a mais comum
CREATE INDEX IF NOT EXISTS idx_tasks_duedate_user 
ON sincroapp.tasks(user_id, due_date);

-- Metas: Busca por status ou data alvo
CREATE INDEX IF NOT EXISTS idx_goals_user_target 
ON sincroapp.goals(user_id, target_date);

-- 4. RLS (Row Level Security) para Memórias
ALTER TABLE sincroapp.user_memories ENABLE ROW LEVEL SECURITY;

-- Usuário pode ver suas próprias memórias
CREATE POLICY memories_select_policy ON sincroapp.user_memories
FOR SELECT USING (user_id = auth.uid());

-- Usuário (ou Agente em nome dele) pode inserir
CREATE POLICY memories_insert_policy ON sincroapp.user_memories
FOR INSERT WITH CHECK (user_id = auth.uid());

-- Usuário pode deletar/esquecer memórias
CREATE POLICY memories_delete_policy ON sincroapp.user_memories
FOR DELETE USING (user_id = auth.uid());
