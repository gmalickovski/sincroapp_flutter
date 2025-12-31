
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const FEEDBACK_WEBHOOK_URL = "https://n8n.studiomlk.com.br/webhook/sincroapp-feedback";

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const feedbackData = await req.json()

        // Optionally: validate user auth here using Supabase Auth context if needed
        // const authHeader = req.headers.get('Authorization')
        // ...

        console.log("Forwarding feedback to n8n:", JSON.stringify(feedbackData));

        const response = await fetch(FEEDBACK_WEBHOOK_URL, {
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
    } catch (error) {
        return new Response(JSON.stringify({ error: error.message }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 500,
        })
    }
})
