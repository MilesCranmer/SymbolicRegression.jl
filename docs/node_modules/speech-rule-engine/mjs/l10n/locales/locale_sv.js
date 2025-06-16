import { createLocale } from '../locale.js';
import { nestingToString } from '../locale_util.js';
import { NUMBERS } from '../numbers/numbers_sv.js';
import * as tr from '../transformers.js';
let locale = null;
export function sv() {
    if (!locale) {
        locale = create();
    }
    return locale;
}
function create() {
    const loc = createLocale();
    loc.NUMBERS = NUMBERS;
    loc.FUNCTIONS.radicalNestDepth = nestingToString;
    loc.FUNCTIONS.fontRegexp = function (font) {
        return new RegExp('((^' + font + ' )|( ' + font + '$))');
    };
    loc.ALPHABETS.combiner = tr.Combiners.prefixCombiner;
    loc.ALPHABETS.digitTrans.default = NUMBERS.numberToWords;
    loc.CORRECTIONS.correctOne = (num) => num.replace(/^ett$/, 'en');
    return loc;
}
