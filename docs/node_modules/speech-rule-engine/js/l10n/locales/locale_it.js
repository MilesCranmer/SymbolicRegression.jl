"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.it = it;
const locale_util_js_1 = require("../locale_util.js");
const locale_js_1 = require("../locale.js");
const numbers_it_js_1 = require("../numbers/numbers_it.js");
const transformers_js_1 = require("../transformers.js");
const italianPostfixCombiner = function (letter, font, cap) {
    if (letter.match(/^[a-zA-Z]$/)) {
        font = font.replace('cerchiato', 'cerchiata');
    }
    letter = cap ? letter + ' ' + cap : letter;
    return font ? letter + ' ' + font : letter;
};
let locale = null;
function it() {
    if (!locale) {
        locale = create();
    }
    return locale;
}
function create() {
    const loc = (0, locale_js_1.createLocale)();
    loc.NUMBERS = numbers_it_js_1.NUMBERS;
    loc.COMBINERS['italianPostfix'] = italianPostfixCombiner;
    loc.FUNCTIONS.radicalNestDepth = locale_util_js_1.nestingToString;
    loc.FUNCTIONS.combineRootIndex = locale_util_js_1.combinePostfixIndex;
    loc.FUNCTIONS.combineNestedFraction = (a, b, c) => c.replace(/ $/g, '') + b + a;
    loc.FUNCTIONS.combineNestedRadical = (a, _b, c) => c + ' ' + a;
    loc.FUNCTIONS.fontRegexp = (font) => RegExp(' (en |)' + font + '$');
    loc.ALPHABETS.combiner = transformers_js_1.Combiners.romanceCombiner;
    return loc;
}
