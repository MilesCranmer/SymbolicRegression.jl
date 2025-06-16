"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.hi = hi;
const locale_js_1 = require("../locale.js");
const numbers_hi_js_1 = require("../numbers/numbers_hi.js");
const transformers_js_1 = require("../transformers.js");
const locale_util_js_1 = require("../locale_util.js");
let locale = null;
function hi() {
    if (!locale) {
        locale = create();
    }
    return locale;
}
function create() {
    const loc = (0, locale_js_1.createLocale)();
    loc.NUMBERS = numbers_hi_js_1.NUMBERS;
    loc.ALPHABETS.combiner = transformers_js_1.Combiners.prefixCombiner;
    loc.FUNCTIONS.radicalNestDepth = locale_util_js_1.nestingToString;
    return loc;
}
