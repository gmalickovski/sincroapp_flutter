const path = require('path');
const dotenv = require('dotenv');

// Load .env from ROOT of the project (one level up)
// This ensures we use the unified .env file used by install/deploy scripts.
const envPath = path.resolve(__dirname, '../.env');
console.log(`[SERVER] Loading .env from: ${envPath}`);
dotenv.config({ path: envPath });

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
const { createClient } = require('@supabase/supabase-js');
console.log(`[DEBUG] STRIPE_SECRET_KEY available: ${!!process.env.STRIPE_SECRET_KEY}`);
let stripe;
if (process.env.STRIPE_SECRET_KEY) {
    stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
} else {
    console.warn('[WARNING] STRIPE_SECRET_KEY is missing. Stripe features will not work.');
    // Mock stripe object to prevent immediate crash, allow server to start for other features
    stripe = {
        webhooks: {
            constructEvent: () => { throw new Error('Stripe Key missing in .env'); }
        },
        billingPortal: {
            sessions: { create: async () => { throw new Error('Stripe Key missing in .env'); } }
        }
    };
}

const crypto = require('crypto');
// body-parser is needed for specific routes, but express.json() is global.
// We need raw body for stripe webhook.

const app = express();

// Initialize Supabase Admin Client
// Ensure these are in .env
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

// Fail gracefully if keys are missing (for dev)
let supabase;
if (supabaseUrl && supabaseServiceKey) {
    // UPDATED: Target 'sincroapp' schema directly
    supabase = createClient(supabaseUrl, supabaseServiceKey, {
        db: {
            schema: 'sincroapp'
        }
    });
} else {
    console.warn('[WARNING] Supabase URL or Service Key missing. Database operations will fail.');
}
const PORT = process.env.PORT || 3000;

// Enable CORS
app.use(cors());

// Serve Static Files for Web Help Center
app.use('/central-de-ajuda', express.static(path.join(__dirname, '../web/central-de-ajuda')));

// Serve Static Files for Plans & Pricing (New)
app.use('/planos-e-precos', express.static(path.join(__dirname, '../web/planos-e-precos')));

// Serve Static Files for Features Documentation
app.use('/funcionalidades', express.static(path.join(__dirname, '../web/funcionalidades')));

// Serve Static Files for About Page
app.use('/sobre', express.static(path.join(__dirname, '../web/sobre')));

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

// Serve Thank You Page
app.get('/thank-you', (req, res) => {
    res.sendFile(path.join(__dirname, '../web/thank-you.html'));
});
app.get('/thankyou', (req, res) => {
    res.sendFile(path.join(__dirname, '../web/thank-you.html'));
});

// Serve Landing Page (Home) at Root
app.use(express.static(path.join(__dirname, '../web/home')));

// Serve Global Assets (Images, Fonts, etc.) - Allow dotfiles for .env loading
app.use('/assets', express.static(path.join(__dirname, '../web/assets'), { dotfiles: 'allow' }));

// Content Security Policy (Optional - preventing errors in browser log)
app.use((req, res, next) => {
    res.setHeader("Content-Security-Policy", "default-src 'self'; script-src 'self' 'unsafe-inline' https://www.gstatic.com https://cdn.tailwindcss.com; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data: https://*.firebasealt.com https://firebasestorage.googleapis.com https://placehold.co; connect-src 'self' http://localhost:3000 http://www.localhost:3000 https://n8n.studiomlk.com.br https://firebasestorage.googleapis.com;");
    next();
});

