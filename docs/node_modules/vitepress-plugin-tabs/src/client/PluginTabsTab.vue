<script setup lang="ts">
import { useTabsSingleState } from './useTabsSingleState'
import { useIsPrint } from './useIsPrint'

defineProps<{ label: string }>()

const { uid, selected } = useTabsSingleState()

const isPrint = useIsPrint()
</script>

<template>
  <div
    v-if="selected === label || isPrint"
    :id="`panel-${label}-${uid}`"
    class="plugin-tabs--content"
    role="tabpanel"
    tabindex="0"
    :aria-labelledby="`tab-${label}-${uid}`"
    :data-is-print="isPrint"
  >
    <slot />
  </div>
</template>

<style scoped>
.plugin-tabs--content {
  padding: 16px;
}

.plugin-tabs--content[data-is-print='true']:not(:last-child) {
  border-bottom: 2px solid var(--vp-plugin-tabs-tab-divider);
}

.plugin-tabs--content > :first-child:first-child {
  margin-top: 0;
}

.plugin-tabs--content > :last-child:last-child {
  margin-bottom: 0;
}

.plugin-tabs--content > :deep(div[class*='language-']) {
  border-radius: 8px;
  margin: 16px 0px;
}

:root:not(.dark) .plugin-tabs--content :deep(div[class*='language-']) {
  background-color: var(--vp-c-bg);
}
</style>
