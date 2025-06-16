import { createLocale } from '../locale.js';
import { combinePostfixIndex } from '../locale_util.js';
import { NUMBERS } from '../numbers/numbers_es.js';
import { Combiners } from '../transformers.js';
const sansserifCombiner = function (letter, font, cap) {
    letter = 'sans serif ' + (cap ? cap + ' ' + letter : letter);
    return font ? letter + ' ' + font : letter;
};
let locale = null;
export function es() {
    if (!locale) {
        locale = create();
    }
    return locale;
}
function create() {
    const loc = createLocale();
    loc.NUMBERS = NUMBERS;
    loc.COMBINERS['sansserif'] = sansserifCombiner;
    loc.FUNCTIONS.fracNestDepth = (_node) => false;
    loc.FUNCTIONS.combineRootIndex = combinePostfixIndex;
    loc.FUNCTIONS.combineNestedRadical = (a, _b, c) => a + c;
    loc.FUNCTIONS.fontRegexp = (font) => RegExp('^' + font + ' ');
    loc.FUNCTIONS.plural = (unit) => {
        if (/.*(a|e|i|o|u)$/.test(unit)) {
            return unit + 's';
        }
        if (/.*z$/.test(unit)) {
            return unit.slice(0, -1) + 'ces';
        }
        if (/.*c$/.test(unit)) {
            return unit.slice(0, -1) + 'ques';
        }
        if (/.*g$/.test(unit)) {
            return unit + 'ues';
        }
        if (/.*\u00f3n$/.test(unit)) {
            return unit.slice(0, -2) + 'ones';
        }
        return unit + 'es';
    };
    loc.FUNCTIONS.si = (prefix, unit) => {
        if (unit.match(/^metro/)) {
            prefix = prefix.replace(/a$/, 'á').replace(/o$/, 'ó').replace(/i$/, 'í');
        }
        return prefix + unit;
    };
    loc.ALPHABETS.combiner = Combiners.prefixCombiner;
    return loc;
}