// Stripe Webhook needs raw body
app.use('/api/webhooks/stripe', express.raw({ type: 'application/json' }));

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

        // Helper to render children if they exist
        const renderChildren = (children) => {
            if (children && children.length > 0) {
                return notionToHtml(children);
            }
            return '';
        };

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
                    html += '<ul class="notion-list-disc">';
                    listType = 'ul';
                }
                // Include nested children for list items
                const bulletChildren = renderChildren(block.children);
                html += `<li>${richText(block.bulleted_list_item.rich_text)}${bulletChildren}</li>`;
                break;
            case 'numbered_list_item':
                if (listType !== 'ol') {
                    if (listType) html += `</${listType}>`;
                    html += '<ol class="notion-list-decimal">';
                    listType = 'ol';
                }
                // Include nested children for list items
                const numChildren = renderChildren(block.children);
                html += `<li>${richText(block.numbered_list_item.rich_text)}${numChildren}</li>`;
                break;
            case 'divider':
                html += `<hr>`;
                break;
            case 'quote':
                const quoteChildren = renderChildren(block.children);
                html += `<blockquote>${richText(block.quote.rich_text)}${quoteChildren}</blockquote>`;
                break;
            case 'callout':
                const icon = block.callout.icon?.emoji || '💡';
                // IMPORTANT: Render nested children inside the callout
                const calloutChildren = renderChildren(block.children);
                html += `<div class="callout"><span class="callout-icon">${icon}</span><div class="callout-content">${richText(block.callout.rich_text)}${calloutChildren ? `<div class="callout-children">${calloutChildren}</div>` : ''}</div></div>`;
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
                // IMPORTANT: Render nested children inside the toggle
                const toggleChildren = renderChildren(block.children);
                html += `<details><summary>${toggleContent}</summary><div class="toggle-content">${toggleChildren}</div></details>`;
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
        const { featured } = req.query;
        console.log(`Fetching FAQ from Notion... (Featured: ${featured})`);

        const andFilters = [
            {
                property: "Publicado",
                checkbox: {
                    equals: true,
                },
            }
        ];

        if (featured === 'true') {
            andFilters.push({
                property: "Destaque",
                checkbox: {
                    equals: true,
                },
            });
        }

        // 1. Query Database
        const response = await notion.databases.query({
            database_id: NOTION_DATABASE_ID,
            filter: {
                and: andFilters
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

const FEEDBACK_WEBHOOK_URL = process.env.FEEDBACK_WEBHOOK_URL || "https://n8n.studiomlk.com.br/webhook/sincroapp-feedback";

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

        const queryFilter = {
            property: "Planos",
            checkbox: { equals: true },
        };
        // console.log("DEBUG: Querying Notion with Filter:", JSON.stringify(queryFilter, null, 2));

        const response = await notion.databases.query({
            database_id: PLANS_DATABASE_ID,
            filter: queryFilter,
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
        const { context } = req.query;
        console.log(`Fetching Features from Notion... Context: ${context || 'default(landing)'}`);

        // Determine which checkbox property to filter by based on context
        let filterProperty = "Landing Page";
        if (context === 'blog') {
            filterProperty = "Blog";
        }

        const response = await notion.databases.query({
            database_id: FEATURES_DATABASE_ID,
            filter: {
                property: filterProperty,
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
            imgMobile: page.properties['Imagem Mobile']?.files[0]?.file?.url || page.properties['Imagem Mobile']?.files[0]?.external?.url || page.properties['Imagem']?.files[0]?.file?.url || page.properties['Imagem']?.files[0]?.external?.url || "https://picsum.photos/seed/sincro/350/800",
            imgDesktop: page.properties['Imagem Desktop']?.files[0]?.file?.url || page.properties['Imagem Desktop']?.files[0]?.external?.url || page.properties['Imagem']?.files[0]?.file?.url || page.properties['Imagem']?.files[0]?.external?.url || "https://picsum.photos/seed/sincro/1200/800",
            plans: page.properties['Plano']?.multi_select?.map(tag => tag.name) || [],
        }));

        console.log("Loaded Features:", features.length);
        if (features.length > 0) {
            console.log("DEBUG: Available Notion Properties:", Object.keys(response.results[0].properties));
        }

        res.json({ features });

    } catch (error) {
        console.error("Notion Features API Error:", error);
        res.status(500).json({ error: "Failed to fetch features", details: error.message });
    }
});

// Helper: Recursively fetch block children (for nested Notion content)
const fetchBlockChildren = async (blockId, depth = 0) => {
    const blocks = [];
    let cursor;
    while (true) {
        const { results, next_cursor } = await notion.blocks.children.list({
            block_id: blockId,
            start_cursor: cursor,
        });
        blocks.push(...results);
        if (!next_cursor) break;
        cursor = next_cursor;
    }

    // Recursively fetch nested children for blocks that have them
    for (const block of blocks) {
        if (block.has_children) {
            console.log(`[NOTION] Block ${block.type} has children, fetching...`);
            block.children = await fetchBlockChildren(block.id, depth + 1);
        }
    }
    return blocks;
};

// API Route: Get Single Feature with full content
app.get('/api/features/:id', async (req, res) => {
    try {
        const { id } = req.params;
        console.log(`Fetching Feature ${id} from Notion (with children)...`);

        // Get page properties
        const page = await notion.pages.retrieve({ page_id: id });

        // Get page content blocks RECURSIVELY to capture nested content
        const blocks = await fetchBlockChildren(id);
        const contentHtml = notionToHtml(blocks);

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

// API Route: Get About Page Data
app.get('/api/about', async (req, res) => {
    try {
        const ABOUT_DATABASE_ID = process.env.NOTION_ABOUT_DATABASE_ID;
        console.log("Fetching About Page data from Notion...", ABOUT_DATABASE_ID);

        const response = await notion.databases.query({
            database_id: ABOUT_DATABASE_ID,
            filter: {
                property: "Publicar",
                checkbox: { equals: true },
            },
            sorts: [
                { timestamp: "created_time", direction: "ascending" }
            ],
        });

        const sections = {
            sincroApp: [],
            team: []
        };

        for (const page of response.results) {
            const title = page.properties['Título']?.title[0]?.plain_text || "Sem título";
            const sectionTag = page.properties['Seção']?.select?.name || "Geral";
            const imageUrl = page.properties['Imagem']?.files[0]?.file?.url || page.properties['Imagem']?.files[0]?.external?.url || null;

            // Fetch blocks (content)
            const blocks = await notion.blocks.children.list({ block_id: page.id });
            const contentHtml = notionToHtml(blocks.results);

            const item = {
                id: page.id,
                title,
                content: contentHtml,
                image: imageUrl,
                section: sectionTag
            };

            if (sectionTag === 'SincroApp' || sectionTag === 'SincroApp 02') {
                sections.sincroApp.push(item);
            } else if (sectionTag === 'Idealizadores' || sectionTag === 'Equipe') {
                // Handle both new 'Idealizadores' and fallback 'Equipe'
                sections.team.push(item);
            } else {
                // Default fallback
                console.log(`[DEBUG] Uncategorized section tag: ${sectionTag}`);
                sections.team.push(item);
            }
        }

        res.json(sections);

    } catch (error) {
        console.error("Notion About API Error:", error);
        res.status(500).json({ error: "Failed to fetch about data", details: error.message });
    }
});

const N8N_PASSWORD_RESET_WEBHOOK = process.env.N8N_PASSWORD_RESET_WEBHOOK || "https://n8n.studiomlk.com.br/webhook/sincroapp-password-reset";
const N8N_TRANSACTION_WEBHOOK = process.env.N8N_TRANSACTION_WEBHOOK || "https://n8n.webhook.sincroapp.com.br/webhook/stripe-events";

// --- STRIPE CUSTOMER PORTAL ---
app.post('/api/stripe/portal-session', async (req, res) => {
    const { userId, returnUrl } = req.body;
    if (!userId) return res.status(400).json({ error: 'User ID required' });

    try {
        // 1. Get Customer ID from Supabase
        if (!supabase) throw new Error("Supabase client not initialized");

        const { data: userData, error } = await supabase
            .from('users')
            .select('stripe_id') // Ensure your table has stripe_id
            .eq('user_id', userId)
            .single();

        if (error || !userData?.stripe_id) {
            console.error("User not found or no stripe_id:", error);
            return res.status(404).json({ error: 'Stripe Customer not found for this user. Please subscribe first.' });
        }

        // 2. Create Portal Session
        const portalConfig = process.env.STRIPE_PORTAL_CONFIG_ID;
        const sessionParams = {
            customer: userData.stripe_id,
            return_url: returnUrl || 'https://sincroapp.com.br',
        };

        if (portalConfig) {
            sessionParams.configuration = portalConfig;
        }

        const session = await stripe.billingPortal.sessions.create(sessionParams);

        res.json({ url: session.url });
    } catch (e) {
        console.error("Portal Session Error:", e.message);
        res.status(500).json({ error: 'Failed to create portal session: ' + e.message });
    }
});

// --- STRIPE WEBHOOK ---

app.post('/api/webhooks/stripe', async (req, res) => {
    const sig = req.headers['stripe-signature'];
    const endpointSecret = process.env.STRIPE_WEBHOOK_SECRET;

    let event;

    try {
        event = stripe.webhooks.constructEvent(req.body, sig, endpointSecret);
    } catch (err) {
        console.error(`Webhook Error: ${err.message}`);
        return res.status(400).send(`Webhook Error: ${err.message}`);
    }

    // Handle the event
    try {
        const dataObject = event.data.object;

        switch (event.type) {
            case "checkout.session.completed": {
                const session = dataObject;
                const userId = session.client_reference_id;
                const customerId = session.customer;

                if (userId && supabase) {
                    console.log(`Checkout complete for ${userId}. Updating stripe_id: ${customerId}`);
                    // Note: Update logic might vary depending on table structure (profiles vs users)
                    // Assuming 'profiles' table or similar where user_id is PK
                    await supabase.from('users').update({ stripe_id: customerId }).eq('user_id', userId);
                }
                break;
            }
            case "invoice.payment_succeeded": {
                const customerId = dataObject.customer;
                const amount = dataObject.amount_paid / 100;
                const currency = dataObject.currency;

                if (supabase) {
                    const { data: userData } = await supabase.from('users').select('*').eq('stripe_id', customerId).single();
                    if (userData) {
                        // Update subscription JSONB
                        const currentSub = userData.subscription || {};
                        const newSub = { ...currentSub, status: 'active', lastPayment: new Date().toISOString() };

                        await supabase.from('users').update({
                            subscription: newSub
                        }).eq('user_id', userData.user_id);

                        // Send to N8N (Standardized)
                        await sendN8nEvent('invoice.payment_succeeded', {
                            event: 'subscription_activated', // Legacy field for compat
                            email: userData.email,
                            name: `${userData.first_name || ''} ${userData.last_name || ''}`.trim(),
                            userId: userData.user_id,
                            amount,
                            currency,
                            stripeCustomerId: customerId,
                            invoice_url: dataObject.hosted_invoice_url
                        });
                    }
                }
                break;
            }
            case "customer.subscription.deleted": {
                const customerId = dataObject.customer;
                if (supabase) {
                    const { data: userData } = await supabase.from('users').select('*').eq('stripe_id', customerId).single();
                    if (userData) {
                        const currentSub = userData.subscription || {};
                        const newSub = { ...currentSub, status: 'cancelled' };

                        await supabase.from('users').update({ subscription: newSub }).eq('user_id', userData.user_id);

                        await sendN8nEvent('customer.subscription.deleted', {
                            event: 'subscription_cancelled',
                            email: userData.email,
                            userId: userData.user_id,
                            stripeCustomerId: customerId
                        });
                    }
                }
                break;
            }
            case "customer.subscription.updated": {
                const subscription = dataObject;
                const customerId = subscription.customer;
                const status = subscription.status;
                const priceId = subscription.items.data[0].price.id;

                if (supabase) {
                    const { data: userData } = await supabase.from('users').select('*').eq('stripe_id', customerId).single();
                    if (userData) {
                        const currentSub = userData.subscription || {};
                        const newSub = {
                            ...currentSub,
                            status: status,
                            priceId: priceId,
                            updatedAt: new Date().toISOString()
                        };

                        await supabase.from('users').update({
                            subscription: newSub
                        }).eq('user_id', userData.user_id);

                        // Also notify N8N about updates
                        await sendN8nEvent('customer.subscription.updated', {
                            event: 'subscription_updated',
                            email: userData.email,
                            userId: userData.user_id,
                            status: status,
                            priceId: priceId
                        });
                    }
                }
                break;
            }
        }
    } catch (err) {
        console.error("Error processing webhook:", err);
    }

    res.json({ received: true });
});

// --- HELPER: Send Standardized Event to N8N ---
const https = require('https'); // Ensure this is imported or require it here

const sendN8nEvent = async (eventType, dataObject) => {
    // UPDATED: Use ENV variable as requested
    const webhookUrl = process.env.N8N_EVENT_HOST_WEBHOOK || "https://n8n.studiomlk.com.br/webhook/sincroapp-event-host";

    // Create an HTTPS agent that ignores SSL certificate errors
    const httpsAgent = new https.Agent({
        rejectUnauthorized: false
    });

    // Simple Event Structure (Requested by User)
    // The 'eventType' argument becomes the 'event' field
    const payload = {
        event: eventType,
        ...dataObject
    };

    try {
        console.log(`[N8N] Sending ${eventType} to ${webhookUrl}`);
        // Pass the httpsAgent to axios
        await axios.post(webhookUrl, payload, { httpsAgent });
        console.log(`[N8N] Success: ${eventType} sent.`);
    } catch (e) {
        console.error(`[N8N] Failed to send ${eventType}:`, e.message);
        if (e.response && e.response.data) {
            console.error('[N8N] Response Body:', JSON.stringify(e.response.data, null, 2));
        }
        if (e.code === 'CERT_HAS_EXPIRED' || e.code === 'DEPTH_ZERO_SELF_SIGNED_CERT') {
            console.error('[N8N] SSL Error detected. The `rejectUnauthorized: false` fix should have handled this. Check network connectivity.');
        }
    }
};

// --- PASSWORD RESET ---
app.post('/api/auth/reset-password', async (req, res) => {
    const { email } = req.body;
    if (!email) return res.status(400).json({ error: "Email required" });

    try {
        // 1. Generate Token
        const token = crypto.randomBytes(32).toString('hex');
        const expiresAt = new Date(Date.now() + 3600000); // 1 hour

        // 2. Save to Supabase (Requires password_resets table)
        if (supabase) {
            const { error } = await supabase.from('password_resets').insert({
                email,
                token,
                expires_at: expiresAt.toISOString()
            });
            if (error) {
                console.error("Supabase Error:", error);
                throw error;
            }
        }

        // 3. Send to N8N
        const baseUrl = process.env.APP_BASE_URL || "https://sincroapp.com.br";
        const link = `${baseUrl}/reset-password?token=${token}`;

        await sendN8nEvent('password_reset_requested', {
            email,
            link,
            token
        });

        res.json({ success: true });
    } catch (e) {
        console.error("Reset Password Error:", e);
        res.status(500).json({ error: "Failed to process request" });
    }
});

// --- USER SIGNUP NOTIFICATION WEBHOOK ---
app.post('/api/auth/signup-notify', async (req, res) => {
    const { userId, email, name } = req.body;
    console.log(`New user signup: ${email} (${userId})`);

    try {
        await sendN8nEvent('user_created', {
            userId: userId, // Requested format uses userId
            email,
            name,
            plan: 'gratuito' // Added default plan as in example
        });
    } catch (e) {
        // Do not fail
    }

    res.json({ success: true });
});

// --- USER DELETION CLEANUP WEBHOOK (TRIGGER) ---
app.post('/api/auth/delete-user', async (req, res) => {
    const { userId, email } = req.body;
    console.log(`User deletion requested for ${userId}`);

    try {
        await sendN8nEvent('user_deleted', {
            userId,
            email
        });
    } catch (e) { }

    res.json({ success: true });
});

// --- REMINDER SCHEDULER ---
const checkReminders = async () => {
    if (!supabase) return;

    try {
        const now = new Date().toISOString();
        // Check for reminders due in the last hour that haven't been sent
        // (Avoid sending reminders for very old tasks if server was down)
        const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000).toISOString();

        const { data: tasks, error } = await supabase
            .from('tasks')
            .select('*')
            .lte('reminder_at', now)
            .gt('reminder_at', oneHourAgo)
            .is('reminder_sent', false) // Use .is for null/false check if needed, or .eq
            .eq('completed', false);

        if (error) {
            console.error('[REMINDER] Error fetching due tasks:', error.message);
            return;
        }

        if (tasks && tasks.length > 0) {
            console.log(`[REMINDER] Found ${tasks.length} due reminders.`);

            for (const task of tasks) {
                // Fetch user logic (safer than join if FK not strict)
                const { data: user } = await supabase
                    .from('users')
                    .select('email, first_name, uid')
                    .eq('uid', task.user_id)
                    .single();

                if (user) {
                    // Send to N8N
                    await sendN8nEvent('task_reminder', {
                        email: user.email,
                        name: user.first_name,
                        userId: user.uid,
                        taskText: task.text,
                        taskId: task.id,
                        journeyTitle: task.journey_title,
                        reminderAt: task.reminder_at
                    });

                    // Mark as sent
                    await supabase
                        .from('tasks')
                        .update({ reminder_sent: true })
                        .eq('id', task.id);

                    console.log(`[REMINDER] Sent for task: ${task.id}`);
                }
            }
        }
    } catch (e) {
        console.error('[REMINDER] Unexpected error:', e);
    }
};

// Start Polling (every 60 seconds)
setInterval(checkReminders, 60000);
console.log('[SERVER] Reminder polling started (60s interval).');

// --- APP VERSION & CHANGELOG ---
app.get('/api/version', async (req, res) => {
    try {
        const fs = require('fs');

        // 1. Read Package.json for version
        const packageJsonPath = path.resolve(__dirname, '../package.json');

        if (!fs.existsSync(packageJsonPath)) {
            console.error('[VERSION] package.json not found at:', packageJsonPath);
            return res.status(404).json({ error: "package.json not found" });
        }

        const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
        const version = packageJson.version;

        // 2. Read Changelog for latest notes
        const changelogPath = path.resolve(__dirname, '../CHANGELOG.md');
        let latestNotes = '';

        if (fs.existsSync(changelogPath)) {
            const changelogContent = fs.readFileSync(changelogPath, 'utf8');

            // Try to find the section for the current version
            // Matches "## [1.1.0]" or "### [1.1.0]"
            const versionHeaderRegex = new RegExp(`##\\s+\\[?${version.replace(/\./g, '\\.')}\\]?|###\\s+\\[?${version.replace(/\./g, '\\.')}\\]?`);
            const matchIndex = changelogContent.search(versionHeaderRegex);

            if (matchIndex !== -1) {
                // Found current version header
                // Extract until next version header
                const contentFromVersion = changelogContent.substring(matchIndex);
                const lines = contentFromVersion.split('\n');

                // Keep lines until next check
                const extractedLines = [];
                // Add header (first line)
                extractedLines.push(lines[0]);

                for (let i = 1; i < lines.length; i++) {
                    const line = lines[i];
                    // Stop if line is another header (## [ or ### [)
                    if (line.match(/^##\s+\[/) || (line.match(/^###\s+\[/) && !line.includes(version))) {
                        break;
                    }
                    extractedLines.push(line);
                }
                latestNotes = extractedLines.join('\n').trim();
            } else {
                // If version specific notes not found, maybe show generic or first n lines?
                // For now, simple fallback
                latestNotes = `Versão ${version} lançada! Detalhes em breve.`;
            }
        } else {
            console.warn('[VERSION] CHANGELOG.md not found at:', changelogPath);
            latestNotes = "Notas de lançamento indisponíveis no momento.";
        }

        res.json({
            version: version,
            notes: latestNotes
        });

    } catch (error) {
        console.error("Version API Error:", error);
        res.status(500).json({ error: "Failed to fetch version info" });
    }
});

app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});
