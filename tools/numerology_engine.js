
// === HELPER FUNCTIONS ===
function reduceNumber(n, mestre = false) {
    while (n > 9) {
        if (mestre && (n === 11 || n === 22)) return n;
        n = n.toString().split('').reduce((a, b) => parseInt(a) + parseInt(b), 0);
    }
    return n;
}

function parseDate(dateStr) {
    if (!dateStr) return null;
    if (dateStr.includes('-')) {
        const parts = dateStr.split('-');
        if (parts.length === 3) return new Date(parts[0], parts[1] - 1, parts[2]);
    }
    if (dateStr.includes('/')) {
        const parts = dateStr.split('/');
        if (parts.length === 3) return new Date(parts[2], parts[1] - 1, parts[0]);
    }
    return null;
}

function calculatePersonalDay(targetDate, birthDate) {
    const bioMonth = birthDate.getMonth() + 1;
    const bioDay = birthDate.getDate();
    const targetYear = targetDate.getFullYear();
    const targetMonth = targetDate.getMonth() + 1;
    const targetDay = targetDate.getDate();

    let calcYear = targetYear;
    if (targetMonth < bioMonth || (targetMonth === bioMonth && targetDay < bioDay)) {
        calcYear = targetYear - 1;
    }
    const anoPessoal = reduceNumber(bioDay + bioMonth + calcYear, false);
    const mesPessoal = reduceNumber(anoPessoal + targetMonth, false);
    const diaReduzido = reduceNumber(targetDay, true);
    return reduceNumber(mesPessoal + diaReduzido, true);
}

// === HARMONIZATION MATRIX ===
const MATRIX = {
    1: { fav: [3, 5, 9], unfav: [6], neutral: [1, 2, 4, 7, 8] },
    2: { fav: [2, 4, 6, 7], unfav: [5, 9], neutral: [1, 3, 8] },
    3: { fav: [1, 3, 5, 6], unfav: [4, 7, 8], neutral: [2, 9] },
    4: { fav: [2, 6, 8], unfav: [3, 5, 7, 9], neutral: [1, 4] },
    5: { fav: [1, 3, 5, 7, 9], unfav: [2, 4, 6, 8], neutral: [] },
    6: { fav: [2, 3, 4, 8, 9], unfav: [1, 5, 7], neutral: [6] },
    7: { fav: [2, 5, 7], unfav: [3, 4, 6, 8, 9], neutral: [1] },
    8: { fav: [4, 6], unfav: [3, 5, 7, 8, 9], neutral: [1, 2] },
    9: { fav: [1, 5, 6, 9], unfav: [2, 4, 7, 8], neutral: [3] },
    11: { fav: [1, 3, 5, 7, 9, 11], unfav: [2, 4, 6, 8], neutral: [22] },
    22: { fav: [1, 2, 3, 4, 5, 6, 7, 8, 9, 22], unfav: [], neutral: [11] }
};

const VIBE_KEYWORDS = {
    1: ["Início", "Liderança"], 2: ["Parceria", "Paciência"], 3: ["Criatividade", "Comunicação"],
    4: ["Trabalho", "Ordem"], 5: ["Mudança", "Vendas"], 6: ["Família", "Harmonia"],
    7: ["Análise", "Estudo"], 8: ["Poder", "Finanças"], 9: ["Conclusão", "Altruísmo"],
    11: ["Inspiração", "Mestre"], 22: ["Construção", "Grandeza"]
};

// === INPUTS ===
const input = items[0].json;
const params = input.params || input;
const title = params.title || params.intent || 'Tarefa';

const context = $('Webhook (SincroApp)').item.json.body.context || {};
const contextNumerology = context.numerology || {};
const contextUser = context.user || {};

const birthDateStr = contextUser.dataNasc || "2000-01-01";
const birthDate = parseDate(birthDateStr) || new Date(2000, 0, 1);

// Get Destiny Number
let destinyNum = 1;
if (contextNumerology.numeros && contextNumerology.numeros.destino) {
    destinyNum = contextNumerology.numeros.destino;
}

// Target Date Logic (SUPORTA NULL)
let targetDateStr = params.target_date;
let isSuggestionMode = false;
let targetDate = null;

if (!targetDateStr || targetDateStr === 'null') {
    isSuggestionMode = true;
    targetDateStr = null;
} else {
    targetDate = new Date(targetDateStr);
}

// === SCORING ===
function evaluateDate(date, bDate, dNum) {
    const pDay = calculatePersonalDay(date, bDate);
    const rules = MATRIX[dNum] || MATRIX[1];
    let status = "Neutro";
    let score = 50;

    if (rules.fav.includes(pDay)) { status = "Favorável"; score = 100; }
    else if (rules.unfav.includes(pDay)) { status = "Desafiador"; score = 0; }

    return { date, personalDay: pDay, status, score, vibe: VIBE_KEYWORDS[pDay] || [] };
}

let mainAnalysis = {};
if (!isSuggestionMode && targetDate) {
    mainAnalysis = evaluateDate(targetDate, birthDate, destinyNum);
    mainAnalysis.is_favorable = mainAnalysis.score >= 50;
}

// Find Suggestions
let suggestions = [];
// CORREÇÃO: Começa a busca a partir da data alvo (se houver) ou de hoje
let scanDate = targetDate ? new Date(targetDate) : new Date();
scanDate.setDate(scanDate.getDate() + 1); // +1 dia
let attempts = 0;
while (suggestions.length < 3 && attempts < 15) {
    const ev = evaluateDate(scanDate, birthDate, destinyNum);
    if (ev.score === 100) {
        suggestions.push({ date: ev.date.toISOString(), personalDay: ev.personalDay, vibe: ev.vibe, status: ev.status });
    }
    scanDate.setDate(scanDate.getDate() + 1);
    attempts++;
}

return {
    title: title,
    date: isSuggestionMode ? null : targetDateStr,
    analysis: isSuggestionMode ? { is_favorable: false, keywords: [], personalDay: 0 } : {
        personalDay: mainAnalysis.personalDay,
        keywords: mainAnalysis.vibe,
        is_favorable: mainAnalysis.is_favorable,
        status: mainAnalysis.status
    },
    suggestedDates: suggestions
};
