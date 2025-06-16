import { createLocale } from '../locale.js';
import { combinePostfixIndex } from '../locale_util.js';
import { NUMBERS } from '../numbers/numbers_ca.js';
import { Combiners } from '../transformers.js';
const sansserifCombiner = function (letter, font, cap) {
    letter = 'sans serif ' + (cap ? cap + ' ' + letter : letter);
    return font ? letter + ' ' + font : letter;
};
let locale = null;
export function ca() {
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
        if (/.*os$/.test(unit)) {
            return unit + 'sos';
        }
        if (/.*s$/.test(unit)) {
            return unit + 'os';
        }
        if (/.*ga$/.test(unit)) {
            return unit.slice(0, -2) + 'gues';
        }
        if (/.*ça$/.test(unit)) {
            return unit.slice(0, -2) + 'ces';
        }
        if (/.*ca$/.test(unit)) {
            return unit.slice(0, -2) + 'ques';
        }
        if (/.*ja$/.test(unit)) {
            return unit.slice(0, -2) + 'ges';
        }
        if (/.*qua$/.test(unit)) {
            return unit.slice(0, -3) + 'qües';
        }
        if (/.*a$/.test(unit)) {
            return unit.slice(0, -1) + 'es';
        }
        if (/.*(e|i)$/.test(unit)) {
            return unit + 'ns';
        }
        if (/.*í$/.test(unit)) {
            return unit.slice(0, -1) + 'ins';
        }
        return unit + 's';
    };
    loc.FUNCTIONS.si = (prefix, unit) => {
        if (unit.match(/^metre/)) {
            prefix = prefix.replace(/a$/, 'à').replace(/o$/, 'ò').replace(/i$/, 'í');
        }
        return prefix + unit;
    };
    loc.ALPHABETS.combiner = Combiners.prefixCombiner;
    return loc;
}
