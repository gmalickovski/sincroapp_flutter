// construction_check.js
// Checks if site is in construction/maintenance mode and redirects if necessary

(async function () {
    const currentPath = window.location.pathname;
    const isMaintenancePage = currentPath.includes('maintenance.html');
    const isConstructionPage = currentPath.includes('under_construction.html');

    // 0. Skip check on localhost/dev environment
    console.log('🔍 Hostname detected:', window.location.hostname);

    if (window.location.hostname.includes('localhost') || window.location.hostname.includes('127.0.0.1')) {
        console.log('🚧 Maintenance check skipped on localhost');
        // If we are currently ON the blockage page, send us back home
        if (isMaintenancePage || isConstructionPage) {
            window.location.href = '/';
        }
        return;
    }

    // 1. Check for bypass token
    const bypassToken = sessionStorage.getItem('sincro_bypass_token');
    const bypassExpiry = sessionStorage.getItem('sincro_bypass_expiry');

    if (bypassToken && bypassExpiry) {
        const now = Date.now();
        if (now < parseInt(bypassExpiry)) {
            // Bypass is valid
            console.log('✅ Bypass token valid - allowing access');
            // If we are on a restricted page but have access, go to home
            if (isMaintenancePage || isConstructionPage) {
                window.location.href = '/';
            }
            return;
        } else {
            // Bypass expired
            sessionStorage.removeItem('sincro_bypass_token');
            sessionStorage.removeItem('sincro_bypass_expiry');
        }
    }

    try {
        // Initialize Firebase if not already initialized
        if (!firebase.apps.length) {
            const firebaseConfig = {
                apiKey: "AIzaSyBLfDEbGCqBbWKlqfVvCRnGfBBZKJxWZnw",
                authDomain: "sincroapp-529cc.firebaseapp.com",
                projectId: "sincroapp-529cc",
                storageBucket: "sincroapp-529cc.firebasestorage.app",
                messagingSenderId: "1026698348026",
                appId: "1:1026698348026:web:0e7a7d3e4c9a0e0e8e0e0e"
            };
            firebase.initializeApp(firebaseConfig);
        }

        const db = firebase.firestore();

        // Fetch site settings
        const doc = await db.collection('config').doc('site_settings').get();

        if (doc.exists) {
            const data = doc.data();
            const status = data.status || 'active'; // active, maintenance, construction

            console.log(`🔍 Site Status: ${status}`);

            if (status === 'maintenance') {
                if (!isMaintenancePage) {
                    console.log('🛠️ Maintenance mode - redirecting...');
                    window.location.href = '/maintenance.html';
                }
            } else if (status === 'construction') {
                if (!isConstructionPage) {
                    console.log('🚧 Construction mode - redirecting...');
                    window.location.href = '/under_construction.html';
                }
            } else {
                // Status is active
                if (isMaintenancePage || isConstructionPage) {
                    console.log('✅ Site is live - redirecting to home...');
                    window.location.href = '/';
                }
            }
        } else {
            // Default to active if no settings found
            if (isMaintenancePage || isConstructionPage) {
                window.location.href = '/';
            }
        }
    } catch (error) {
        console.error('❌ Error checking site status:', error);
        // Fail-safe: If error, stay where we are (or go home if on restricted page?)
        // Better to do nothing to avoid loops in case of network error
    }
})();
