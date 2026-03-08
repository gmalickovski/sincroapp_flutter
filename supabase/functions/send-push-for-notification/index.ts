// supabase/functions/send-push-for-notification/index.ts
// Edge Function: Sends FCM push notification when a new notification is inserted
// Called by PostgreSQL trigger via pg_net

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

// Map notification type to FCM data action
function getActionForType(type: string): string {
    switch (type) {
        case 'task_invite': return 'VIEW_NOTIFICATION'
        case 'contact_request': return 'VIEW_NOTIFICATION'
        case 'contact_accepted': return 'VIEW_NOTIFICATION'
        case 'task_update': return 'VIEW_TASK'
        case 'sincro_alert': return 'VIEW_NOTIFICATION'
        case 'share': return 'VIEW_NOTIFICATION'
        case 'reminder': return 'VIEW_TASK'
        default: return 'VIEW_NOTIFICATION'
    }
}

serve(async (req: Request) => {
    try {
        const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
        const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        const FIREBASE_PROJECT_ID = Deno.env.get('FIREBASE_PROJECT_ID') ?? ''

        const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
        const db = supabase.schema('sincroapp')

        // Parse the notification data from request body
        const body = await req.json()
        const notificationId = body.notification_id

        if (!notificationId) {
            return new Response(JSON.stringify({ error: 'missing notification_id' }), { status: 400 })
        }

        // 1. Fetch the notification
        const { data: notification, error: notifError } = await db
            .from('notifications')
            .select('id, user_id, type, title, body, related_item_id, metadata')
            .eq('id', notificationId)
            .maybeSingle()

        if (notifError || !notification) {
            console.error('[PUSH] Notification not found:', notificationId)
            return new Response(JSON.stringify({ error: 'notification not found' }), { status: 404 })
        }

        // 2. Skip reminder type (already handled by send-task-reminders)
        if (notification.type === 'reminder') {
            return new Response(JSON.stringify({ skipped: true, reason: 'reminder handled separately' }))
        }

        // 3. Get FCM tokens for this user
        const { data: tokens, error: tokenError } = await db
            .from('user_push_tokens')
            .select('fcm_token')
            .eq('user_id', notification.user_id)

        if (tokenError || !tokens || tokens.length === 0) {
            console.log(`[PUSH] No FCM tokens for user ${notification.user_id}`)
            return new Response(JSON.stringify({ sent: 0, reason: 'no tokens' }))
        }

        // 4. Get Firebase access token and send push
        const accessToken = await getFirebaseAccessToken()
        const action = getActionForType(notification.type)
        let sentCount = 0

        for (const t of tokens) {
            try {
                const response = await fetch(
                    `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`,
                    {
                        method: 'POST',
                        headers: {
                            'Authorization': `Bearer ${accessToken}`,
                            'Content-Type': 'application/json',
                        },
                        body: JSON.stringify({
                            message: {
                                token: t.fcm_token,
                                notification: {
                                    title: notification.title,
                                    body: notification.body,
                                },
                                data: {
                                    action,
                                    type: notification.type,
                                    notificationId: notification.id,
                                    relatedItemId: notification.related_item_id ?? '',
                                },
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

                if (response.ok) {
                    sentCount++
                } else {
                    const errBody = await response.text()
                    console.error(`[PUSH] FCM send failed: ${errBody}`)
                }
            } catch (err) {
                console.error(`[PUSH] FCM error: ${err.message}`)
            }
        }

        console.log(`[PUSH] Notification ${notification.type}: sent to ${sentCount}/${tokens.length} tokens for user ${notification.user_id}`)

        return new Response(
            JSON.stringify({ sent: sentCount, type: notification.type }),
            { headers: { 'Content-Type': 'application/json' } }
        )
    } catch (err) {
        console.error('[PUSH] Fatal error:', err)
        return new Response(JSON.stringify({ error: err.message }), { status: 500 })
    }
})
