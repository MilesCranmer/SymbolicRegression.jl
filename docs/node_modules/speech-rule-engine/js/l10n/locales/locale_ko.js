"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ko = ko;
const grammar_js_1 = require("../../rule_engine/grammar.js");
const locale_js_1 = require("../locale.js");
const locale_util_js_1 = require("../locale_util.js");
const numbers_ko_js_1 = require("../numbers/numbers_ko.js");
const tr = require("../transformers.js");
let locale = null;
function ko() {
    if (!locale) {
        locale = create();
    }
    return locale;
}
function create() {
    const loc = (0, locale_js_1.createLocale)();
    loc.NUMBERS = numbers_ko_js_1.NUMBERS;
    loc.FUNCTIONS.radicalNestDepth = locale_util_js_1.nestingToString;
    loc.FUNCTIONS.plural = function (unit) {
        return unit;
    };
    loc.FUNCTIONS.si = (prefix, unit) => {
        return prefix + unit;
    };
    loc.FUNCTIONS.combineRootIndex = function (index, postfix) {
        return index + postfix;
    };
    loc.ALPHABETS.combiner = tr.Combiners.prefixCombiner;
    loc.ALPHABETS.digitTrans.default = numbers_ko_js_1.NUMBERS.numberToWords;
    loc.CORRECTIONS.postposition = (name) => {
        if (['같다', '는', '와', '를', '로'].includes(name))
            return name;
        const char = name.slice(-1);
        const value = (char.charCodeAt(0) - 44032) % 28;
        let final = value > 0 ? true : false;
        if (char.match(/[r,l,n,m,1,3,6,7,8,0]/i))
            final = true;
        grammar_js_1.Grammar.getInstance().setParameter('final', final);
        return name;
    };
    loc.CORRECTIONS.article = (name) => {
        const final = grammar_js_1.Grammar.getInstance().getParameter('final');
        if (final)
            grammar_js_1.Grammar.getInstance().setParameter('final', false);
        if (name === '같다')
            name = '는';
        const temp = { 는: '은', 와: '과', 를: '을', 로: '으로' }[name];
        return temp !== undefined && final ? temp : name;
    };
    return loc;
}
