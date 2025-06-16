"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.generateBase = generateBase;
exports.generate = generate;
const Alphabet = require("./alphabet.js");
const engine_js_1 = require("../common/engine.js");
const L10n = require("../l10n/l10n.js");
const locale_js_1 = require("../l10n/locale.js");
const locale_util_js_1 = require("../l10n/locale_util.js");
const MathCompoundStore = require("../rule_engine/math_compound_store.js");
const Domains = {
    small: ['default'],
    capital: ['default'],
    digit: ['default']
};
function makeDomains() {
    const alph = locale_js_1.LOCALE.ALPHABETS;
    const combineKeys = (obj1, obj2) => {
        const result = {};
        Object.keys(obj1).forEach((k) => (result[k] = true));
        Object.keys(obj2).forEach((k) => (result[k] = true));
        return Object.keys(result);
    };
    Domains.small = combineKeys(alph.smallPrefix, alph.letterTrans);
    Domains.capital = combineKeys(alph.capPrefix, alph.letterTrans);
    Domains.digit = combineKeys(alph.digitPrefix, alph.digitTrans);
}
function generateBase() {
    for (const int of Alphabet.INTERVALS.values()) {
        const letters = int.unicode;
        for (const letter of letters) {
            MathCompoundStore.baseStores.set(letter, {
                key: letter,
                category: int.category
            });
        }
    }
}
function generate(locale) {
    const oldLocale = engine_js_1.Engine.getInstance().locale;
    engine_js_1.Engine.getInstance().locale = locale;
    L10n.setLocale();
    MathCompoundStore.changeLocale({ locale: locale });
    makeDomains();
    for (const int of Alphabet.INTERVALS.values()) {
        const letters = int.unicode;
        if ('offset' in int) {
            numberRules(letters, int.font, int.offset || 0);
        }
        else {
            const alphabet = locale_js_1.LOCALE.ALPHABETS[int.base];
            alphabetRules(letters, alphabet, int.font, !!int.capital);
        }
    }
    engine_js_1.Engine.getInstance().locale = oldLocale;
    L10n.setLocale();
}
function getFont(font) {
    const realFont = font === 'normal' || font === 'fullwidth'
        ? ''
        : locale_js_1.LOCALE.MESSAGES.font[font] || locale_js_1.LOCALE.MESSAGES.embellish[font] || '';
    return (0, locale_util_js_1.localeFontCombiner)(realFont);
}
function alphabetRules(unicodes, letters, font, cap) {
    const realFont = getFont(font);
    for (let i = 0, unicode, letter; (unicode = unicodes[i]), (letter = letters[i]); i++) {
        const prefixes = cap
            ? locale_js_1.LOCALE.ALPHABETS.capPrefix
            : locale_js_1.LOCALE.ALPHABETS.smallPrefix;
        const domains = cap ? Domains.capital : Domains.small;
        makeLetter(realFont.combiner, unicode, letter, realFont.font, prefixes, locale_js_1.LOCALE.ALPHABETS.letterTrans, domains);
    }
}
function numberRules(unicodes, font, offset) {
    const realFont = getFont(font);
    for (let i = 0, unicode; (unicode = unicodes[i]); i++) {
        const prefixes = locale_js_1.LOCALE.ALPHABETS.digitPrefix;
        const num = i + offset;
        makeLetter(realFont.combiner, unicode, num, realFont.font, prefixes, locale_js_1.LOCALE.ALPHABETS.digitTrans, Domains.digit);
    }
}
function makeLetter(combiner, unicode, letter, font, prefixes, transformers, domains) {
    for (let i = 0, domain; (domain = domains[i]); i++) {
        const transformer = domain in transformers ? transformers[domain] : transformers['default'];
        const prefix = domain in prefixes ? prefixes[domain] : prefixes['default'];
        MathCompoundStore.defineRule(domain, 'default', unicode, combiner(transformer(letter), font, prefix));
    }
}
