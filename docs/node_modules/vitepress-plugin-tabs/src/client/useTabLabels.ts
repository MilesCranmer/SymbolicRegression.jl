import type { Ref } from 'vue'
import { computed, useSlots } from 'vue'

export function useTabLabels(): Ref<string[]> {
  const slots = useSlots()
  const tabLabels = computed(() => {
    const defaultSlot = slots.default?.()
    if (!defaultSlot) {
      return []
    }

    return defaultSlot
      .filter(
        vnode =>
          typeof vnode.type === 'object' &&
          '__name' in vnode.type &&
          vnode.type.__name === 'PluginTabsTab' &&
          vnode.props
      )
      .map(vnode => vnode.props?.label)
  })
  return tabLabels
}
