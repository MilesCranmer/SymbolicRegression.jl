import { createLocale } from '../locale.js';
import { NUMBERS } from '../numbers/numbers_hi.js';
import { Combiners } from '../transformers.js';
import { nestingToString } from '../locale_util.js';
let locale = null;
export function hi() {
    if (!locale) {
        locale = create();
    }
    return locale;
}
function create() {
    const loc = createLocale();
    loc.NUMBERS = NUMBERS;
    loc.ALPHABETS.combiner = Combiners.prefixCombiner;
    loc.FUNCTIONS.radicalNestDepth = nestingToString;
    return loc;
}
