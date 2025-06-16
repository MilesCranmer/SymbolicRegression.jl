import { onBeforeMount, onUnmounted, ref } from 'vue'

export const useIsPrint = () => {
  const matchMedia =
    typeof window !== 'undefined' ? window.matchMedia('print') : undefined
  const value = ref(matchMedia?.matches)

  const listener = () => {
    value.value = matchMedia?.matches
  }
  onBeforeMount(() => {
    matchMedia?.addEventListener('change', listener)
  })
  onUnmounted(() => {
    matchMedia?.removeEventListener('change', listener)
  })

  return value
}
