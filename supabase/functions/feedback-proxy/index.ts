import { serve } from "std/http/server.ts"

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
    // Handling CORS preflight requests
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const WEBHOOK_URL = Deno.env.get('FEEDBACK_WEBHOOK_URL');
        if (!WEBHOOK_URL) {
            throw new Error('Missing configuration: FEEDBACK_WEBHOOK_URL');
        }

        const feedbackData = await req.json()

        console.log("Forwarding feedback to n8n:", JSON.stringify(feedbackData));

        const response = await fetch(WEBHOOK_URL, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(feedbackData)
        });

        if (!response.ok) {
            throw new Error(`N8N responded with ${response.status}`);
        }

        return new Response(JSON.stringify({ success: true, n8n_status: response.status }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200,
        })
    } catch (error: any) {
        console.error("Feedback Proxy Error:", error);
        return new Response(JSON.stringify({ error: error.message || 'Internal Server Error' }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 500,
        })
    }
})
