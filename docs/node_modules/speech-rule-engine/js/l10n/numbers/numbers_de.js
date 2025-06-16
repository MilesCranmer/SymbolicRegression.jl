"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.NUMBERS = void 0;
const messages_js_1 = require("../messages.js");
function onePrefix_(num, mill = false) {
    return num === exports.NUMBERS.ones[1] ? (mill ? 'eine' : 'ein') : num;
}
function hundredsToWords_(num) {
    let n = num % 1000;
    let str = '';
    let ones = exports.NUMBERS.ones[Math.floor(n / 100)];
    str += ones ? onePrefix_(ones) + 'hundert' : '';
    n = n % 100;
    if (n) {
        str += str ? exports.NUMBERS.numSep : '';
        ones = exports.NUMBERS.ones[n];
        if (ones) {
            str += ones;
        }
        else {
            const tens = exports.NUMBERS.tens[Math.floor(n / 10)];
            ones = exports.NUMBERS.ones[n % 10];
            str += ones ? onePrefix_(ones) + 'und' + tens : tens;
        }
    }
    return str;
}
function numberToWords(num) {
    if (num === 0) {
        return exports.NUMBERS.zero;
    }
    if (num >= Math.pow(10, 36)) {
        return num.toString();
    }
    let pos = 0;
    let str = '';
    while (num > 0) {
        const hundreds = num % 1000;
        if (hundreds) {
            const hund = hundredsToWords_(num % 1000);
            if (pos) {
                const large = exports.NUMBERS.large[pos];
                const plural = pos > 1 && hundreds > 1 ? (large.match(/e$/) ? 'n' : 'en') : '';
                str = onePrefix_(hund, pos > 1) + large + plural + str;
            }
            else {
                str = onePrefix_(hund, pos > 1) + str;
            }
        }
        num = Math.floor(num / 1000);
        pos++;
    }
    return str.replace(/ein$/, 'eins');
}
function numberToOrdinal(num, plural) {
    if (num === 1) {
        return 'eintel';
    }
    if (num === 2) {
        return plural ? 'halbe' : 'halb';
    }
    return wordOrdinal(num) + 'l';
}
function wordOrdinal(num) {
    if (num === 1) {
        return 'erste';
    }
    if (num === 3) {
        return 'dritte';
    }
    if (num === 7) {
        return 'siebte';
    }
    if (num === 8) {
        return 'achte';
    }
    const ordinal = numberToWords(num);
    return ordinal + (num < 19 ? 'te' : 'ste');
}
function numericOrdinal(num) {
    return num.toString() + '.';
}
exports.NUMBERS = (0, messages_js_1.NUMBERS)({
    wordOrdinal: wordOrdinal,
    numericOrdinal: numericOrdinal,
    numberToWords: numberToWords,
    numberToOrdinal: numberToOrdinal
});
