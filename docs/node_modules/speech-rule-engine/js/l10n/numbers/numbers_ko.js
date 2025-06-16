"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.NUMBERS = void 0;
const messages_js_1 = require("../messages.js");
function thousandsToWords_(num) {
    let n = num % 10000;
    let str = '';
    str += exports.NUMBERS.ones[Math.floor(n / 1000)]
        ? Math.floor(n / 1000) === 1
            ? '천'
            : exports.NUMBERS.ones[Math.floor(n / 1000)] + '천'
        : '';
    n = n % 1000;
    if (n) {
        str += exports.NUMBERS.ones[Math.floor(n / 100)]
            ? Math.floor(n / 100) === 1
                ? '백'
                : exports.NUMBERS.ones[Math.floor(n / 100)] + '백'
            : '';
        n = n % 100;
        str +=
            exports.NUMBERS.tens[Math.floor(n / 10)] + (n % 10 ? exports.NUMBERS.ones[n % 10] : '');
    }
    return str;
}
function numberToWords(num) {
    if (num === 0)
        return exports.NUMBERS.zero;
    if (num >= Math.pow(10, 36))
        return num.toString();
    let pos = 0;
    let str = '';
    while (num > 0) {
        const thousands = num % 10000;
        if (thousands) {
            str =
                thousandsToWords_(num % 10000) +
                    (pos ? exports.NUMBERS.large[pos] + exports.NUMBERS.numSep : '') +
                    str;
        }
        num = Math.floor(num / 10000);
        pos++;
    }
    return str.replace(/ $/, '');
}
function numberToOrdinal(num, _plural) {
    if (num === 1)
        return '첫번째';
    return wordOrdinal(num) + '번째';
}
function wordOrdinal(num) {
    const ordinal = numberToWords(num);
    num %= 100;
    const label = numberToWords(num);
    if (!label || !num)
        return ordinal;
    const tens = num === 20 ? '스무' : exports.NUMBERS.tens[10 + Math.floor(num / 10)];
    const ones = exports.NUMBERS.ones[10 + Math.floor(num % 10)];
    return ordinal.slice(0, -label.length) + tens + ones;
}
function numericOrdinal(num) {
    return numberToOrdinal(num, false);
}
exports.NUMBERS = (0, messages_js_1.NUMBERS)({
    wordOrdinal: wordOrdinal,
    numericOrdinal: numericOrdinal,
    numberToWords: numberToWords,
    numberToOrdinal: numberToOrdinal
});
