"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.NUMBERS = void 0;
const grammar_js_1 = require("../../rule_engine/grammar.js");
const messages_js_1 = require("../messages.js");
function hundredsToWords_(num) {
    let n = num % 1000;
    let str = '';
    str += exports.NUMBERS.ones[Math.floor(n / 100)]
        ? exports.NUMBERS.ones[Math.floor(n / 100)] + exports.NUMBERS.numSep + 'cento'
        : '';
    n = n % 100;
    if (n) {
        str += str ? exports.NUMBERS.numSep : '';
        const ones = exports.NUMBERS.ones[n];
        if (ones) {
            str += ones;
        }
        else {
            let tens = exports.NUMBERS.tens[Math.floor(n / 10)];
            const rest = n % 10;
            if (rest === 1 || rest === 8) {
                tens = tens.slice(0, -1);
            }
            str += tens;
            str += rest ? exports.NUMBERS.numSep + exports.NUMBERS.ones[n % 10] : '';
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
    if (num === 1 && grammar_js_1.Grammar.getInstance().getParameter('fraction')) {
        return 'un';
    }
    let pos = 0;
    let str = '';
    while (num > 0) {
        const hundreds = num % 1000;
        if (hundreds) {
            str =
                hundredsToWords_(num % 1000) +
                    (pos ? '-' + exports.NUMBERS.large[pos] + '-' : '') +
                    str;
        }
        num = Math.floor(num / 1000);
        pos++;
    }
    return str.replace(/-$/, '');
}
function numberToOrdinal(num, plural) {
    if (num === 2) {
        return plural ? 'mezzi' : 'mezzo';
    }
    const ordinal = wordOrdinal(num);
    if (!plural) {
        return ordinal;
    }
    const gender = ordinal.match(/o$/) ? 'i' : 'e';
    return ordinal.slice(0, -1) + gender;
}
function wordOrdinal(num) {
    const gender = grammar_js_1.Grammar.getInstance().getParameter('gender');
    const postfix = gender === 'm' ? 'o' : 'a';
    let ordinal = exports.NUMBERS.special.onesOrdinals[num];
    if (ordinal) {
        return ordinal.slice(0, -1) + postfix;
    }
    ordinal = numberToWords(num);
    return ordinal.slice(0, -1) + 'esim' + postfix;
}
function numericOrdinal(num) {
    const gender = grammar_js_1.Grammar.getInstance().getParameter('gender');
    return num.toString() + (gender === 'm' ? 'o' : 'a');
}
exports.NUMBERS = (0, messages_js_1.NUMBERS)({
    wordOrdinal: wordOrdinal,
    numericOrdinal: numericOrdinal,
    numberToWords: numberToWords,
    numberToOrdinal: numberToOrdinal
});
