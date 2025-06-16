"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.addCharacterRules = exports.baseStores = exports.subStores = void 0;
exports.changeLocale = changeLocale;
exports.setSiPrefixes = setSiPrefixes;
exports.defineRules = defineRules;
exports.defineRule = defineRule;
exports.addSymbolRules = addSymbolRules;
exports.addFunctionRules = addFunctionRules;
exports.addUnitRules = addUnitRules;
exports.lookupRule = lookupRule;
exports.lookupCategory = lookupCategory;
exports.lookupString = lookupString;
exports.enumerate = enumerate;
exports.reset = reset;
const engine_js_1 = require("../common/engine.js");
const l10n_js_1 = require("../l10n/l10n.js");
const semantic_attr_js_1 = require("../semantic_tree/semantic_attr.js");
const math_simple_store_js_1 = require("./math_simple_store.js");
const dynamic_cstr_js_1 = require("./dynamic_cstr.js");
let locale = dynamic_cstr_js_1.DynamicCstr.DEFAULT_VALUES[dynamic_cstr_js_1.Axis.LOCALE];
let modality = dynamic_cstr_js_1.DynamicCstr.DEFAULT_VALUES[dynamic_cstr_js_1.Axis.MODALITY];
function changeLocale(json) {
    if (!json['locale'] && !json['modality']) {
        return false;
    }
    locale = json['locale'] || locale;
    modality = json['modality'] || modality;
    return true;
}
let siPrefixes = {};
function setSiPrefixes(prefixes) {
    siPrefixes = prefixes;
}
exports.subStores = new Map();
exports.baseStores = new Map();
function getSubStore(base, key) {
    let store = exports.subStores.get(key);
    if (store) {
        return store;
    }
    store = new math_simple_store_js_1.MathSimpleStore();
    store.base = exports.baseStores.get(base);
    exports.subStores.set(key, store);
    return store;
}
function completeWithBase(json) {
    const base = exports.baseStores.get(json.key);
    if (!base) {
        return;
    }
    const names = json.names;
    Object.assign(json, base);
    if (names && base.names) {
        json.names = json.names.concat(names);
    }
}
function defineRules(base, str, mappings) {
    const store = getSubStore(base, str);
    store.defineRulesFromMappings(locale, modality, mappings);
}
function defineRule(domain, style, str, content) {
    const store = getSubStore(str, str);
    store.defineRuleFromStrings(locale, modality, domain, style, content);
}
function addSymbolRules(json) {
    for (const rule of json) {
        if (changeLocale(rule)) {
            continue;
        }
        const key = math_simple_store_js_1.MathSimpleStore.parseUnicode(rule['key']);
        if (locale === 'base') {
            exports.baseStores.set(key, rule);
            continue;
        }
        defineRules(key, key, rule['mappings']);
    }
}
function addCharacterRule(json) {
    if (changeLocale(json)) {
        return;
    }
    for (const [key, value] of Object.entries(json)) {
        defineRule('default', 'default', key, value);
    }
}
const addCharacterRules = (json) => json.forEach(addCharacterRule);
exports.addCharacterRules = addCharacterRules;
function addFunctionRule(json) {
    for (let j = 0, name; (name = json.names[j]); j++) {
        defineRules(json.key, name, json.mappings);
    }
}
function addFunctionRules(json) {
    for (const rule of json) {
        if (changeLocale(rule)) {
            continue;
        }
        (0, semantic_attr_js_1.addFunctionSemantic)(rule.key, rule.names || []);
        if (locale === 'base') {
            exports.baseStores.set(rule.key, rule);
            continue;
        }
        completeWithBase(rule);
        addFunctionRule(rule);
    }
}
function addUnitRules(json) {
    for (const rule of json) {
        if (changeLocale(rule)) {
            continue;
        }
        rule.key += ':unit';
        if (locale === 'base') {
            exports.baseStores.set(rule.key, rule);
            continue;
        }
        completeWithBase(rule);
        if (rule.names) {
            rule.names = rule.names.map(function (name) {
                return name + ':unit';
            });
        }
        if (rule.si) {
            addSiUnitRule(rule);
        }
        addFunctionRule(rule);
    }
}
function addSiUnitRule(json) {
    for (const key of Object.keys(siPrefixes)) {
        const newJson = Object.assign({}, json);
        newJson.mappings = {};
        const prefix = siPrefixes[key];
        newJson['names'] = newJson['names'].map(function (name) {
            return key + name;
        });
        for (const domain of Object.keys(json['mappings'])) {
            newJson.mappings[domain] = {};
            for (const style of Object.keys(json['mappings'][domain])) {
                newJson['mappings'][domain][style] = l10n_js_1.locales[locale]().FUNCTIONS.si(prefix, json['mappings'][domain][style]);
            }
        }
        addFunctionRule(newJson);
    }
}
function lookupRule(node, dynamic) {
    const store = exports.subStores.get(node);
    return store ? store.lookupRule(null, dynamic) : null;
}
function lookupCategory(character) {
    const store = exports.subStores.get(character);
    return (store === null || store === void 0 ? void 0 : store.base) ? store.base.category : '';
}
function lookupString(text, dynamic) {
    const rule = lookupRule(text, dynamic);
    if (!rule) {
        return null;
    }
    return rule.action;
}
engine_js_1.Engine.getInstance().evaluator = lookupString;
function enumerate(info = {}) {
    for (const store of exports.subStores.values()) {
        for (const [, rules] of store.rules.entries()) {
            for (const { cstr: dynamic } of rules) {
                info = enumerate_(dynamic.getValues(), info);
            }
        }
    }
    return info;
}
function enumerate_(dynamic, info) {
    info = info || {};
    if (!dynamic.length) {
        return info;
    }
    info[dynamic[0]] = enumerate_(dynamic.slice(1), info[dynamic[0]]);
    return info;
}
function reset() {
    locale = dynamic_cstr_js_1.DynamicCstr.DEFAULT_VALUES[dynamic_cstr_js_1.Axis.LOCALE];
    modality = dynamic_cstr_js_1.DynamicCstr.DEFAULT_VALUES[dynamic_cstr_js_1.Axis.MODALITY];
}
