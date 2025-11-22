// construction_check.js
// Checks if site is in construction mode and redirects if necessary

(async function () {
    // Skip check if we're already on the construction page
    if (window.location.pathname.includes('under_construction.html')) {
        return;
    }

    try {
        // Check for bypass token
        const bypassToken = sessionStorage.getItem('sincro_bypass_token');
        const bypassExpiry = sessionStorage.getItem('sincro_bypass_expiry');

        if (bypassToken && bypassExpiry) {
            const now = Date.now();
            if (now < parseInt(bypassExpiry)) {
                // Bypass is still valid
                console.log('✅ Bypass token valid - showing landing page');
                return;
            } else {
                // Bypass expired
                sessionStorage.removeItem('sincro_bypass_token');
                sessionStorage.removeItem('sincro_bypass_expiry');
            }
        }

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
            const isUnderConstruction = data.underConstructionEnabled || false;

            if (isUnderConstruction) {
                console.log('🚧 Site is under construction - redirecting...');
                window.location.href = '/under_construction.html';
            } else {
                console.log('✅ Site is live - showing landing page');
            }
        } else {
            // Document doesn't exist - assume site is live
            console.log('⚠️ Site settings not found - showing landing page');
        }
    } catch (error) {
        console.error('❌ Error checking construction status:', error);
        // On error, show landing page (fail-safe)
    }
})();
