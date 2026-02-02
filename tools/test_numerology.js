
const fs = require('fs');

// Mock N8n Environment
const items = [{
    json: {
        params: {
            title: "Test",
            target_date: "2026-02-14", // Testing a specific date
            intent: "consultation"
        }
    }
}];

const $ = (nodeName) => {
    return {
        item: {
            json: {
                body: {
                    context: {
                        user: { dataNasc: "1990-02-14" },
                        numerology: { numeros: { destino: 5 } } // Assuming Destiny 5 for test context
                    }
                }
            }
        }
    };
};

// Read and Eval the Engine Code
const engineCode = fs.readFileSync('tools/numerology_engine.js', 'utf8');

// Wrap in a function to execute
const runEngine = new Function('items', '$', engineCode);

const result = runEngine(items, $);

console.log("=== DEBUG INFO ===");
console.log(JSON.stringify(result.debug_info, null, 2));

console.log("\n=== SUGGESTIONS ===");
result.suggestedDates.forEach(s => {
    console.log(`Date: ${s.date.split('T')[0]} | Score: ${s.score} | Status: ${s.status}`);
});
