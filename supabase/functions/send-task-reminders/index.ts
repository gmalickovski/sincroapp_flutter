// supabase/functions/send-task-reminders/index.ts
// Edge Function: Processes due task reminders and sends FCM push notifications
// Called by pg_cron every minute

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

// Firebase Auth: Get OAuth2 access token from service account
async function getFirebaseAccessToken(): Promise<string> {
    const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
    if (!serviceAccountJson) throw new Error('FIREBASE_SERVICE_ACCOUNT not set')

    const sa = JSON.parse(serviceAccountJson)

    // Create JWT for Google OAuth2
    const header = { alg: 'RS256', typ: 'JWT' }
    const now = Math.floor(Date.now() / 1000)
    const payload = {
        iss: sa.client_email,
        scope: 'https://www.googleapis.com/auth/firebase.messaging',
        aud: 'https://oauth2.googleapis.com/token',
        iat: now,
        exp: now + 3600,
    }

    // Base64url encode
    const enc = (obj: unknown) =>
        btoa(JSON.stringify(obj)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')

    const unsignedToken = `${enc(header)}.${enc(payload)}`

    // Import private key and sign
    const pemBody = sa.private_key
        .replace(/-----BEGIN PRIVATE KEY-----/, '')
        .replace(/-----END PRIVATE KEY-----/, '')
        .replace(/\s/g, '')

    const binaryKey = Uint8Array.from(atob(pemBody), (c: string) => c.charCodeAt(0))

    const cryptoKey = await crypto.subtle.importKey(
        'pkcs8',
        binaryKey,
        { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
        false,
        ['sign']
    )

    const signatureBuffer = await crypto.subtle.sign(
        'RSASSA-PKCS1-v1_5',
        cryptoKey,
        new TextEncoder().encode(unsignedToken)
    )

    const signature = btoa(String.fromCharCode(...new Uint8Array(signatureBuffer)))
        .replace(/\+/g, '-')
        .replace(/\//g, '_')
        .replace(/=+$/, '')

    const jwt = `${unsignedToken}.${signature}`

    // Exchange JWT for access token
    const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
    })

    const tokenData = await tokenResponse.json()
    if (!tokenData.access_token) {
        throw new Error(`Failed to get Firebase access token: ${JSON.stringify(tokenData)}`)
    }

    return tokenData.access_token
}

// Send FCM push using HTTP v1 API
async function sendFCMPush(
    accessToken: string,
    projectId: string,
    token: string,
    title: string,
    body: string,
    data: Record<string, string> = {}
): Promise<boolean> {
    try {
        const response = await fetch(
            `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
            {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${accessToken}`,
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    message: {
                        token,
                        notification: { title, body },
                        data,
                        android: {
                            priority: 'high',
                            notification: {
                                channel_id: 'sincroapp_reminders',
                                sound: 'default',
                            }
                        },
                        apns: {
                            payload: {
                                aps: {
                                    sound: 'default',
                                    badge: 1,
                                }
                            }
                        }
                    }
                }),
            }
        )

        if (!response.ok) {
            const errBody = await response.text()
            console.error(`FCM send failed for token ${token.substring(0, 20)}...: ${errBody}`)
            return false
        }

        return true
    } catch (err) {
        console.error(`FCM send error: ${err.message}`)
        return false
    }
}

// Format minutes as human-readable text
function formatMinutes(minutes: number): string {
    if (minutes === 0) return 'agora'
    if (minutes < 60) return `${minutes} min`
    const hours = Math.floor(minutes / 60)
    const mins = minutes % 60
    if (mins === 0) return `${hours}h`
    return `${hours}h ${mins}min`
}

