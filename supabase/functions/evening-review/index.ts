// supabase/functions/evening-review/index.ts
// Edge Function: Sends evening review push to users with pending tasks (20:00)
// Called by pg_cron daily

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

async function getFirebaseAccessToken(): Promise<string> {
    const sa = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT') ?? '{}')
    const header = { alg: 'RS256', typ: 'JWT' }
    const now = Math.floor(Date.now() / 1000)
    const payload = {
        iss: sa.client_email,
        scope: 'https://www.googleapis.com/auth/firebase.messaging',
        aud: 'https://oauth2.googleapis.com/token',
        iat: now, exp: now + 3600,
    }
    const enc = (obj: unknown) =>
        btoa(JSON.stringify(obj)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
    const unsigned = `${enc(header)}.${enc(payload)}`
    const pemBody = sa.private_key.replace(/-----BEGIN PRIVATE KEY-----/, '')
        .replace(/-----END PRIVATE KEY-----/, '').replace(/\s/g, '')
    const binaryKey = Uint8Array.from(atob(pemBody), (c: string) => c.charCodeAt(0))
    const cryptoKey = await crypto.subtle.importKey('pkcs8', binaryKey,
        { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign'])
    const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', cryptoKey,
        new TextEncoder().encode(unsigned))
    const signature = btoa(String.fromCharCode(...new Uint8Array(sig)))
        .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
    const jwt = `${unsigned}.${signature}`
    const resp = await fetch('https://oauth2.googleapis.com/token', {
        method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
    })
    const data = await resp.json()
    if (!data.access_token) throw new Error(`Firebase auth failed: ${JSON.stringify(data)}`)
    return data.access_token
}

serve(async (_req: Request) => {
    try {
        const supabase = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )
        const db = supabase.schema('sincroapp')
        const FIREBASE_PROJECT_ID = Deno.env.get('FIREBASE_PROJECT_ID') ?? ''

        // Get today's date range (UTC)
        const now = new Date()
        const startOfDay = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()))
        const endOfDay = new Date(startOfDay.getTime() + 24 * 60 * 60 * 1000)

        // Find users with pending tasks today
        const { data: pendingTasks, error } = await db
            .from('tasks')
            .select('user_id')
            .eq('completed', false)
            .gte('due_date', startOfDay.toISOString())
            .lt('due_date', endOfDay.toISOString())

        if (error || !pendingTasks || pendingTasks.length === 0) {
            return new Response(JSON.stringify({ sent: 0 }), {
                headers: { 'Content-Type': 'application/json' }
            })
        }

        // Count tasks per user
        const taskCounts: Record<string, number> = {}
        for (const t of pendingTasks) {
            taskCounts[t.user_id] = (taskCounts[t.user_id] || 0) + 1
        }

        const userIds = Object.keys(taskCounts)

        // Get FCM tokens for these users
        const { data: tokens } = await db
            .from('user_push_tokens')
            .select('user_id, fcm_token')
            .in('user_id', userIds)

        if (!tokens || tokens.length === 0) {
            return new Response(JSON.stringify({ sent: 0 }), {
                headers: { 'Content-Type': 'application/json' }
            })
        }

        const accessToken = await getFirebaseAccessToken()
        let sentCount = 0

        // Group tokens by user
        const tokensByUser: Record<string, string[]> = {}
        for (const t of tokens) {
            if (!tokensByUser[t.user_id]) tokensByUser[t.user_id] = []
            tokensByUser[t.user_id].push(t.fcm_token)
        }

        for (const [userId, userTokens] of Object.entries(tokensByUser)) {
            const count = taskCounts[userId] || 0
            if (count === 0) continue

            const body = `Você tem ${count} tarefa${count > 1 ? 's' : ''} pendente${count > 1 ? 's' : ''} para hoje. Que tal revisá-la${count > 1 ? 's' : ''}?`

            for (const token of userTokens) {
                try {
                    await fetch(
                        `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`,
                        {
                            method: 'POST',
                            headers: {
                                'Authorization': `Bearer ${accessToken}`,
                                'Content-Type': 'application/json',
                            },
                            body: JSON.stringify({
                                message: {
                                    token,
                                    notification: {
                                        title: 'Fim de dia 🌙',
                                        body,
                                    },
                                    data: { action: 'VIEW_TASKS' },
                                    android: { priority: 'normal' },
                                }
                            }),
                        }
                    )
                    sentCount++
                } catch (err) {
                    console.error(`Evening push failed: ${err.message}`)
                }
            }
        }

        console.log(`[EVENING] Sent to ${sentCount} tokens, ${Object.keys(tokensByUser).length} users with pending tasks`)

        return new Response(
            JSON.stringify({ sent: sentCount, usersWithTasks: userIds.length }),
            { headers: { 'Content-Type': 'application/json' } }
        )
    } catch (err) {
        console.error('[EVENING] Fatal:', err)
        return new Response(JSON.stringify({ error: err.message }), { status: 500 })
    }
})
