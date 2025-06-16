"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.en = en;
const grammar_js_1 = require("../../rule_engine/grammar.js");
const locale_js_1 = require("../locale.js");
const locale_util_js_1 = require("../locale_util.js");
const numbers_en_js_1 = require("../numbers/numbers_en.js");
const tr = require("../transformers.js");
let locale = null;
function en() {
    if (!locale) {
        locale = create();
    }
    return locale;
}
function create() {
    const loc = (0, locale_js_1.createLocale)();
    loc.NUMBERS = numbers_en_js_1.NUMBERS;
    loc.FUNCTIONS.radicalNestDepth = locale_util_js_1.nestingToString;
    loc.FUNCTIONS.plural = (unit) => {
        return /.*s$/.test(unit) ? unit : unit + 's';
    };
    loc.ALPHABETS.combiner = tr.Combiners.prefixCombiner;
    loc.ALPHABETS.digitTrans.default = numbers_en_js_1.NUMBERS.numberToWords;
    loc.CORRECTIONS.article = (name) => {
        return grammar_js_1.Grammar.getInstance().getParameter('noArticle') ? '' : name;
    };
    return loc;
}
