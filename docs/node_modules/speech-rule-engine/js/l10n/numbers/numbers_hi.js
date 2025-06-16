"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.NUMBERS = void 0;
const grammar_js_1 = require("../../rule_engine/grammar.js");
const messages_js_1 = require("../messages.js");
function hundredsToWords_(num) {
    let n = num % 1000;
    let str = '';
    str += exports.NUMBERS.ones[Math.floor(n / 100)]
        ? exports.NUMBERS.ones[Math.floor(n / 100)] +
            exports.NUMBERS.numSep +
            exports.NUMBERS.special.hundred
        : '';
    n = n % 100;
    if (n) {
        str += str ? exports.NUMBERS.numSep : '';
        str += exports.NUMBERS.ones[n];
    }
    return str;
}
function numberToWords(num) {
    if (num === 0) {
        return exports.NUMBERS.zero;
    }
    if (num >= Math.pow(10, 32)) {
        return num.toString();
    }
    let pos = 0;
    let str = '';
    const hundreds = num % 1000;
    const hundredsWords = hundredsToWords_(hundreds);
    num = Math.floor(num / 1000);
    if (!num) {
        return hundredsWords;
    }
    while (num > 0) {
        const thousands = num % 100;
        if (thousands) {
            str =
                exports.NUMBERS.ones[thousands] +
                    exports.NUMBERS.numSep +
                    exports.NUMBERS.large[pos] +
                    (str ? exports.NUMBERS.numSep + str : '');
        }
        num = Math.floor(num / 100);
        pos++;
    }
    return hundredsWords ? str + exports.NUMBERS.numSep + hundredsWords : str;
}
function numberToOrdinal(num, _plural) {
    if (num <= 10) {
        return exports.NUMBERS.special.smallDenominators[num];
    }
    return wordOrdinal(num) + ' अंश';
}
function wordOrdinal(num) {
    const gender = grammar_js_1.Grammar.getInstance().getParameter('gender');
    if (num <= 0) {
        return num.toString();
    }
    if (num < 10) {
        return gender === 'f'
            ? exports.NUMBERS.special.ordinalsFeminine[num]
            : exports.NUMBERS.special.ordinalsMasculine[num];
    }
    const ordinal = numberToWords(num);
    return ordinal + (gender === 'f' ? 'वीं' : 'वाँ');
}
function numericOrdinal(num) {
    const gender = grammar_js_1.Grammar.getInstance().getParameter('gender');
    if (num > 0 && num < 10) {
        return gender === 'f'
            ? exports.NUMBERS.special.simpleSmallOrdinalsFeminine[num]
            : exports.NUMBERS.special.simpleSmallOrdinalsMasculine[num];
    }
    const ordinal = num
        .toString()
        .split('')
        .map(function (x) {
        const num = parseInt(x, 10);
        return isNaN(num) ? '' : exports.NUMBERS.special.simpleNumbers[num];
    })
        .join('');
    return ordinal + (gender === 'f' ? 'वीं' : 'वाँ');
}
exports.NUMBERS = (0, messages_js_1.NUMBERS)({
    wordOrdinal: wordOrdinal,
    numericOrdinal: numericOrdinal,
    numberToWords: numberToWords,
    numberToOrdinal: numberToOrdinal
});
