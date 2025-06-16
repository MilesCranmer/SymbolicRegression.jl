import { Engine } from '../common/engine.js';
import { locales } from '../l10n/l10n.js';
import { addFunctionSemantic } from '../semantic_tree/semantic_attr.js';
import { MathSimpleStore } from './math_simple_store.js';
import { Axis, DynamicCstr } from './dynamic_cstr.js';
let locale = DynamicCstr.DEFAULT_VALUES[Axis.LOCALE];
let modality = DynamicCstr.DEFAULT_VALUES[Axis.MODALITY];
export function changeLocale(json) {
    if (!json['locale'] && !json['modality']) {
        return false;
    }
    locale = json['locale'] || locale;
    modality = json['modality'] || modality;
    return true;
}
let siPrefixes = {};
export function setSiPrefixes(prefixes) {
    siPrefixes = prefixes;
}
export const subStores = new Map();
export const baseStores = new Map();
function getSubStore(base, key) {
    let store = subStores.get(key);
    if (store) {
        return store;
    }
    store = new MathSimpleStore();
    store.base = baseStores.get(base);
    subStores.set(key, store);
    return store;
}
function completeWithBase(json) {
    const base = baseStores.get(json.key);
    if (!base) {
        return;
    }
    const names = json.names;
    Object.assign(json, base);
    if (names && base.names) {
        json.names = json.names.concat(names);
    }
}
export function defineRules(base, str, mappings) {
    const store = getSubStore(base, str);
    store.defineRulesFromMappings(locale, modality, mappings);
}
export function defineRule(domain, style, str, content) {
    const store = getSubStore(str, str);
    store.defineRuleFromStrings(locale, modality, domain, style, content);
}
export function addSymbolRules(json) {
    for (const rule of json) {
        if (changeLocale(rule)) {
            continue;
        }
        const key = MathSimpleStore.parseUnicode(rule['key']);
        if (locale === 'base') {
            baseStores.set(key, rule);
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
export const addCharacterRules = (json) => json.forEach(addCharacterRule);
function addFunctionRule(json) {
    for (let j = 0, name; (name = json.names[j]); j++) {
        defineRules(json.key, name, json.mappings);
    }
}
export function addFunctionRules(json) {
    for (const rule of json) {
        if (changeLocale(rule)) {
            continue;
        }
        addFunctionSemantic(rule.key, rule.names || []);
        if (locale === 'base') {
            baseStores.set(rule.key, rule);
            continue;
        }
        completeWithBase(rule);
        addFunctionRule(rule);
    }
}
export function addUnitRules(json) {
    for (const rule of json) {
        if (changeLocale(rule)) {
            continue;
        }
        rule.key += ':unit';
        if (locale === 'base') {
            baseStores.set(rule.key, rule);
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
                newJson['mappings'][domain][style] = locales[locale]().FUNCTIONS.si(prefix, json['mappings'][domain][style]);
            }
        }
        addFunctionRule(newJson);
    }
}
export function lookupRule(node, dynamic) {
    const store = subStores.get(node);
    return store ? store.lookupRule(null, dynamic) : null;
}
export function lookupCategory(character) {
    const store = subStores.get(character);
    return (store === null || store === void 0 ? void 0 : store.base) ? store.base.category : '';
}
export function lookupString(text, dynamic) {
    const rule = lookupRule(text, dynamic);
    if (!rule) {
        return null;
    }
    return rule.action;
}
Engine.getInstance().evaluator = lookupString;
export function enumerate(info = {}) {
    for (const store of subStores.values()) {
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
export function reset() {
    locale = DynamicCstr.DEFAULT_VALUES[Axis.LOCALE];
    modality = DynamicCstr.DEFAULT_VALUES[Axis.MODALITY];
}
