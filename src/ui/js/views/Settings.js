// Settings View
var SettingsView = {
    template: `
        <div>
            <div class="mb-6">
                <h2 class="text-2xl font-bold text-gray-900 dark:text-white">Settings</h2>
                <p class="text-gray-500 dark:text-gray-400 mt-1">Configure your CLI UI</p>
            </div>
            
            <div class="space-y-6">
                <!-- Appearance -->
                <div class="bg-white dark:bg-gray-800 rounded-xl border border-gray-200 dark:border-gray-700 p-6">
                    <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">Appearance</h3>
                    <div class="space-y-4">
                        <div>
                            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Theme</label>
                            <select 
                                v-model="settings.theme"
                                class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-white rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                            >
                                <option value="light">Light</option>
                                <option value="dark">Dark</option>
                                <option value="system">System</option>
                            </select>
                        </div>
                        <div>
                            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Accent Color</label>
                            <div class="flex gap-2">
                                <button 
                                    v-for="color in accentColors" 
                                    :key="color"
                                    @click="settings.accentColor = color"
                                    :class="[
                                        'w-8 h-8 rounded-full transition-transform',
                                        settings.accentColor === color ? 'ring-2 ring-offset-2 ring-gray-400 scale-110' : 'hover:scale-105'
                                    ]"
                                    :style="{ backgroundColor: color }"
                                ></button>
                            </div>
                        </div>
                    </div>
                </div>
                
                <!-- API Configuration -->
                <div class="bg-white dark:bg-gray-800 rounded-xl border border-gray-200 dark:border-gray-700 p-6">
                    <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">API Configuration</h3>
                    <div class="space-y-4">
                        <div>
                            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Refresh Interval (seconds)</label>
                            <input 
                                v-model.number="settings.refreshInterval"
                                type="number" 
                                min="1" 
                                max="60"
                                class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-white rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                            >
                        </div>
                        <div class="flex items-center justify-between">
                            <div>
                                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">Auto-refresh</label>
                                <p class="text-xs text-gray-500 dark:text-gray-400">Automatically refresh status</p>
                            </div>
                            <button 
                                @click="settings.autoRefresh = !settings.autoRefresh"
                                :class="[
                                    'relative inline-flex h-6 w-11 items-center rounded-full transition-colors',
                                    settings.autoRefresh ? 'bg-indigo-600' : 'bg-gray-200 dark:bg-gray-600'
                                ]"
                            >
                                <span 
                                    :class="[
                                        'inline-block h-4 w-4 transform rounded-full bg-white dark:bg-gray-300 transition-transform',
                                        settings.autoRefresh ? 'translate-x-6' : 'translate-x-1'
                                    ]"
                                ></span>
                            </button>
                        </div>
                    </div>
                </div>
                
                <!-- Save Button -->
                <div class="flex justify-end items-center gap-4">
                    <span v-if="saveMessage" class="text-sm text-green-600 dark:text-green-400">{{ saveMessage }}</span>
                    <button 
                        @click="saveSettings"
                        class="px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 dark:hover:bg-indigo-500 transition-colors font-medium"
                    >
                        Save Settings
                    </button>
                </div>
            </div>
        </div>
    `,
    setup() {
        const theme = Vue.inject('theme');
        const setTheme = Vue.inject('setTheme');
        
        const settings = Vue.reactive({
            theme: theme.value,
            accentColor: '#6366f1',
            refreshInterval: 10,
            autoRefresh: true,
        });
        
        const saveMessage = Vue.ref('');
        
        const accentColors = [
            '#6366f1', // indigo
            '#8b5cf6', // violet
            '#ec4899', // pink
            '#10b981', // emerald
            '#3b82f6', // blue
            '#f59e0b', // amber
        ];
        
        const saveSettings = () => {
            localStorage.setItem('cli-ui-settings', JSON.stringify(settings));
            // Apply theme immediately on save
            setTheme(settings.theme);
            saveMessage.value = 'Settings saved!';
            setTimeout(() => { saveMessage.value = ''; }, 2000);
        };
        
        // Apply theme whenever it changes in the dropdown
        Vue.watch(() => settings.theme, (newTheme) => {
            setTheme(newTheme);
        });
        
        // Load saved settings on mount
        Vue.onMounted(() => {
            const saved = localStorage.getItem('cli-ui-settings');
            if (saved) {
                const parsed = JSON.parse(saved);
                Object.assign(settings, parsed);
                // Ensure theme from settings is applied
                setTheme(parsed.theme || theme.value);
            }
        });
        
        return { settings, accentColors, saveSettings, saveMessage };
    }
};
