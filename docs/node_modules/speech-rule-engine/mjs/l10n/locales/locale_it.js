import { combinePostfixIndex, nestingToString } from '../locale_util.js';
import { createLocale } from '../locale.js';
import { NUMBERS } from '../numbers/numbers_it.js';
import { Combiners } from '../transformers.js';
const italianPostfixCombiner = function (letter, font, cap) {
    if (letter.match(/^[a-zA-Z]$/)) {
        font = font.replace('cerchiato', 'cerchiata');
    }
    letter = cap ? letter + ' ' + cap : letter;
    return font ? letter + ' ' + font : letter;
};
let locale = null;
export function it() {
    if (!locale) {
        locale = create();
    }
    return locale;
}
function create() {
    const loc = createLocale();
    loc.NUMBERS = NUMBERS;
    loc.COMBINERS['italianPostfix'] = italianPostfixCombiner;
    loc.FUNCTIONS.radicalNestDepth = nestingToString;
    loc.FUNCTIONS.combineRootIndex = combinePostfixIndex;
    loc.FUNCTIONS.combineNestedFraction = (a, b, c) => c.replace(/ $/g, '') + b + a;
    loc.FUNCTIONS.combineNestedRadical = (a, _b, c) => c + ' ' + a;
    loc.FUNCTIONS.fontRegexp = (font) => RegExp(' (en |)' + font + '$');
    loc.ALPHABETS.combiner = Combiners.romanceCombiner;
    return loc;
}
