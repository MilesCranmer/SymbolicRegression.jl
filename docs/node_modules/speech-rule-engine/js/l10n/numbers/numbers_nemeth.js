"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.NUMBERS = void 0;
const messages_js_1 = require("../messages.js");
function numberToWords(num) {
    const digits = num.toString().split('');
    return digits
        .map(function (digit) {
        return exports.NUMBERS.ones[parseInt(digit, 10)];
    })
        .join('');
}
exports.NUMBERS = (0, messages_js_1.NUMBERS)({
    numberToWords: numberToWords,
    numberToOrdinal: numberToWords
});
