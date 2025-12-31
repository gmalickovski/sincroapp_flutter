
// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { Client } from "https://deno.land/x/notion_sdk@v2.2.3/src/mod.ts"

// Initialize Notion Client with Env Var
const notion = new Client({ auth: Deno.env.get('NOTION_API_KEY') });

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
    // Handle CORS preflight requests
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const url = new URL(req.url);
        const path = url.pathname.split('/').pop(); // "faq", "plans", "features", "about" etc if routed via /notion-proxy/faq

        // Router Logic
        // Usage: https://project.functions.supabase.co/notion-proxy?type=faq
        const type = url.searchParams.get('type');

        // Config IDs from Env
        const NOTION_DATABASE_ID = Deno.env.get('NOTION_FAQ_DATABASE_ID');
        const PLANS_DATABASE_ID = Deno.env.get('PLANS_DATABASE_ID') || Deno.env.get('NOTION_PLANS_DATABASE_ID');
        const ABOUT_DATABASE_ID = Deno.env.get('NOTION_ABOUT_DATABASE_ID');

        let responseData = {};

        switch (type) {
            case 'faq':
                responseData = await getFaq(url.searchParams.get('featured'), NOTION_DATABASE_ID);
                break;
            case 'plans':
                responseData = await getPlans(PLANS_DATABASE_ID);
                break;
            case 'features':
                // If ID is provided, fetch single feature
                const featureId = url.searchParams.get('id');
                if (featureId) {
                    responseData = await getFeatureDetail(featureId);
                } else {
                    responseData = await getFeaturesList(PLANS_DATABASE_ID);
                }
                break;
            case 'about':
                responseData = await getAbout(ABOUT_DATABASE_ID);
                break;
            default:
                throw new Error(`Invalid type parameter: ${type}`);
        }

        return new Response(JSON.stringify(responseData), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200,
        })

    } catch (error) {
        return new Response(JSON.stringify({ error: error.message }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 400,
        })
    }
})

// --- HELPER FUNCTIONS (Migrated from Server/index.js) ---

const richText = (textArray) => {
    if (!textArray) return '';
    return textArray.map(t => {
        let content = t.plain_text
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;");
        // Simplified for brevity in this artifact, but logic is same
        return content;
    }).join("");
};

// Simplified HTML converter for MVP - can extract full logic if needed
const notionToHtml = (blocks) => {
    // Basic implementation for MVP
    let html = "";
    for (const block of blocks) {
        if (block.type === 'paragraph') html += `<p>${richText(block.paragraph.rich_text)}</p>`;
        // Add more types as needed
    }
    return html;
};


async function getFaq(featured, dbId) {
    const andFilters = [{ property: "Publicado", checkbox: { equals: true } }];
    if (featured === 'true') andFilters.push({ property: "Destaque", checkbox: { equals: true } });

    const response = await notion.databases.query({
        database_id: dbId,
        filter: { and: andFilters },
        sorts: [{ timestamp: "created_time", direction: "ascending" }],
    });

    const items = [];
    for (const page of response.results) {
        const question = page.properties.Pergunta?.title[0]?.plain_text || "Sem título";
        const category = page.properties['Tópico']?.select?.name || "Geral";
        // Fetch content
        const blocks = await notion.blocks.children.list({ block_id: page.id });
        // const answer = notionToHtml(blocks.results); 
        // Note: Full HTML conversion logic should be included or simplified
        // Returning raw blocks might be better for Flutter rendering, but preserving API contract:
        items.push({ question, category, answer: "HTML Content Warning: Need full parser" });
    }
    return { faq: items };
}

async function getPlans(dbId) {
    const response = await notion.databases.query({
        database_id: dbId,
        filter: { property: "Planos", checkbox: { equals: true } },
        sorts: [{ property: "Funcionalidade", direction: "ascending" }],
    });

    const cards = { free: [], plus: [], premium: [] };
    const comparison = [];

    response.results.forEach(page => {
        const name = page.properties['Funcionalidade']?.title[0]?.plain_text || "Sem nome";
        const planTags = page.properties['Plano']?.multi_select?.map(tag => tag.name) || [];

        comparison.push({ name, tags: planTags });

        if (planTags.includes('Essencial')) cards.free.push(name);
        else if (planTags.includes('Desperta')) cards.plus.push(name);
        else if (planTags.includes('Sinergia')) cards.premium.push(name);
    });

    return { cards, comparison };
}

async function getFeaturesList(dbId) {
    const response = await notion.databases.query({
        database_id: dbId,
        filter: { property: "Landing Page", checkbox: { equals: true } },
        sorts: [{ property: "Data de Edição", direction: "descending" }],
    });

    const features = response.results.map(page => ({
        id: page.id,
        name: page.properties['Funcionalidade']?.title[0]?.plain_text || "Sem nome",
        // Additional Mappings...
    }));
    return { features };
}

async function getFeatureDetail(id) {
    // ... Implementation similar to server/index.js
    return { feature: { id } }; // Stub
}

async function getAbout(dbId) {
    // ... Implementation similar to server/index.js
    return {}; // Stub
}
