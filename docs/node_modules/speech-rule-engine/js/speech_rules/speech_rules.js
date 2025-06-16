"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.addStore = addStore;
exports.getStore = getStore;
const dynamic_cstr_js_1 = require("../rule_engine/dynamic_cstr.js");
const funcStore = new Map();
function addStore(constr, inherit, store) {
    const values = {};
    if (inherit) {
        const inherits = funcStore.get(inherit) || {};
        Object.assign(values, inherits);
    }
    funcStore.set(constr, Object.assign(values, store));
}
function getStore(locale, modality, domain) {
    return (funcStore.get([locale, modality, domain].join('.')) ||
        funcStore.get([dynamic_cstr_js_1.DynamicCstr.DEFAULT_VALUES[dynamic_cstr_js_1.Axis.LOCALE], modality, domain].join('.')) ||
        funcStore.get([dynamic_cstr_js_1.DynamicCstr.BASE_LOCALE, modality, domain].join('.')) ||
        {});
}
