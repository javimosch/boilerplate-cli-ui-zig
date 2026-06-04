// Sidebar navigation component
var Sidebar = {
    props: {
        open: Boolean,
        currentView: String
    },
    template: `
        <!-- Mobile overlay -->
        <div 
            v-if="open" 
            class="lg:hidden fixed inset-0 bg-black bg-opacity-50 z-40"
            @click="sidebarOpen = false"
        ></div>
        
        <!-- Sidebar -->
        <aside 
            :class="[
                'fixed lg:relative inset-y-0 left-0 z-50 w-64 bg-white dark:bg-gray-900 border-r border-gray-200 dark:border-gray-800 transform transition-transform duration-200 ease-in-out flex-shrink-0',
                open ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'
            ]"
        >
            <div class="flex flex-col h-full">
                <!-- Logo -->
                <div class="px-6 py-5 border-b border-gray-200 dark:border-gray-800">
                    <h1 class="text-xl font-bold text-gray-900 dark:text-white flex items-center gap-2">
                        <i data-lucide="terminal" class="w-5 h-5 text-indigo-600"></i>
                        CLI UI
                    </h1>
                    <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">Zig + Vue 3</p>
                </div>
                
                <!-- Navigation -->
                <nav class="flex-1 px-4 py-4 space-y-1">
                    <button
                        v-for="item in navItems"
                        :key="item.id"
                        @click="handleNavigate(item.id)"
                        :class="[
                            'w-full flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition-colors',
                            currentView === item.id
                                ? 'bg-indigo-50 dark:bg-indigo-900/30 text-indigo-700 dark:text-indigo-300'
                                : 'text-gray-600 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-800 hover:text-gray-900 dark:hover:text-white'
                        ]"
                    >
                        <i :data-lucide="item.icon" class="w-5 h-5"></i>
                        {{ item.label }}
                    </button>
                </nav>
                
                <!-- Footer -->
                <div class="px-4 py-4 border-t border-gray-200 dark:border-gray-800">
                    <div class="flex items-center gap-2 text-sm text-gray-500 dark:text-gray-400">
                        <div class="w-2 h-2 rounded-full bg-green-500 pulse-dot"></div>
                        <span>Server Running</span>
                    </div>
                </div>
            </div>
        </aside>
    `,
    setup(props) {
        const sidebarOpen = Vue.inject('sidebarOpen');
        const navigate = Vue.inject('navigate');
        
        const navItems = [
            { id: 'dashboard', label: 'Dashboard', icon: 'layout-dashboard' },
            { id: 'settings', label: 'Settings', icon: 'settings' },
        ];
        
        const handleNavigate = (viewId) => {
            navigate(viewId);
            sidebarOpen.value = false;
        };
        
        return { navItems, sidebarOpen, handleNavigate };
    }
};
