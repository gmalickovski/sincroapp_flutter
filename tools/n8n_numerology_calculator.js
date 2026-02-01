/**
 * Sincro AI - N8n Numerology Passthrough
 * 
 * Este script REPASSA os dados numerológicos já calculados pelo Flutter.
 * NÃO recalcula nada - apenas organiza os dados para o AI Agent.
 */

// === MAIN LOGIC ===
const webhook = $('Webhook (SincroApp)').item.json;
const context = webhook.body?.context || {};
const userContext = context.user || {};
const numerologyContext = context.numerology || {};

// Dados que já vêm calculados do Flutter
const numeros = numerologyContext.numeros || {};
const listas = numerologyContext.listas || {};
const estruturas = numerologyContext.estruturas || {};

// Keywords por número para contexto extra
const VIBES = {
    1: ["Início", "Liderança", "Ação"],
    2: ["Parceria", "Paciência", "Diplomacia"],
    3: ["Comunicação", "Criatividade", "Social"],
    4: ["Trabalho", "Organização", "Segurança"],
    5: ["Mudança", "Viagem", "Liberdade"],
    6: ["Família", "Responsabilidade", "Harmonia"],
    7: ["Introspecção", "Estudo", "Espiritualidade"],
    8: ["Poder", "Dinheiro", "Negócios"],
    9: ["Conclusão", "Humanitarismo", "Ajuda"],
    11: ["Inspiração", "Intuição Elevada"],
    22: ["Construção", "Grande Escala"]
};

const diaPessoal = numeros.diaPessoal || estruturas.diaPessoal || 1;
const keywordsDia = VIBES[diaPessoal] || ["Neutro"];

// === RETORNO ORGANIZADO PARA O AI AGENT ===
return {
    question: webhook.body?.question || "",

    user: {
        nome: userContext.primeiroNome?.split(' ')[0] || "Usuário",
        nomeCompleto: userContext.primeiroNome || "",
        genero: userContext.gender || null,
        dataNascimento: userContext.dataNasc || null
    },

    numerologia: {
        // Todos os números principais (vindos do Flutter)
        ...numeros,

        // Keywords do dia para contexto
        keywordsDia: keywordsDia,

        // Listas cármicas (vindas do Flutter)
        licoesCarmicas: listas.licoesCarmicas || [],
        debitosCarmicos: listas.debitosCarmicos || [],
        tendenciasOcultas: listas.tendenciasOcultas || [],
        diasFavoraveis: listas.diasFavoraveis || []
    },

    analysis: {
        date: context.currentDate?.split('T')[0] || new Date().toISOString().split('T')[0],
        personalDay: diaPessoal,
        yearPersonal: numeros.anoPessoal || estruturas.anoPessoal,
        monthPersonal: numeros.mesPessoal,
        keywords: keywordsDia
    }
};
