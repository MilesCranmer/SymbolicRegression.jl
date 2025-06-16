import * as Alphabet from './alphabet.js';
import { Engine } from '../common/engine.js';
import * as L10n from '../l10n/l10n.js';
import { LOCALE } from '../l10n/locale.js';
import { localeFontCombiner } from '../l10n/locale_util.js';
import * as MathCompoundStore from '../rule_engine/math_compound_store.js';
const Domains = {
    small: ['default'],
    capital: ['default'],
    digit: ['default']
};
function makeDomains() {
    const alph = LOCALE.ALPHABETS;
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
export function generateBase() {
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
export function generate(locale) {
    const oldLocale = Engine.getInstance().locale;
    Engine.getInstance().locale = locale;
    L10n.setLocale();
    MathCompoundStore.changeLocale({ locale: locale });
    makeDomains();
    for (const int of Alphabet.INTERVALS.values()) {
        const letters = int.unicode;
        if ('offset' in int) {
            numberRules(letters, int.font, int.offset || 0);
        }
        else {
            const alphabet = LOCALE.ALPHABETS[int.base];
            alphabetRules(letters, alphabet, int.font, !!int.capital);
        }
    }
    Engine.getInstance().locale = oldLocale;
    L10n.setLocale();
}
function getFont(font) {
    const realFont = font === 'normal' || font === 'fullwidth'
        ? ''
        : LOCALE.MESSAGES.font[font] || LOCALE.MESSAGES.embellish[font] || '';
    return localeFontCombiner(realFont);
}
function alphabetRules(unicodes, letters, font, cap) {
    const realFont = getFont(font);
    for (let i = 0, unicode, letter; (unicode = unicodes[i]), (letter = letters[i]); i++) {
        const prefixes = cap
            ? LOCALE.ALPHABETS.capPrefix
            : LOCALE.ALPHABETS.smallPrefix;
        const domains = cap ? Domains.capital : Domains.small;
        makeLetter(realFont.combiner, unicode, letter, realFont.font, prefixes, LOCALE.ALPHABETS.letterTrans, domains);
    }
}
function numberRules(unicodes, font, offset) {
    const realFont = getFont(font);
    for (let i = 0, unicode; (unicode = unicodes[i]); i++) {
        const prefixes = LOCALE.ALPHABETS.digitPrefix;
        const num = i + offset;
        makeLetter(realFont.combiner, unicode, num, realFont.font, prefixes, LOCALE.ALPHABETS.digitTrans, Domains.digit);
    }
}
function makeLetter(combiner, unicode, letter, font, prefixes, transformers, domains) {
    for (let i = 0, domain; (domain = domains[i]); i++) {
        const transformer = domain in transformers ? transformers[domain] : transformers['default'];
        const prefix = domain in prefixes ? prefixes[domain] : prefixes['default'];
        MathCompoundStore.defineRule(domain, 'default', unicode, combiner(transformer(letter), font, prefix));
    }
}
