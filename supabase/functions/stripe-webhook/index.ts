// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import Stripe from "https://esm.sh/stripe@13.10.0"

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') ?? '', {
    apiVersion: '2023-10-16',
    httpClient: Stripe.createFetchHttpClient(),
})

const cryptoProvider = Stripe.createSubtleCryptoProvider()

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
const N8N_TRANSACTION_WEBHOOK = Deno.env.get('N8N_TRANSACTION_WEBHOOK') ?? "https://n8n.studiomlk.com.br/webhook/sincroapp-transaction"

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

serve(async (req) => {
    const signature = req.headers.get('Stripe-Signature')

    // First step is to verify the event. The .text() method must be used as the
    // verification MUST be based on the raw request body, rather than parsed JSON.
    const body = await req.text()

    let receivedEvent
    try {
        receivedEvent = await stripe.webhooks.constructEventAsync(
            body,
            signature!,
            Deno.env.get('STRIPE_WEBHOOK_SECRET')!,
            undefined,
            cryptoProvider
        )
    } catch (err) {
        return new Response(err.message, { status: 400 })
    }

    const event = receivedEvent
    const dataObject = event.data.object

    try {
        switch (event.type) {
            case "checkout.session.completed": {
                const session = dataObject;
                const userId = session.client_reference_id;
                const customerId = session.customer;

                if (userId) {
                    console.log(`Checkout complete for ${userId}. Updating stripe_id: ${customerId}`);
                    // Update user in 'sincroapp.users' (or public.users/profiles depending on migration)
                    // Assuming 'sincroapp.users' based on previous context
                    await supabase
                        .schema('sincroapp')
                        .from('users')
                        .update({ stripe_id: customerId }) // Ensure this column exists in SQL
                        .eq('uid', userId);
                }
                break;
            }

            case "invoice.payment_succeeded": {
                const customerId = dataObject.customer;
                const amount = dataObject.amount_paid / 100;
                const currency = dataObject.currency;

                // Find user by Stripe ID
                const { data: userData, error } = await supabase
                    .schema('sincroapp')
                    .from('users')
                    .select('*')
                    .eq('stripe_id', customerId)
                    .single();

                if (userData) {
                    const currentSub = userData.subscription || {};
                    const newSub = {
                        ...currentSub,
                        status: 'active',
                        lastPayment: new Date().toISOString()
                    };

                    // Update Subscription
                    await supabase
                        .schema('sincroapp')
                        .from('users')
                        .update({ subscription: newSub })
                        .eq('uid', userData.uid);

                    // Notify N8N
                    await fetch(N8N_TRANSACTION_WEBHOOK, {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({
                            event: 'subscription_activated',
                            email: userData.email,
                            name: `${userData.first_name || ''} ${userData.last_name || ''}`.trim(),
                            userId: userData.uid,
                            amount,
                            currency,
                            stripeCustomerId: customerId
                        })
                    });
                }
                break;
            }

            case "customer.subscription.deleted": {
                const customerId = dataObject.customer;
                const { data: userData } = await supabase
                    .schema('sincroapp')
                    .from('users')
                    .select('*')
                    .eq('stripe_id', customerId)
                    .single();

                if (userData) {
                    const currentSub = userData.subscription || {};
                    const newSub = { ...currentSub, status: 'cancelled' };

                    await supabase
                        .schema('sincroapp')
                        .from('users')
                        .update({ subscription: newSub })
                        .eq('uid', userData.uid);

                    // Notify N8N (Optional, catch error inside logic if needed)
                    await fetch(N8N_TRANSACTION_WEBHOOK, {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({
                            event: 'subscription_cancelled',
                            email: userData.email,
                            userId: userData.uid
                        })
                    });
                }
                break;
            }

            case "customer.subscription.updated": {
                const subscription = dataObject;
                const customerId = subscription.customer;
                const status = subscription.status;
                // Accessing safely
                const priceId = subscription.items?.data?.[0]?.price?.id;

                const { data: userData } = await supabase
                    .schema('sincroapp')
                    .from('users')
                    .select('*')
                    .eq('stripe_id', customerId)
                    .single();

                if (userData) {
                    const currentSub = userData.subscription || {};
                    const newSub = {
                        ...currentSub,
                        status: status,
                        priceId: priceId,
                        updatedAt: new Date().toISOString()
                    };

                    await supabase
                        .schema('sincroapp')
                        .from('users')
                        .update({ subscription: newSub })
                        .eq('uid', userData.uid);
                }
                break;
            }
        }
    } catch (err) {
        console.error('Webhook processing failed:', err)
        return new Response(`Webhook Error: ${err.message}`, { status: 400 })
    }

    return new Response(JSON.stringify({ received: true }), {
        headers: { "Content-Type": "application/json" },
    })
})
