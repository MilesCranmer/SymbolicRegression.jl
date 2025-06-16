"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.da = da;
const locale_js_1 = require("../locale.js");
const locale_util_js_1 = require("../locale_util.js");
const numbers_da_js_1 = require("../numbers/numbers_da.js");
const tr = require("../transformers.js");
let locale = null;
function da() {
    if (!locale) {
        locale = create();
    }
    return locale;
}
function create() {
    const loc = (0, locale_js_1.createLocale)();
    loc.NUMBERS = numbers_da_js_1.NUMBERS;
    loc.FUNCTIONS.radicalNestDepth = locale_util_js_1.nestingToString;
    loc.FUNCTIONS.fontRegexp = (font) => {
        return font === loc.ALPHABETS.capPrefix['default']
            ? RegExp('^' + font + ' ')
            : RegExp(' ' + font + '$');
    };
    loc.ALPHABETS.combiner = tr.Combiners.postfixCombiner;
    loc.ALPHABETS.digitTrans.default = numbers_da_js_1.NUMBERS.numberToWords;
    return loc;
}
