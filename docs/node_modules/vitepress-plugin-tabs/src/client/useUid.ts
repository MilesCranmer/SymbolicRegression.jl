let id = 0

export const useUid = () => {
  id++
  return '' + id
}
