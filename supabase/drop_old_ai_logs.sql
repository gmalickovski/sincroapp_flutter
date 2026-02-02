-- Deletar a tabela antiga 'ai_usage_logs' para evitar confusão.
-- Remove tanto do schema 'sincroapp' quanto do 'public' se existir.

DROP TABLE IF EXISTS sincroapp.ai_usage_logs;
DROP TABLE IF EXISTS public.ai_usage_logs;

-- Confirmar limpeza
-- (Opcional) Se quiser remover também a 'usage_logs' antiga (caso exista duplicada errada), 
-- mas CUIDADO: a tabela correta agora é 'sincroapp.usage_logs'. 
-- NÃO execute drop na 'usage_logs' a menos que queira resetar tudo.
