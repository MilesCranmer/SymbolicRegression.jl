import { createLocale } from '../locale.js';
import { nestingToString } from '../locale_util.js';
import { NUMBERS } from '../numbers/numbers_da.js';
import * as tr from '../transformers.js';
let locale = null;
export function da() {
    if (!locale) {
        locale = create();
    }
    return locale;
}
function create() {
    const loc = createLocale();
    loc.NUMBERS = NUMBERS;
    loc.FUNCTIONS.radicalNestDepth = nestingToString;
    loc.FUNCTIONS.fontRegexp = (font) => {
        return font === loc.ALPHABETS.capPrefix['default']
            ? RegExp('^' + font + ' ')
            : RegExp(' ' + font + '$');
    };
    loc.ALPHABETS.combiner = tr.Combiners.postfixCombiner;
    loc.ALPHABETS.digitTrans.default = NUMBERS.numberToWords;
    return loc;
}
