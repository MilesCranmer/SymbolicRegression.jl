"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.fr = fr;
const grammar_js_1 = require("../../rule_engine/grammar.js");
const locale_js_1 = require("../locale.js");
const locale_util_js_1 = require("../locale_util.js");
const numbers_fr_js_1 = require("../numbers/numbers_fr.js");
const transformers_js_1 = require("../transformers.js");
let locale = null;
function fr() {
    if (!locale) {
        locale = create();
    }
    return locale;
}
function create() {
    const loc = (0, locale_js_1.createLocale)();
    loc.NUMBERS = numbers_fr_js_1.NUMBERS;
    loc.FUNCTIONS.radicalNestDepth = locale_util_js_1.nestingToString;
    loc.FUNCTIONS.combineRootIndex = locale_util_js_1.combinePostfixIndex;
    loc.FUNCTIONS.combineNestedFraction = (a, b, c) => c.replace(/ $/g, '') + b + a;
    loc.FUNCTIONS.combineNestedRadical = (a, _b, c) => c + ' ' + a;
    loc.FUNCTIONS.fontRegexp = (font) => RegExp(' (en |)' + font + '$');
    loc.FUNCTIONS.plural = (unit) => {
        return /.*s$/.test(unit) ? unit : unit + 's';
    };
    loc.CORRECTIONS.article = (name) => {
        return grammar_js_1.Grammar.getInstance().getParameter('noArticle') ? '' : name;
    };
    loc.ALPHABETS.combiner = transformers_js_1.Combiners.romanceCombiner;
    loc.SUBISO = {
        default: 'fr',
        current: 'fr',
        all: ['fr', 'be', 'ch']
    };
    return loc;
}
