"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.MathSimpleStore = void 0;
const engine_js_1 = require("../common/engine.js");
const dynamic_cstr_js_1 = require("./dynamic_cstr.js");
class MathSimpleStore {
    constructor() {
        this.rules = new Map();
    }
    static parseUnicode(num) {
        const keyValue = parseInt(num, 16);
        return String.fromCodePoint(keyValue);
    }
    static testDynamicConstraints_(dynamic, rule) {
        if (engine_js_1.Engine.getInstance().strict) {
            return rule.cstr.equal(dynamic);
        }
        return engine_js_1.Engine.getInstance().comparator.match(rule.cstr);
    }
    defineRulesFromMappings(locale, modality, mapping) {
        for (const [domain, styles] of Object.entries(mapping)) {
            for (const [style, content] of Object.entries(styles)) {
                this.defineRuleFromStrings(locale, modality, domain, style, content);
            }
        }
    }
    getRules(key) {
        let store = this.rules.get(key);
        if (!store) {
            store = [];
            this.rules.set(key, store);
        }
        return store;
    }
    defineRuleFromStrings(locale, modality, domain, style, content) {
        let store = this.getRules(locale);
        const parser = engine_js_1.Engine.getInstance().parsers[domain] ||
            engine_js_1.Engine.getInstance().defaultParser;
        const comp = engine_js_1.Engine.getInstance().comparators[domain];
        const cstr = `${locale}.${modality}.${domain}.${style}`;
        const dynamic = parser.parse(cstr);
        const comparator = comp ? comp() : engine_js_1.Engine.getInstance().comparator;
        const oldCstr = comparator.getReference();
        comparator.setReference(dynamic);
        const rule = { cstr: dynamic, action: content };
        store = store.filter((r) => !dynamic.equal(r.cstr));
        store.push(rule);
        this.rules.set(locale, store);
        comparator.setReference(oldCstr);
    }
    lookupRule(_node, dynamic) {
        let rules = this.getRules(dynamic.getValue(dynamic_cstr_js_1.Axis.LOCALE));
        rules = rules.filter(function (rule) {
            return MathSimpleStore.testDynamicConstraints_(dynamic, rule);
        });
        if (rules.length === 1) {
            return rules[0];
        }
        return rules.length
            ? rules.sort((r1, r2) => engine_js_1.Engine.getInstance().comparator.compare(r1.cstr, r2.cstr))[0]
            : null;
    }
}
exports.MathSimpleStore = MathSimpleStore;
