import { provide, type InjectionKey, type Ref, inject } from 'vue'

type TabsSingleState = {
  uid: string
  selected: Ref<string>
}

const injectionKey: InjectionKey<TabsSingleState> =
  'vitepress:tabSingleState' as unknown as symbol

export const provideTabsSingleState = (state: TabsSingleState) => {
  provide(injectionKey, state)
}

export const useTabsSingleState = () => {
  const singleState = inject(injectionKey)
  if (!singleState) {
    throw new Error(
      '[vitepress-plugin-tabs] TabsSingleState should be injected'
    )
  }
  return singleState
}
