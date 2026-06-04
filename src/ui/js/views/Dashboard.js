// Dashboard View
var DashboardView = {
    template: `
        <div>
            <div class="mb-6">
                <h2 class="text-2xl font-bold text-gray-900 dark:text-white">Dashboard</h2>
                <p class="text-gray-500 dark:text-gray-400 mt-1">Server status and overview</p>
            </div>
            
            <!-- Status Cards -->
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
                <status-card
                    title="Status"
                    :value="status?.status || 'Unknown'"
                    icon="activity"
                    color="green"
                ></status-card>
                <status-card
                    title="Port"
                    :value="status?.port || '-'"
                    icon="network"
                    color="blue"
                ></status-card>
                <status-card
                    title="Uptime"
                    :value="uptime"
                    icon="clock"
                    color="purple"
                ></status-card>
                <status-card
                    title="Version"
                    :value="status?.version || '-'"
                    icon="tag"
                    color="indigo"
                ></status-card>
            </div>
            
            <!-- API Endpoints -->
            <div class="bg-white dark:bg-gray-800 rounded-xl border border-gray-200 dark:border-gray-700 p-6">
                <div class="flex items-center justify-between mb-4">
                    <h3 class="text-lg font-semibold text-gray-900 dark:text-white">API Endpoints</h3>
                    <button @click="fetchStatus()" class="text-sm text-indigo-600 dark:text-indigo-400 hover:text-indigo-700 dark:hover:text-indigo-300 flex items-center gap-1">
                        <i data-lucide="refresh-cw" class="w-4 h-4"></i> Refresh
                    </button>
                </div>
                <div class="space-y-3">
                    <div 
                        v-for="endpoint in endpoints" 
                        :key="endpoint.path"
                        @click="testEndpoint(endpoint.path)"
                        class="flex items-center justify-between p-3 rounded-lg bg-gray-50 dark:bg-gray-700/50 api-endpoint transition-all cursor-pointer"
                    >
                        <div class="flex items-center gap-3">
                            <span :class="[
                                'px-2 py-1 text-xs font-mono font-bold rounded',
                                methodColor(endpoint.method)
                            ]">
                                {{ endpoint.method }}
                            </span>
                            <span class="font-mono text-sm text-gray-700 dark:text-gray-300">{{ endpoint.path }}</span>
                        </div>
                        <span class="text-sm text-gray-500 dark:text-gray-400">{{ endpoint.description }}</span>
                    </div>
                </div>
                
                <!-- Response Preview -->
                <div v-if="lastResponse" class="mt-4 p-4 rounded-lg bg-gray-900 text-green-400 font-mono text-sm overflow-x-auto">
                    <pre>{{ JSON.stringify(lastResponse, null, 2) }}</pre>
                </div>
            </div>
        </div>
    `,
    setup() {
        const status = Vue.inject('status');
        const fetchStatus = Vue.inject('fetchStatus');
        
        const lastResponse = Vue.ref(null);
        
        const endpoints = [
            { method: 'GET', path: '/api/status', description: 'Server status' },
            { method: 'GET', path: '/api/health', description: 'Health check' },
        ];
        
        const uptime = Vue.computed(() => {
            if (!status.value?.uptime) return '-';
            return status.value.uptime.split('.')[0];
        });
        
        const methodColor = (method) => {
            const colors = {
                'GET': 'bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-300',
                'POST': 'bg-blue-100 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300',
            };
            return colors[method] || 'bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-300';
        };
        
        const testEndpoint = async (path) => {
            try {
                const res = await fetch(path);
                lastResponse.value = await res.json();
            } catch (err) {
                lastResponse.value = { error: err.message };
            }
        };
        
        Vue.onMounted(() => {
            lucide.createIcons();
        });
        
        Vue.onUpdated(() => {
            lucide.createIcons();
        });
        
        return { status, endpoints, uptime, lastResponse, methodColor, testEndpoint, fetchStatus };
    }
};
