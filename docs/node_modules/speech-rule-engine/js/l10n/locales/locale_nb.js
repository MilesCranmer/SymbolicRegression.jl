"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.nb = nb;
const locale_js_1 = require("../locale.js");
const locale_util_js_1 = require("../locale_util.js");
const numbers_nn_js_1 = require("../numbers/numbers_nn.js");
const tr = require("../transformers.js");
let locale = null;
function nb() {
    if (!locale) {
        locale = create();
    }
    return locale;
}
function create() {
    const loc = (0, locale_js_1.createLocale)();
    loc.NUMBERS = numbers_nn_js_1.NUMBERS;
    loc.ALPHABETS.combiner = tr.Combiners.prefixCombiner;
    loc.ALPHABETS.digitTrans.default = numbers_nn_js_1.NUMBERS.numberToWords;
    loc.FUNCTIONS.radicalNestDepth = locale_util_js_1.nestingToString;
    return loc;
}
