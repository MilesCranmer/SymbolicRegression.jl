import type { Ref } from 'vue'
import { nextTick } from 'vue'

type StabilizeScrollPosition = <Args extends readonly unknown[], Return>(
  func: (...args: Args) => Return
) => (...args: Args) => Promise<Return>

export const useStabilizeScrollPosition = (
  targetEle: Ref<HTMLElement | undefined>
) => {
  if (typeof document === 'undefined') {
    const mock: StabilizeScrollPosition =
      f =>
      async (...args) =>
        f(...args)
    return { stabilizeScrollPosition: mock }
  }

  const scrollableEleVal = document.documentElement

  const stabilizeScrollPosition: StabilizeScrollPosition =
    func =>
    async (...args) => {
      const result = func(...args)
      const eleVal = targetEle.value
      if (!eleVal) return result

      const offset = eleVal.offsetTop - scrollableEleVal.scrollTop
      await nextTick()
      scrollableEleVal.scrollTop = eleVal.offsetTop - offset

      return result
    }

  return { stabilizeScrollPosition }
}
