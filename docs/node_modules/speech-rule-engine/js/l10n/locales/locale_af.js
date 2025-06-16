"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.af = af;
const grammar_js_1 = require("../../rule_engine/grammar.js");
const locale_util_js_1 = require("../locale_util.js");
const locale_js_1 = require("../locale.js");
const numbers_af_js_1 = require("../numbers/numbers_af.js");
const tr = require("../transformers.js");
const germanPostfixCombiner = function (letter, font, cap) {
    letter = !cap ? letter : cap + ' ' + letter;
    return font ? letter + ' ' + font : letter;
};
let locale = null;
function af() {
    if (!locale) {
        locale = create();
    }
    return locale;
}
function create() {
    const loc = (0, locale_js_1.createLocale)();
    loc.NUMBERS = numbers_af_js_1.NUMBERS;
    loc.COMBINERS['germanPostfix'] = germanPostfixCombiner;
    loc.FUNCTIONS.radicalNestDepth = locale_util_js_1.nestingToString;
    loc.FUNCTIONS.plural = (unit) => {
        return /.*s$/.test(unit) ? unit : unit + 's';
    };
    loc.FUNCTIONS.fontRegexp = function (font) {
        return new RegExp('((^' + font + ' )|( ' + font + '$))');
    };
    loc.ALPHABETS.combiner = tr.Combiners.prefixCombiner;
    loc.ALPHABETS.digitTrans.default = numbers_af_js_1.NUMBERS.numberToWords;
    loc.CORRECTIONS.article = (name) => {
        return grammar_js_1.Grammar.getInstance().getParameter('noArticle') ? '' : name;
    };
    return loc;
}
