const path = require('path');
const dotenv = require('dotenv');

// DEBUG: Load .env from server directory explicitly
const envPath = path.join(__dirname, '.env');
console.log(`[DEBUG] Attempting to load .env from: ${envPath}`);
const result = dotenv.config({ path: envPath });

if (result.error) {
    console.error(`[DEBUG] Error loading .env: ${result.error.message}`);
    // Fallback: try default loading (cwd)
    console.log('[DEBUG] Trying default dotenv load...');
    dotenv.config();
} else {
    console.log(`[DEBUG] .env loaded successfully.`);
}

console.log(`[DEBUG] NOTION_API_KEY available: ${!!process.env.NOTION_API_KEY}`);
if (process.env.NOTION_API_KEY) {
    console.log(`[DEBUG] NOTION_API_KEY length: ${process.env.NOTION_API_KEY.length}`);
    console.log(`[DEBUG] NOTION_API_KEY start: ${process.env.NOTION_API_KEY.substring(0, 4)}...`);
} else {
    console.error('[DEBUG] CRITICAL: NOTION_API_KEY is MISSING in process.env');
}

const express = require('express');
const cors = require('cors');
const axios = require('axios');
const { Client } = require('@notionhq/client');

const app = express();
const PORT = process.env.PORT || 3000;

// Enable CORS
app.use(cors());

// Serve Static Files for Web Help Center
app.use('/central-de-ajuda', express.static(path.join(__dirname, '../web/central-de-ajuda')));

// Serve Static Files for Plans & Pricing (New)
app.use('/planos-e-precos', express.static(path.join(__dirname, '../web/planos-e-precos')));

// Content Security Policy (Optional - preventing errors in browser log)
app.use((req, res, next) => {
    res.setHeader("Content-Security-Policy", "default-src 'self'; script-src 'self' 'unsafe-inline' https://www.gstatic.com; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data: https://*.firebasealt.com https://firebasestorage.googleapis.com; connect-src 'self' http://localhost:3000 https://n8n.studiomlk.com.br https://firebasestorage.googleapis.com;");
    next();
});

app.use(express.json());

// Notion Client
const notion = new Client({ auth: process.env.NOTION_API_KEY });
const NOTION_DATABASE_ID = process.env.NOTION_FAQ_DATABASE_ID;

// Helper: Convert Block Children to HTML
const richText = (textArray) => {
    if (!textArray) return '';
    return textArray.map(t => {
        let content = t.plain_text
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;");

        const { bold, italic, strikethrough, underline, code, color } = t.annotations;
        if (bold) content = `<b>${content}</b>`;
        if (italic) content = `<i>${content}</i>`;
        if (strikethrough) content = `<s>${content}</s>`;
        if (underline) content = `<u>${content}</u>`;
        if (code) content = `<code>${content}</code>`;
        return content;
    }).join("");
};

const notionToHtml = (blocks) => {
    let html = "";
    let listType = null;

    for (const block of blocks) {
        if (listType && block.type !== 'bulleted_list_item' && block.type !== 'numbered_list_item') {
            html += `</${listType}>`;
            listType = null;
        }

        switch (block.type) {
            case 'paragraph':
                html += `<p>${richText(block.paragraph.rich_text)}</p>`;
                break;
            case 'heading_1':
                html += `<h3>${richText(block.heading_1.rich_text)}</h3>`;
                break;
            case 'heading_2':
                html += `<h4>${richText(block.heading_2.rich_text)}</h4>`;
                break;
            case 'heading_3':
                html += `<h5>${richText(block.heading_3.rich_text)}</h5>`;
                break;
            case 'bulleted_list_item':
                if (listType !== 'ul') {
                    if (listType) html += `</${listType}>`;
                    html += '<ul>';
                    listType = 'ul';
                }
                html += `<li>${richText(block.bulleted_list_item.rich_text)}</li>`;
                break;
            case 'numbered_list_item':
                if (listType !== 'ol') {
                    if (listType) html += `</${listType}>`;
                    html += '<ol>';
                    listType = 'ol';
                }
                html += `<li>${richText(block.numbered_list_item.rich_text)}</li>`;
                break;
            case 'divider':
                html += `<hr>`;
                break;
            default:
                break;
        }
    }
    if (listType) html += `</${listType}>`;
    return html;
};

