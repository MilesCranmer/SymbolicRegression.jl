import type { App } from 'vue'
import PluginTabs from './PluginTabs.vue'
import PluginTabsTab from './PluginTabsTab.vue'
import { provideTabsSharedState } from './useTabsSelectedState'

export const enhanceAppWithTabs = (app: App) => {
  provideTabsSharedState(app)
  app.component('PluginTabs', PluginTabs)
  app.component('PluginTabsTab', PluginTabsTab)
}
