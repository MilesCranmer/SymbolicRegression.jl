import { Axis, DynamicCstr } from '../rule_engine/dynamic_cstr.js';
const funcStore = new Map();
export function addStore(constr, inherit, store) {
    const values = {};
    if (inherit) {
        const inherits = funcStore.get(inherit) || {};
        Object.assign(values, inherits);
    }
    funcStore.set(constr, Object.assign(values, store));
}
export function getStore(locale, modality, domain) {
    return (funcStore.get([locale, modality, domain].join('.')) ||
        funcStore.get([DynamicCstr.DEFAULT_VALUES[Axis.LOCALE], modality, domain].join('.')) ||
        funcStore.get([DynamicCstr.BASE_LOCALE, modality, domain].join('.')) ||
        {});
}