// API Route: Get FAQ
app.get('/api/faq', async (req, res) => {
    try {
        console.log("Fetching FAQ from Notion...");

        // 1. Query Database
        const response = await notion.databases.query({
            database_id: NOTION_DATABASE_ID,
            filter: {
                property: "Publicado",
                checkbox: {
                    equals: true,
                },
            },
            sorts: [
                {
                    timestamp: "created_time",
                    direction: "ascending",
                },
            ],
        });

        const items = [];

        // 2. Iterate results
        for (const page of response.results) {
            const questionTitle = page.properties.Pergunta?.title[0]?.plain_text || "Sem título";
            const category = page.properties['Tópico']?.select?.name || "Geral";



            // Fetch Page Content
            const blocks = await notion.blocks.children.list({
                block_id: page.id,
            });

            // Convert Blocks to HTML
            const answerHtml = notionToHtml(blocks.results);

            items.push({
                question: questionTitle,
                answer: answerHtml,
                category: category
            });
        }

        res.json({ faq: items });

    } catch (error) {
        console.error("Notion API Error:", error);
        res.status(500).json({ error: "Failed to fetch FAQ", details: error.message });
    }
});

const FEEDBACK_WEBHOOK_URL = "https://n8n.studiomlk.com.br/webhook/sincroapp-feedback";

app.post('/api/feedback', async (req, res) => {
    try {
        console.log("Receiving feedback submission...");
        const feedbackData = req.body;

        console.log("Forwarding to n8n:", JSON.stringify(feedbackData, null, 2));

        const response = await axios.post(FEEDBACK_WEBHOOK_URL, feedbackData);

        console.log("n8n response status:", response.status);
        res.json({ success: true, n8n_status: response.status });
    } catch (error) {
        console.error("Feedback Error:", error.message);
        if (error.response) {
            console.error("n8n Response Data:", error.response.data);
        }
        res.status(500).json({ error: "Failed to submit feedback" });
    }
});

// API Route: Get Plans (Dynamic)
app.get('/api/plans', async (req, res) => {
    try {
        const PLANS_DATABASE_ID = process.env.PLANS_DATABASE_ID || process.env.NOTION_PLANS_DATABASE_ID; // Support both for safety
        console.log("Fetching Plans from Notion...", PLANS_DATABASE_ID);

        const response = await notion.databases.query({
            database_id: PLANS_DATABASE_ID,
            filter: {
                property: "Publicar",
                checkbox: { equals: true },
            },
            sorts: [
                { property: "Funcionalidade", direction: "ascending" }
            ],
        });

        const cards = {
            free: [],
            plus: [],
            premium: []
        };

        const comparison = [];

        response.results.forEach(page => {
            const name = page.properties['Funcionalidade']?.title[0]?.plain_text || "Sem nome";
            const planTags = page.properties['Plano']?.multi_select?.map(tag => tag.name) || [];

            // 1. Comparison Data (Full Data)
            comparison.push({
                name: name,
                tags: planTags
            });

            // 2. Cards Data (Cascade Exclusion Logic)
            if (planTags.includes('Essencial')) {
                cards.free.push(name);
            } else if (planTags.includes('Desperta')) {
                cards.plus.push(name);
            } else if (planTags.includes('Sinergia')) {
                cards.premium.push(name);
            }
        });

        res.json({ cards, comparison });

    } catch (error) {
        console.error("Notion Plans API Error:", error);
        res.status(500).json({ error: "Failed to fetch plans", details: error.message });
    }
});

app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});
