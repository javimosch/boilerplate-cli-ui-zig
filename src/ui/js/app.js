// Main Vue Application with Hashbang Routing
(function() {
    const { createApp, ref, onMounted, onUnmounted, watch, provide } = Vue;

const app = createApp({
    setup() {
        // ─── Hash Router ──────────────────────────────────────────
        const getHashRoute = () => {
            const hash = window.location.hash.replace('#/', '').replace('#', '');
            return hash || 'dashboard';
        };

        const currentView = ref(getHashRoute());
        const sidebarOpen = ref(false);
        const status = ref(null);

        const navigate = (view) => {
            window.location.hash = `/${view}`;
        };

        const onHashChange = () => {
            currentView.value = getHashRoute();
        };

        // ─── Status Fetching ──────────────────────────────────────
        const fetchStatus = async () => {
            try {
                const res = await fetch('/api/status');
                status.value = await res.json();
            } catch (err) {
                console.error('Failed to fetch status:', err);
            }
        };

        // ─── Theme Management ─────────────────────────────────────
        let systemThemeHandler = null;

        // Check both storage keys for a saved theme
        const savedSettings = (() => {
            try { return JSON.parse(localStorage.getItem('cli-ui-settings') || '{}'); } catch(e) { return {}; }
        })();
        const initialTheme = savedSettings.theme || localStorage.getItem('cli-ui-theme') || 'light';

        const theme = ref(initialTheme);

        const applyTheme = (t) => {
            theme.value = t;
            localStorage.setItem('cli-ui-theme', t);

            const root = document.documentElement;
            if (t === 'dark') {
                root.classList.add('dark');
            } else if (t === 'light') {
                root.classList.remove('dark');
            } else { // system
                const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
                root.classList.toggle('dark', prefersDark);
            }

            // Clean up previous system listener
            if (systemThemeHandler) {
                window.matchMedia('(prefers-color-scheme: dark)').removeEventListener('change', systemThemeHandler);
                systemThemeHandler = null;
            }

            // Set up system listener if needed
            if (t === 'system') {
                systemThemeHandler = (e) => {
                    document.documentElement.classList.toggle('dark', e.matches);
                };
                window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', systemThemeHandler);
            }
        };

        // Apply initial theme
        applyTheme(initialTheme);

        onMounted(() => {
            window.addEventListener('hashchange', onHashChange);
            fetchStatus();
            setInterval(fetchStatus, 10000);
        });

        onUnmounted(() => {
            window.removeEventListener('hashchange', onHashChange);
            // Clean up system theme listener
            if (systemThemeHandler) {
                window.matchMedia('(prefers-color-scheme: dark)').removeEventListener('change', systemThemeHandler);
            }
        });

        // Provide to all components
        provide('status', status);
        provide('currentView', currentView);
        provide('sidebarOpen', sidebarOpen);
        provide('fetchStatus', fetchStatus);
        provide('navigate', navigate);
        provide('theme', theme);
        provide('setTheme', applyTheme);

        return { currentView, sidebarOpen, status, navigate, theme };
    }
});

// Register components
app.component('app-layout', AppLayout);
app.component('sidebar', Sidebar);
app.component('status-card', StatusCard);
app.component('dashboard-view', DashboardView);
app.component('settings-view', SettingsView);

// Mount
app.mount('#app');
})();
