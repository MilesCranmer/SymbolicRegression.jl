"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.es = es;
const locale_js_1 = require("../locale.js");
const locale_util_js_1 = require("../locale_util.js");
const numbers_es_js_1 = require("../numbers/numbers_es.js");
const transformers_js_1 = require("../transformers.js");
const sansserifCombiner = function (letter, font, cap) {
    letter = 'sans serif ' + (cap ? cap + ' ' + letter : letter);
    return font ? letter + ' ' + font : letter;
};
let locale = null;
function es() {
    if (!locale) {
        locale = create();
    }
    return locale;
}
function create() {
    const loc = (0, locale_js_1.createLocale)();
    loc.NUMBERS = numbers_es_js_1.NUMBERS;
    loc.COMBINERS['sansserif'] = sansserifCombiner;
    loc.FUNCTIONS.fracNestDepth = (_node) => false;
    loc.FUNCTIONS.combineRootIndex = locale_util_js_1.combinePostfixIndex;
    loc.FUNCTIONS.combineNestedRadical = (a, _b, c) => a + c;
    loc.FUNCTIONS.fontRegexp = (font) => RegExp('^' + font + ' ');
    loc.FUNCTIONS.plural = (unit) => {
        if (/.*(a|e|i|o|u)$/.test(unit)) {
            return unit + 's';
        }
        if (/.*z$/.test(unit)) {
            return unit.slice(0, -1) + 'ces';
        }
        if (/.*c$/.test(unit)) {
            return unit.slice(0, -1) + 'ques';
        }
        if (/.*g$/.test(unit)) {
            return unit + 'ues';
        }
        if (/.*\u00f3n$/.test(unit)) {
            return unit.slice(0, -2) + 'ones';
        }
        return unit + 'es';
    };
    loc.FUNCTIONS.si = (prefix, unit) => {
        if (unit.match(/^metro/)) {
            prefix = prefix.replace(/a$/, 'á').replace(/o$/, 'ó').replace(/i$/, 'í');
        }
        return prefix + unit;
    };
    loc.ALPHABETS.combiner = transformers_js_1.Combiners.prefixCombiner;
    return loc;
}
