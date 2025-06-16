"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.NUMBERS = void 0;
const messages_js_1 = require("../messages.js");
function hundredsToWords_(num) {
    let n = num % 1000;
    let str = '';
    let ones = exports.NUMBERS.ones[Math.floor(n / 100)];
    str += ones ? ones + exports.NUMBERS.numSep + 'honderd' : '';
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
            str += ones ? ones + '-en-' + tens : tens;
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
                str = hund + exports.NUMBERS.numSep + large + (str ? exports.NUMBERS.numSep + str : '');
            }
            else {
                str = hund + (str ? exports.NUMBERS.numSep + str : '');
            }
        }
        num = Math.floor(num / 1000);
        pos++;
    }
    return str;
}
function numberToOrdinal(num, plural) {
    if (num === 1) {
        return 'enkel';
    }
    if (num === 2) {
        return plural ? 'helftes' : 'helfte';
    }
    if (num === 4) {
        return plural ? 'kwarte' : 'kwart';
    }
    return wordOrdinal(num) + (plural ? 's' : '');
}
function wordOrdinal(num) {
    if (num === 1) {
        return 'eerste';
    }
    if (num === 3) {
        return 'derde';
    }
    if (num === 8) {
        return 'agste';
    }
    if (num === 9) {
        return 'negende';
    }
    const ordinal = numberToWords(num);
    return ordinal + (num < 19 ? 'de' : 'ste');
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
