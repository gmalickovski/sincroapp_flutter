require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { Client } = require('@notionhq/client');
const axios = require('axios');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors()); // Allow all origins (configured via Nginx in prod)
app.use(express.json());

// Notion Config
const notion = new Client({ auth: process.env.NOTION_API_KEY });
const NOTION_DATABASE_ID = process.env.NOTION_FAQ_DATABASE_ID;

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

            // Convert blocks to simple HTML
            let htmlContent = "";
            for (const block of blocks.results) {
                if (block.type === 'paragraph') {
                    const text = block.paragraph.rich_text.map(t => t.plain_text).join("");
                    if (text) htmlContent += `<p>${text}</p>`;
                } else if (block.type === 'heading_1') {
                    htmlContent += `<h3>${block.heading_1.rich_text.map(t => t.plain_text).join("")}</h3>`;
                } else if (block.type === 'heading_2') {
                    htmlContent += `<h4>${block.heading_2.rich_text.map(t => t.plain_text).join("")}</h4>`;
                } else if (block.type === 'heading_3') {
                    htmlContent += `<h5>${block.heading_3.rich_text.map(t => t.plain_text).join("")}</h5>`;
                } else if (block.type === 'bulleted_list_item') {
                    htmlContent += `<ul><li>${block.bulleted_list_item.rich_text.map(t => t.plain_text).join("")}</li></ul>`;
                } else if (block.type === 'numbered_list_item') {
                    htmlContent += `<ol><li>${block.numbered_list_item.rich_text.map(t => t.plain_text).join("")}</li></ol>`;
                }
            }

            items.push({
                id: page.id,
                question: questionTitle,
                category: category,
                answerHtml: htmlContent
            });
        }

        res.json({ faq: items });

    } catch (error) {
        console.error("Notion API Error:", error);
        res.status(500).json({ error: "Failed to fetch FAQ", details: error.message });
    }
});

const FEEDBACK_WEBHOOK_URL = "https://n8n.webhook.sincroapp.com.br/webhook/app-feedback";

// API Route: Submit Feedback
app.post('/api/feedback', async (req, res) => {
    try {
        console.log("Receiving feedback submission...");
        const { type, description, user_id, user_email, name, device_info, app_version, attachment_url } = req.body;

        const payload = {
            event: 'user_feedback',
            type, // 'bug', 'idea', 'account', etc.
            description,
            app_version: app_version || 'Web Help Center',
            device_info: device_info || req.headers['user-agent'],
            user_id: user_id || 'anonymous_web',
            user_email: user_email || 'anonymous',
            name: name || 'Visitante Web',
            image_url: attachment_url || null,
            timestamp: new Date().toISOString()
        };

        console.log("Forwarding to n8n:", payload);

        await axios.post(FEEDBACK_WEBHOOK_URL, payload);

        res.json({ success: true, message: "Feedback sent" });

    } catch (error) {
        console.error("Feedback Error:", error.message);
        res.status(500).json({ error: "Failed to submit feedback" });
    }
});

// Start Server
app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});
