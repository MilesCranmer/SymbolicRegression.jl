import { Grammar } from '../../rule_engine/grammar.js';
import { createLocale } from '../locale.js';
import { combinePostfixIndex, nestingToString } from '../locale_util.js';
import { NUMBERS } from '../numbers/numbers_fr.js';
import { Combiners } from '../transformers.js';
let locale = null;
export function fr() {
    if (!locale) {
        locale = create();
    }
    return locale;
}
function create() {
    const loc = createLocale();
    loc.NUMBERS = NUMBERS;
    loc.FUNCTIONS.radicalNestDepth = nestingToString;
    loc.FUNCTIONS.combineRootIndex = combinePostfixIndex;
    loc.FUNCTIONS.combineNestedFraction = (a, b, c) => c.replace(/ $/g, '') + b + a;
    loc.FUNCTIONS.combineNestedRadical = (a, _b, c) => c + ' ' + a;
    loc.FUNCTIONS.fontRegexp = (font) => RegExp(' (en |)' + font + '$');
    loc.FUNCTIONS.plural = (unit) => {
        return /.*s$/.test(unit) ? unit : unit + 's';
    };
    loc.CORRECTIONS.article = (name) => {
        return Grammar.getInstance().getParameter('noArticle') ? '' : name;
    };
    loc.ALPHABETS.combiner = Combiners.romanceCombiner;
    loc.SUBISO = {
        default: 'fr',
        current: 'fr',
        all: ['fr', 'be', 'ch']
    };
    return loc;
}
