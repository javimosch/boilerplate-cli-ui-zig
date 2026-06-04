// AppLayout - Main layout wrapper
(function() {
    const { inject, onMounted, onUpdated } = Vue;

    window.AppLayout = {
    template: `
        <div class="flex h-screen">
            <!-- Sidebar -->
            <sidebar :open="sidebarOpen" :current-view="currentView"></sidebar>
            
            <!-- Main Content -->
            <div class="flex-1 flex flex-col overflow-hidden">
                <!-- Mobile Header -->
                <header class="lg:hidden bg-white dark:bg-gray-800 border-b border-gray-200 dark:border-gray-700 px-4 py-3 flex items-center justify-between">
                    <button @click="sidebarOpen = true" class="text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white">
                        <i data-lucide="menu" class="w-6 h-6"></i>
                    </button>
                    <span class="font-semibold text-gray-900 dark:text-white">CLI UI</span>
                    <div class="w-6"></div>
                </header>
                
                <!-- Page Content -->
                <main class="flex-1 p-6 overflow-auto">
                    <dashboard-view v-if="currentView === 'dashboard'"></dashboard-view>
                    <settings-view v-if="currentView === 'settings'"></settings-view>
                </main>
            </div>
        </div>
    `,
    setup() {
        const sidebarOpen = inject('sidebarOpen');
        const currentView = inject('currentView');

        onMounted(() => {
            lucide.createIcons();
        });

        onUpdated(() => {
            lucide.createIcons();
        });
        
        return { sidebarOpen, currentView };
    }
};
})();
