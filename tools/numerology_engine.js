
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
    const cleanStr = dateStr.split('T')[0];
    if (cleanStr.includes('-')) {
        const parts = cleanStr.split('-');
        if (parts.length === 3) return new Date(parts[0], parts[1] - 1, parts[2]);
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

// === FAVORABLE DAYS LOGIC ===

// Table Reference: Day/Month -> Base Numbers [B1, B2]
const BASE_DAYS_TABLE = {
    1: { 1: [1, 5], 2: [1, 6], 3: [3, 6], 4: [1, 5], 5: [5, 6], 6: [5, 6], 7: [1, 7], 8: [1, 3], 9: [6, 9], 10: [1, 5], 11: [1, 6], 12: [6, 9], 13: [1, 5], 14: [5, 6], 15: [5, 6], 16: [1, 5], 17: [1, 3], 18: [5, 6], 19: [1, 5], 20: [1, 6], 21: [3, 6], 22: [1, 5], 23: [5, 6], 24: [5, 6], 25: [1, 5], 26: [2, 3], 27: [6, 9], 28: [2, 7], 29: [5, 7], 30: [2, 3], 31: [2, 7] },
    2: { 1: [1, 5], 2: [2, 7], 3: [3, 6], 4: [2, 7], 5: [5, 6], 6: [3, 6], 7: [2, 7], 8: [2, 3], 9: [3, 6], 10: [2, 7], 11: [5, 7], 12: [5, 6], 13: [2, 7], 14: [5, 6], 15: [3, 6], 16: [2, 5], 17: [2, 3], 18: [3, 6], 19: [2, 7], 20: [2, 7], 21: [3, 6], 22: [2, 7], 23: [5, 6], 24: [5, 6], 25: [2, 7], 26: [2, 3], 27: [6, 9], 28: [2, 7], 29: [6, 7], 30: [3, 9], 31: [1, 7] },
    3: { 1: [1, 7], 2: [2, 7], 3: [3, 6], 4: [1, 7], 5: [5, 7], 6: [3, 6], 7: [2, 7], 8: [3, 6], 9: [6, 9], 10: [1, 7], 11: [1, 7], 12: [6, 7], 13: [1, 5], 14: [5, 7], 15: [3, 6], 16: [1, 2], 17: [3, 6], 18: [3, 6], 19: [1, 7], 20: [2, 7], 21: [3, 6], 22: [1, 7], 23: [6, 7], 24: [3, 6], 25: [2, 7], 26: [1, 3], 27: [1, 9], 28: [5, 9], 29: [1, 7], 30: [3, 6], 31: [1, 5] },
    4: { 1: [1, 7], 2: [1, 7], 3: [3, 9], 4: [1, 7], 5: [5, 7], 6: [3, 6], 7: [5, 7], 8: [1, 3], 9: [3, 9], 10: [1, 7], 11: [1, 7], 12: [1, 9], 13: [1, 7], 14: [5, 7], 15: [3, 6], 16: [1, 2], 17: [1, 3], 18: [1, 3], 19: [1, 7], 20: [2, 7], 21: [1, 3], 22: [1, 7], 23: [5, 7], 24: [3, 5], 25: [5, 7], 26: [2, 3], 27: [3, 6], 28: [2, 7], 29: [1, 7], 30: [5, 6], 31: [1, 3] },
    5: { 1: [1, 2], 2: [2, 7], 3: [3, 6], 4: [1, 7], 5: [5, 6], 6: [5, 6], 7: [2, 7], 8: [2, 5], 9: [5, 9], 10: [1, 5], 11: [1, 7], 12: [2, 6], 13: [1, 7], 14: [5, 6], 15: [5, 6], 16: [2, 5], 17: [2, 3], 18: [5, 6], 19: [1, 2], 20: [2, 7], 21: [3, 6], 22: [1, 7], 23: [5, 6], 24: [5, 6], 25: [2, 7], 26: [2, 5], 27: [5, 9], 28: [2, 7], 29: [5, 7], 30: [2, 3], 31: [1, 5] },
    6: { 1: [1, 5], 2: [2, 7], 3: [5, 6], 4: [1, 5], 5: [5, 6], 6: [5, 6], 7: [2, 7], 8: [3, 5], 9: [5, 9], 10: [1, 5], 11: [5, 7], 12: [5, 6], 13: [1, 5], 14: [5, 6], 15: [5, 6], 16: [2, 5], 17: [2, 5], 18: [5, 6], 19: [1, 5], 20: [2, 7], 21: [5, 6], 22: [1, 5], 23: [5, 6], 24: [5, 6], 25: [2, 7], 26: [2, 5], 27: [5, 6], 28: [2, 7], 29: [1, 7], 30: [3, 6], 31: [1, 5] },
    7: { 1: [1, 2], 2: [2, 7], 3: [2, 3], 4: [1, 7], 5: [5, 7], 6: [2, 6], 7: [2, 7], 8: [2, 3], 9: [2, 3], 10: [1, 2], 11: [1, 7], 12: [2, 6], 13: [1, 2], 14: [5, 7], 15: [6, 7], 16: [1, 2], 17: [2, 3], 18: [2, 3], 19: [1, 2], 20: [2, 7], 21: [3, 6], 22: [1, 2], 23: [5, 7], 24: [6, 7], 25: [2, 7], 26: [2, 3], 27: [1, 9], 28: [2, 7], 29: [1, 7], 30: [3, 6], 31: [1, 7] },
    8: { 1: [1, 2], 2: [1, 5], 3: [3, 6], 4: [1, 2], 5: [1, 5], 6: [3, 6], 7: [2, 7], 8: [2, 3], 9: [3, 6], 10: [1, 2], 11: [1, 7], 12: [1, 6], 13: [1, 5], 14: [1, 5], 15: [1, 6], 16: [1, 2], 17: [1, 3], 18: [1, 3], 19: [1, 2], 20: [2, 7], 21: [3, 6], 22: [1, 2], 23: [1, 5], 24: [3, 6], 25: [2, 7], 26: [2, 3], 27: [3, 6], 28: [2, 5], 29: [1, 5], 30: [3, 6], 31: [1, 5] },
    9: { 1: [1, 5], 2: [2, 5], 3: [3, 6], 4: [1, 5], 5: [5, 6], 6: [5, 6], 7: [2, 5], 8: [2, 3], 9: [3, 6], 10: [1, 2], 11: [1, 5], 12: [3, 6], 13: [1, 7], 14: [5, 6], 15: [5, 6], 16: [2, 5], 17: [2, 3], 18: [3, 6], 19: [1, 5], 20: [2, 7], 21: [3, 6], 22: [1, 7], 23: [5, 6], 24: [3, 6], 25: [2, 7], 26: [3, 6], 27: [6, 9], 28: [2, 7], 29: [1, 7], 30: [3, 6], 31: [1, 5] },
    10: { 1: [2, 7], 2: [2, 7], 3: [3, 6], 4: [1, 7], 5: [5, 6], 6: [3, 6], 7: [2, 7], 8: [3, 6], 9: [3, 6], 10: [1, 5], 11: [1, 6], 12: [2, 6], 13: [1, 7], 14: [5, 6], 15: [3, 6], 16: [1, 2], 17: [3, 6], 18: [3, 6], 19: [2, 7], 20: [2, 7], 21: [3, 6], 22: [1, 7], 23: [5, 6], 24: [3, 6], 25: [2, 7], 26: [3, 6], 27: [6, 9], 28: [2, 7], 29: [1, 7], 30: [3, 6], 31: [1, 3] },
    11: { 1: [1, 7], 2: [1, 7], 3: [3, 9], 4: [1, 7], 5: [5, 7], 6: [3, 5], 7: [1, 7], 8: [3, 9], 9: [3, 9], 10: [2, 7], 11: [1, 7], 12: [1, 9], 13: [1, 7], 14: [5, 7], 15: [3, 5], 16: [1, 5], 17: [3, 9], 18: [3, 9], 19: [1, 7], 20: [2, 7], 21: [3, 9], 22: [1, 7], 23: [5, 7], 24: [3, 5], 25: [1, 7], 26: [3, 9], 27: [3, 9], 28: [2, 7], 29: [1, 7], 30: [3, 6], 31: [1, 7] },
    12: { 1: [1, 7], 2: [2, 7], 3: [3, 6], 4: [1, 7], 5: [3, 6], 6: [3, 6], 7: [2, 7], 8: [2, 3], 9: [3, 9], 10: [1, 7], 11: [1, 7], 12: [6, 9], 13: [1, 3], 14: [5, 6], 15: [3, 6], 16: [1, 2], 17: [2, 3], 18: [3, 6], 19: [1, 7], 20: [2, 7], 21: [3, 6], 22: [1, 7], 23: [5, 6], 24: [3, 6], 25: [3, 7], 26: [3, 6], 27: [6, 9], 28: [5, 6], 29: [1, 6], 30: [3, 6], 31: [1, 7] }
};

function calculateFavorableDaysList(birthDate) {
    const day = birthDate.getDate();
    const month = birthDate.getMonth() + 1; // JS Month is 0-indexed

    const monthTable = BASE_DAYS_TABLE[month];
    if (!monthTable) return [];

    const bases = monthTable[day];
    if (!bases || bases.length !== 2) return [];

    const b1 = bases[0];
    const b2 = bases[1];
    const days = new Set([b1, b2]);

    let sum = b2 * 2;
    if (sum <= 31) days.add(sum);

    let alterna = true;
    while (true) {
        const valToAdd = alterna ? b1 : b2;
        sum += valToAdd;
        if (sum > 31) break;
        days.add(sum);
        alterna = !alterna;
    }
    return Array.from(days).sort((a, b) => a - b);
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
    10: ["Renovação"], 11: ["Inspiração", "Mestre"], 22: ["Construção", "Grandeza"]
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

// Target Date Logic
let targetDateStr = params.target_date;
let isSuggestionMode = false;
let targetDate = null;

if (!targetDateStr || targetDateStr === 'null') {
    isSuggestionMode = true;
    targetDateStr = null;
} else {
    targetDate = parseDate(targetDateStr);
}

// Pre-Calculate Favorable Days List for the user
const favorableDaysList = calculateFavorableDaysList(birthDate);

// === SCORING ===
function evaluateDate(date, bDate, dNum, favList) {
    const pDay = calculatePersonalDay(date, bDate);
    const dayOfMonth = date.getDate();

    // Cross-Harmonization Logic
    let status = "Neutro";
    let score = 50;

    // 1. Primary Check: Is it in the Favorable Days List? (Gold Standard)
    if (favList.includes(dayOfMonth)) {
        status = "Dia de Sorte";
        score = 100;
    } else {
        // 2. Secondary Check: Destiny Number Harmonization
        const rules = MATRIX[dNum] || MATRIX[1];
        if (rules.fav.includes(pDay)) {
            status = "Favorável";
            score = 75; // Good, but not a "List Day"
        } else if (rules.unfav.includes(pDay)) {
            status = "Desafiador";
            score = 0;
        } else {
            status = "Neutro";
            score = 50;
        }
    }

    return { date, personalDay: pDay, status, score, vibe: VIBE_KEYWORDS[pDay] || [] };
}

let mainAnalysis = {};
if (!isSuggestionMode && targetDate) {
    mainAnalysis = evaluateDate(targetDate, birthDate, destinyNum, favorableDaysList);
    mainAnalysis.is_favorable = mainAnalysis.score >= 50;
}

// Find Suggestions
let suggestions = [];
let scanDate = targetDate ? new Date(targetDate) : new Date();
scanDate.setDate(scanDate.getDate() + 1); // +1 dia

// Suggestion Search Loop
let attempts = 0;
while (suggestions.length < 3 && attempts < 90) { // Increased to 90 days to find high quality matches
    const ev = evaluateDate(scanDate, birthDate, destinyNum, favorableDaysList);

    // Filter: User requested "High Favorable" (>75) and NOT Neutral.
    // Our scores: 100 (Lucky), 75 (Favorable), 50 (Neutral), 0 (Bad)
    if (ev.score >= 75) {
        suggestions.push({
            date: ev.date.toISOString(),
            personalDay: ev.personalDay,
            vibe: ev.vibe,
            status: ev.status,
            score: ev.score
        });
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
        status: mainAnalysis.status,
        score: mainAnalysis.score
    },
    suggestedDates: suggestions,
    debug_info: {
        birthDate: birthDate.toISOString().split('T')[0],
        destinyNum: destinyNum,
        favorableDaysList: favorableDaysList,
        targetDateParsed: targetDate ? targetDate.toISOString().split('T')[0] : 'null',
    }
};
