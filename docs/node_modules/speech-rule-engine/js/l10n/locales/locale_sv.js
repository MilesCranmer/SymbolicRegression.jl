"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.sv = sv;
const locale_js_1 = require("../locale.js");
const locale_util_js_1 = require("../locale_util.js");
const numbers_sv_js_1 = require("../numbers/numbers_sv.js");
const tr = require("../transformers.js");
let locale = null;
function sv() {
    if (!locale) {
        locale = create();
    }
    return locale;
}
function create() {
    const loc = (0, locale_js_1.createLocale)();
    loc.NUMBERS = numbers_sv_js_1.NUMBERS;
    loc.FUNCTIONS.radicalNestDepth = locale_util_js_1.nestingToString;
    loc.FUNCTIONS.fontRegexp = function (font) {
        return new RegExp('((^' + font + ' )|( ' + font + '$))');
    };
    loc.ALPHABETS.combiner = tr.Combiners.prefixCombiner;
    loc.ALPHABETS.digitTrans.default = numbers_sv_js_1.NUMBERS.numberToWords;
    loc.CORRECTIONS.correctOne = (num) => num.replace(/^ett$/, 'en');
    return loc;
}