serve(async (req: Request) => {
    try {
        const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
        const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        const FIREBASE_PROJECT_ID = Deno.env.get('FIREBASE_PROJECT_ID') ?? ''

        const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
        const db = supabase.schema('sincroapp')

        // 1. Get pending reminders (fire_at <= now and not sent)
        const { data: reminders, error } = await db
            .from('task_reminders')
            .select(`
                id,
                task_id,
                user_id,
                offset_minutes,
                fire_at
            `)
            .eq('sent', false)
            .lte('fire_at', new Date().toISOString())
            .order('fire_at', { ascending: true })
            .limit(100)

        if (error) {
            console.error('Error fetching reminders:', error.message)
            return new Response(JSON.stringify({ error: error.message }), { status: 500 })
        }

        if (!reminders || reminders.length === 0) {
            return new Response(JSON.stringify({ processed: 0 }), {
                headers: { 'Content-Type': 'application/json' }
            })
        }

        console.log(`[REMINDERS] Processing ${reminders.length} pending reminders`)

        // 2. Get Firebase access token (one for all requests in this batch)
        const accessToken = await getFirebaseAccessToken()

        let successCount = 0
        let failCount = 0

        // 3. Group reminders by user to batch token lookups
        const userIds = [...new Set(reminders.map((r: { user_id: string }) => r.user_id))]

        // Fetch all tokens for involved users
        const { data: allTokens } = await db
            .from('user_push_tokens')
            .select('user_id, fcm_token')
            .in('user_id', userIds)

        const tokensByUser: Record<string, string[]> = {}
        for (const t of (allTokens || [])) {
            if (!tokensByUser[t.user_id]) tokensByUser[t.user_id] = []
            tokensByUser[t.user_id].push(t.fcm_token)
        }

        // Fetch task details for text
        const taskIds = [...new Set(reminders.map((r: { task_id: string }) => r.task_id))]
        const { data: tasks } = await db
            .from('tasks')
            .select('id, text, journey_title')
            .in('id', taskIds)

        const tasksMap: Record<string, { text: string; journey_title?: string }> = {}
        for (const t of (tasks || [])) {
            tasksMap[t.id] = { text: t.text, journey_title: t.journey_title }
        }

        // 4. Process each reminder
        const sentIds: string[] = []

        for (const reminder of reminders) {
            const tokens = tokensByUser[reminder.user_id] || []
            const task = tasksMap[reminder.task_id]
            const taskText = task?.text || 'Tarefa'

            if (tokens.length === 0) {
                console.log(`[REMINDERS] User ${reminder.user_id} has no FCM tokens, skipping`)
                // Still mark as sent to avoid retrying endlessly
                sentIds.push(reminder.id)
                continue
            }

            // Build notification content
            let title: string, body: string
            if (reminder.offset_minutes === 0) {
                title = '⏰ Hora do agendamento!'
                body = `"${taskText}" — é agora!`
            } else {
                title = `🔔 Lembrete: ${formatMinutes(reminder.offset_minutes)} antes`
                body = `"${taskText}" começa em ${formatMinutes(reminder.offset_minutes)}.`
            }

            if (task?.journey_title) {
                body += ` (${task.journey_title})`
            }

            // Send to all user tokens
            let anySent = false
            for (const token of tokens) {
                const ok = await sendFCMPush(accessToken, FIREBASE_PROJECT_ID, token, title, body, {
                    action: 'VIEW_TASK',
                    taskId: reminder.task_id,
                    type: 'TASK_REMINDER',
                })
                if (ok) anySent = true
            }

            sentIds.push(reminder.id)
            if (anySent) successCount++
            else failCount++
        }

        // 5. Mark all processed reminders as sent
        if (sentIds.length > 0) {
            const { error: updateError } = await db
                .from('task_reminders')
                .update({ sent: true, sent_at: new Date().toISOString() })
                .in('id', sentIds)

            if (updateError) {
                console.error('Error marking reminders as sent:', updateError.message)
            }
        }

        console.log(`[REMINDERS] Done: ${successCount} sent, ${failCount} failed, ${sentIds.length} processed`)

        return new Response(
            JSON.stringify({ processed: sentIds.length, success: successCount, failed: failCount }),
            { headers: { 'Content-Type': 'application/json' } }
        )
    } catch (err) {
        console.error('[REMINDERS] Fatal error:', err)
        return new Response(JSON.stringify({ error: err.message }), { status: 500 })
    }
})
