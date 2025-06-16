import { createLocale } from '../locale.js';
import { nestingToString } from '../locale_util.js';
import { NUMBERS } from '../numbers/numbers_nn.js';
import * as tr from '../transformers.js';
let locale = null;
export function nn() {
    if (!locale) {
        locale = create();
    }
    return locale;
}
function create() {
    const loc = createLocale();
    loc.NUMBERS = NUMBERS;
    loc.ALPHABETS.combiner = tr.Combiners.prefixCombiner;
    loc.ALPHABETS.digitTrans.default = NUMBERS.numberToWords;
    loc.FUNCTIONS.radicalNestDepth = nestingToString;
    loc.SUBISO = {
        default: '',
        current: '',
        all: ['', 'alt']
    };
    return loc;
}
