// ------------------------------------------------------------------
// LÓGICA DE COMPATIBILIDADE (VERSÃO 3.0 - SOLVER DE MELHOR MATCH)
// ------------------------------------------------------------------

// --- HELPER: Reduce Number ---
function reduce(num) {
    if (!num) return 0;
    if (num === 11 || num === 22) return num;
    let sum = parseInt(num);
    while (sum > 9 && sum !== 11 && sum !== 22) {
        sum = sum.toString().split('').reduce((a, b) => parseInt(a) + parseInt(b), 0);
    }
    return sum;
}

// --- TABELA DE HARMONIZAÇÃO ---
// Definida fora para ser reusável na simulação
const HARMONY_TABLE = {
    1: { favorable: [3, 5, 9], unfavorable: [6] },
    2: { favorable: [2, 4, 6, 7], unfavorable: [5, 9] },
    3: { favorable: [1, 3, 5, 6], unfavorable: [4, 7, 8] },
    4: { favorable: [2, 6, 8], unfavorable: [3, 5, 7, 9] },
    5: { favorable: [1, 3, 5, 7, 9], unfavorable: [2, 4, 6, 8] },
    6: { favorable: [2, 3, 4, 8, 9], unfavorable: [1, 5, 7] },
    7: { favorable: [2, 5, 7], unfavorable: [3, 4, 6, 8, 9] },
    8: { favorable: [4, 6], unfavorable: [3, 5, 7, 8, 9] },
    9: { favorable: [1, 5, 6, 9], unfavorable: [2, 4, 7, 8] },
    11: { favorable: [2, 4, 6, 7, 11], unfavorable: [5, 9] },
    22: { favorable: [2, 6, 8, 22], unfavorable: [3, 5, 7, 9] }
};

// --- FUNÇÃO DE CÁLCULO (Simulável) ---
function calculateScore(profVib, userExpr, userDest, userPath) {
    let s = 0;
    let r = [];

    // A. EXPRESSÃO (50%)
    if (profVib === userExpr) {
        s += 50;
        r.push("Compatibilidade Total com sua Expressão (Talento Natural)");
    } else {
        const rules = HARMONY_TABLE[userExpr] || HARMONY_TABLE[reduce(userExpr)];
        if (rules && rules.favorable.includes(profVib)) {
            s += 35;
        } else if (rules && rules.unfavorable.includes(profVib)) {
            s += 10;
        } else {
            s += 25;
        }
    }

    // B. DESTINO (30%)
    if (profVib === userDest) {
        s += 30;
    } else {
        const rules = HARMONY_TABLE[userDest] || HARMONY_TABLE[reduce(userDest)];
        if (rules && rules.favorable.includes(profVib)) s += 20;
        else if (rules && rules.unfavorable.includes(profVib)) s += 5;
        else s += 15;
    }

    // C. MISSÃO (20%)
    if (profVib === userPath) {
        s += 20;
    } else {
        const isProfOdd = profVib % 2 !== 0;
        const isPathOdd = userPath % 2 !== 0;
        if (isProfOdd === isPathOdd) s += 10;
        else s += 5;
    }

    // Arredondamento
    return Math.min(100, Math.round(s / 5) * 5);
}


// --- 1. RECUPERAÇÃO DE DADOS ---
let user = null;
try {
    if ($input.item.json.user) user = $input.item.json.user;
    else if ($input.item.json.body && $input.item.json.body.user) user = $input.item.json.body.user;

    if (!user) {
        const webhookData = $('Webhook').first();
        if (webhookData) user = webhookData.json.body.user;
    }
} catch (e) { }

if (!user) throw new Error("User Data Not Found");

// --- 2. PARSE DA CLASSIFICAÇÃO DA IA ---
let aiData = {};
let rawOutput = $input.item.json;
const possibleKeys = ['output', 'text', 'response', 'content'];

if (rawOutput.primary) {
    aiData = rawOutput;
} else {
    for (const key of possibleKeys) {
        if (rawOutput[key]) {
            let cleanJson = rawOutput[key].toString().replace(/```json/g, '').replace(/```/g, '').trim();
            try { aiData = JSON.parse(cleanJson); break; } catch (e) { }
        }
    }
}
if (!aiData.primary && !aiData.primary_vibration) aiData = { primary_vibration: 1 };

// --- 3. EXECUÇÃO REAL ---
const expression = reduce(user.numerology.expression);
const destiny = reduce(user.numerology.destiny);
const path = reduce(user.numerology.path);

const profVibration = reduce(aiData.primary_vibration || aiData.primary);
const profName = aiData.category || "Profissão";

// Calcula o Score Real
let realScore = calculateScore(profVibration, expression, destiny, path);

// --- 4. SOLVER (Encontrar a Melhor Sugestão) ---
// Simulamos todas as vibrações (1 a 9) para ver qual dá o maior score para ESSE usuário
let bestVib = expression;
let maxPossibleScore = 0;

for (let v = 1; v <= 9; v++) {
    let simScore = calculateScore(v, expression, destiny, path);
    if (simScore > maxPossibleScore) {
        maxPossibleScore = simScore;
        bestVib = v;
    }
}

// Se o maxPossibleScore ainda for baixo (<90), tentamos os Mestres (11, 22) se aplicável
if (maxPossibleScore < 90) {
    let sim11 = calculateScore(11, expression, destiny, path);
    if (sim11 > maxPossibleScore) { maxPossibleScore = sim11; bestVib = 11; }

    let sim22 = calculateScore(22, expression, destiny, path);
    if (sim22 > maxPossibleScore) { maxPossibleScore = sim22; bestVib = 22; }
}

// Lógica de Gatilho
let suggestionsNeeded = realScore < 90;

// Recalcula os motivos REAIS para passar pro texto
let realReasons = [];
// (Replicando a lógica de texto do cálculo principal para display)
// Expressão
if (profVibration === expression) realReasons.push("Compatível com seu Talento Natural (Expressão)");
else {
    const rules = HARMONY_TABLE[expression] || HARMONY_TABLE[reduce(expression)];
    if (rules && rules.favorable.includes(profVibration)) realReasons.push("Harmoniza com seus Talentos");
    else if (rules && rules.unfavorable.includes(profVibration)) realReasons.push("Desafia sua zona de conforto natural");
}
// Destino
if (profVibration === destiny) realReasons.push("Alinhado ao seu Destino");
else {
    const rules = HARMONY_TABLE[destiny] || HARMONY_TABLE[reduce(destiny)];
    if (rules && rules.favorable.includes(profVibration)) realReasons.push("Favorece seu caminho de vida");
}
// Missão
if (profVibration === path) realReasons.push("Conectado à sua Missão de Vida");


// RETORNO
return {
    json: {
        calculated_score: realScore,
        reasons: realReasons,
        profession_vibration: profVibration,
        user: user, // Passa tudo pro prompt usar na explicação
        profession: $input.item.json.profession || profName,
        suggestions: {
            needed: suggestionsNeeded,
            ideal_vibration: bestVib, // AGORA SIM: A melhor vibração MATEMÁTICA possível
            max_possible_score: maxPossibleScore
        }
    }
};
