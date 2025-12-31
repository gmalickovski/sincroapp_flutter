
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import Stripe from "https://esm.sh/stripe@13.10.0"

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') ?? '', {
    apiVersion: '2023-10-16',
    httpClient: Stripe.createFetchHttpClient(),
})

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        // Get the user from the authorization header (JWT)
        const authHeader = req.headers.get('Authorization')
        if (!authHeader) throw new Error('Missing Authorization header')

        const token = authHeader.replace('Bearer ', '')
        const { data: { user }, error: userError } = await supabase.auth.getUser(token)

        if (userError || !user) throw new Error('Invalid User Token')

        const { returnUrl } = await req.json()

        // 1. Get Customer ID from Supabase 'users' table (sincroapp schema)
        const { data: userData, error: dbError } = await supabase
            .schema('sincroapp')
            .from('users')
            .select('stripe_id')
            .eq('uid', user.id)
            .single()

        if (dbError || !userData?.stripe_id) {
            throw new Error('Stripe Customer not found for this user. Please subscribe first.')
        }

        // 2. Create Portal Session
        const portalConfig = Deno.env.get('STRIPE_PORTAL_CONFIG_ID');
        const sessionParams = {
            customer: userData.stripe_id,
            return_url: returnUrl || 'https://sincroapp.com.br',
        };

        if (portalConfig) {
            sessionParams.configuration = portalConfig;
        }

        const session = await stripe.billingPortal.sessions.create(sessionParams);

        return new Response(JSON.stringify({ url: session.url }), {
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
