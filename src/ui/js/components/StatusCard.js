// StatusCard - Displays a status metric
var StatusCard = {
    props: {
        title: String,
        value: String,
        icon: String,
        color: {
            type: String,
            default: 'indigo'
        }
    },
    template: `
        <div class="bg-white dark:bg-gray-800 rounded-xl border border-gray-200 dark:border-gray-700 p-5">
            <div class="flex items-center justify-between">
                <div>
                    <p class="text-sm font-medium text-gray-500 dark:text-gray-400">{{ title }}</p>
                    <p class="text-2xl font-bold text-gray-900 dark:text-white mt-1">{{ value }}</p>
                </div>
                <div :class="[
                    'w-12 h-12 rounded-lg flex items-center justify-center',
                    colorClasses
                ]">
                    <i :data-lucide="icon" class="w-6 h-6"></i>
                </div>
            </div>
        </div>
    `,
    computed: {
        colorClasses() {
            const colors = {
                indigo: 'bg-indigo-100 text-indigo-600',
                green: 'bg-green-100 text-green-600',
                blue: 'bg-blue-100 text-blue-600',
                purple: 'bg-purple-100 text-purple-600',
            };
            return colors[this.color] || colors.indigo;
        }
    }
};
