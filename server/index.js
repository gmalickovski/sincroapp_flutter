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

// Serve Static Files for Features Documentation
app.use('/funcionalidades', express.static(path.join(__dirname, '../web/funcionalidades')));

// Serve Maintenance & Construction Files (Root Level)
app.get('/construction_check.js', (req, res) => {
    res.sendFile(path.join(__dirname, '../web/construction_check.js'));
});
app.get('/maintenance.html', (req, res) => {
    res.sendFile(path.join(__dirname, '../web/maintenance.html'));
});
app.get('/under_construction.html', (req, res) => {
    res.sendFile(path.join(__dirname, '../web/under_construction.html'));
});

// Serve Landing Page (Home) at Root
app.use(express.static(path.join(__dirname, '../web/home')));

// Serve Global Assets (Images, Fonts, etc.)
app.use('/assets', express.static(path.join(__dirname, '../web/assets')));

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

        // Handle links
        if (t.href) {
            content = `<a href="${t.href}" target="_blank" rel="noopener">${content}</a>`;
        }

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
                html += `<h2>${richText(block.heading_1.rich_text)}</h2>`;
                break;
            case 'heading_2':
                html += `<h3>${richText(block.heading_2.rich_text)}</h3>`;
                break;
            case 'heading_3':
                html += `<h4>${richText(block.heading_3.rich_text)}</h4>`;
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
            case 'quote':
                html += `<blockquote>${richText(block.quote.rich_text)}</blockquote>`;
                break;
            case 'callout':
                const icon = block.callout.icon?.emoji || '💡';
                html += `<div class="callout"><span class="callout-icon">${icon}</span><div class="callout-content">${richText(block.callout.rich_text)}</div></div>`;
                break;
            case 'code':
                const lang = block.code.language || 'plaintext';
                html += `<pre><code class="language-${lang}">${richText(block.code.rich_text)}</code></pre>`;
                break;
            case 'image':
                const imgUrl = block.image.type === 'external'
                    ? block.image.external.url
                    : block.image.file.url;
                const caption = block.image.caption?.length > 0
                    ? `<figcaption>${richText(block.image.caption)}</figcaption>`
                    : '';
                html += `<figure><img src="${imgUrl}" alt="Imagem" loading="lazy">${caption}</figure>`;
                break;
            case 'toggle':
                const toggleContent = richText(block.toggle.rich_text);
                html += `<details><summary>${toggleContent}</summary><div class="toggle-content"></div></details>`;
                break;
            case 'to_do':
                const checked = block.to_do.checked ? 'checked' : '';
                html += `<div class="todo-item"><input type="checkbox" ${checked} disabled><span>${richText(block.to_do.rich_text)}</span></div>`;
                break;
            default:
                // Skip unsupported block types
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

// API Route: Get Features List (for documentation page)
app.get('/api/features', async (req, res) => {
    try {
        const FEATURES_DATABASE_ID = process.env.PLANS_DATABASE_ID || process.env.NOTION_PLANS_DATABASE_ID;
        console.log("Fetching Features from Notion...");

        const response = await notion.databases.query({
            database_id: FEATURES_DATABASE_ID,
            filter: {
                property: "Landing Page",
                checkbox: { equals: true },
            },
            sorts: [
                { property: "Data de Edição", direction: "descending" }
            ],
        });

        const features = response.results.map(page => ({
            id: page.id,
            name: page.properties['Funcionalidade']?.title[0]?.plain_text || "Sem nome",
            shortDescription: page.properties['Descrição Curta']?.rich_text[0]?.plain_text || "",
            image: page.properties['Imagem']?.files[0]?.file?.url || page.properties['Imagem']?.files[0]?.external?.url || "https://picsum.photos/seed/sincro/1200/800",
            imgMobile: page.properties['Imagem Mobile']?.files[0]?.file?.url || page.properties['Imagem Mobile']?.files[0]?.external?.url || page.properties['Imagem']?.files[0]?.file?.url || "https://picsum.photos/seed/sincro/350/800",
            imgDesktop: page.properties['Imagem Desktop']?.files[0]?.file?.url || page.properties['Imagem Desktop']?.files[0]?.external?.url || page.properties['Imagem']?.files[0]?.file?.url || "https://picsum.photos/seed/sincro/1200/800",
            plans: page.properties['Plano']?.multi_select?.map(tag => tag.name) || [],
        }));

        console.log("Loaded Features:", features.length);
        if (features.length > 0) {
            console.log("DEBUG: Available Notion Properties:", Object.keys(response.results[0].properties));
            console.log("Sample Feature Images:", {
                name: features[0].name,
                img: features[0].image,
                mob: features[0].imgMobile,
                desk: features[0].imgDesktop
            });
        }

        res.json({ features });

    } catch (error) {
        console.error("Notion Features API Error:", error);
        res.status(500).json({ error: "Failed to fetch features", details: error.message });
    }
});

// API Route: Get Single Feature with full content
app.get('/api/features/:id', async (req, res) => {
    try {
        const { id } = req.params;
        console.log(`Fetching Feature ${id} from Notion...`);

        // Get page properties
        const page = await notion.pages.retrieve({ page_id: id });

        // Get page content blocks
        const blocks = await notion.blocks.children.list({ block_id: id });
        const contentHtml = notionToHtml(blocks.results);

        const feature = {
            id: page.id,
            name: page.properties['Funcionalidade']?.title[0]?.plain_text || "Sem nome",
            shortDescription: page.properties['Descrição Curta']?.rich_text[0]?.plain_text || "",
            plans: page.properties['Plano']?.multi_select?.map(tag => tag.name) || [],
            createdAt: page.properties['Data de Criação']?.date?.start || page.created_time,
            updatedAt: page.properties['Data de Edição']?.date?.start || page.last_edited_time,
            version: page.properties['Versão']?.rich_text?.[0]?.plain_text || "1.0",
            content: contentHtml
        };

        res.json({ feature });

    } catch (error) {
        console.error("Notion Feature Detail API Error:", error);
        res.status(500).json({ error: "Failed to fetch feature", details: error.message });
    }
});

app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});
