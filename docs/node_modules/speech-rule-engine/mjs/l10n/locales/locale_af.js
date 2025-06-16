import { Grammar } from '../../rule_engine/grammar.js';
import { nestingToString } from '../locale_util.js';
import { createLocale } from '../locale.js';
import { NUMBERS } from '../numbers/numbers_af.js';
import * as tr from '../transformers.js';
const germanPostfixCombiner = function (letter, font, cap) {
    letter = !cap ? letter : cap + ' ' + letter;
    return font ? letter + ' ' + font : letter;
};
let locale = null;
export function af() {
    if (!locale) {
        locale = create();
    }
    return locale;
}
function create() {
    const loc = createLocale();
    loc.NUMBERS = NUMBERS;
    loc.COMBINERS['germanPostfix'] = germanPostfixCombiner;
    loc.FUNCTIONS.radicalNestDepth = nestingToString;
    loc.FUNCTIONS.plural = (unit) => {
        return /.*s$/.test(unit) ? unit : unit + 's';
    };
    loc.FUNCTIONS.fontRegexp = function (font) {
        return new RegExp('((^' + font + ' )|( ' + font + '$))');
    };
    loc.ALPHABETS.combiner = tr.Combiners.prefixCombiner;
    loc.ALPHABETS.digitTrans.default = NUMBERS.numberToWords;
    loc.CORRECTIONS.article = (name) => {
        return Grammar.getInstance().getParameter('noArticle') ? '' : name;
    };
    return loc;
}
