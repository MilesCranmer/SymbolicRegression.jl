import { Engine } from '../common/engine.js';
import { Axis } from './dynamic_cstr.js';
export class MathSimpleStore {
    constructor() {
        this.rules = new Map();
    }
    static parseUnicode(num) {
        const keyValue = parseInt(num, 16);
        return String.fromCodePoint(keyValue);
    }
    static testDynamicConstraints_(dynamic, rule) {
        if (Engine.getInstance().strict) {
            return rule.cstr.equal(dynamic);
        }
        return Engine.getInstance().comparator.match(rule.cstr);
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
        const parser = Engine.getInstance().parsers[domain] ||
            Engine.getInstance().defaultParser;
        const comp = Engine.getInstance().comparators[domain];
        const cstr = `${locale}.${modality}.${domain}.${style}`;
        const dynamic = parser.parse(cstr);
        const comparator = comp ? comp() : Engine.getInstance().comparator;
        const oldCstr = comparator.getReference();
        comparator.setReference(dynamic);
        const rule = { cstr: dynamic, action: content };
        store = store.filter((r) => !dynamic.equal(r.cstr));
        store.push(rule);
        this.rules.set(locale, store);
        comparator.setReference(oldCstr);
    }
    lookupRule(_node, dynamic) {
        let rules = this.getRules(dynamic.getValue(Axis.LOCALE));
        rules = rules.filter(function (rule) {
            return MathSimpleStore.testDynamicConstraints_(dynamic, rule);
        });
        if (rules.length === 1) {
            return rules[0];
        }
        return rules.length
            ? rules.sort((r1, r2) => Engine.getInstance().comparator.compare(r1.cstr, r2.cstr))[0]
            : null;
    }
}
