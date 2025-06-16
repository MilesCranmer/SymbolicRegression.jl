import { Grammar } from '../../rule_engine/grammar.js';
import { createLocale } from '../locale.js';
import { nestingToString } from '../locale_util.js';
import { NUMBERS } from '../numbers/numbers_en.js';
import * as tr from '../transformers.js';
let locale = null;
export function en() {
    if (!locale) {
        locale = create();
    }
    return locale;
}
function create() {
    const loc = createLocale();
    loc.NUMBERS = NUMBERS;
    loc.FUNCTIONS.radicalNestDepth = nestingToString;
    loc.FUNCTIONS.plural = (unit) => {
        return /.*s$/.test(unit) ? unit : unit + 's';
    };
    loc.ALPHABETS.combiner = tr.Combiners.prefixCombiner;
    loc.ALPHABETS.digitTrans.default = NUMBERS.numberToWords;
    loc.CORRECTIONS.article = (name) => {
        return Grammar.getInstance().getParameter('noArticle') ? '' : name;
    };
    return loc;
}
