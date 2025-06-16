"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.NUMBERS = void 0;
const grammar_js_1 = require("../../rule_engine/grammar.js");
const messages_js_1 = require("../messages.js");
function tensToWords_(num) {
    const n = num % 100;
    if (n < 30) {
        return exports.NUMBERS.ones[n];
    }
    const tens = exports.NUMBERS.tens[Math.floor(n / 10)];
    const ones = exports.NUMBERS.ones[n % 10];
    return tens && ones ? tens + ' y ' + ones : tens || ones;
}
function hundredsToWords_(num) {
    const n = num % 1000;
    const hundred = Math.floor(n / 100);
    const hundreds = exports.NUMBERS.special.hundreds[hundred];
    const tens = tensToWords_(n % 100);
    if (hundred === 1) {
        if (!tens) {
            return hundreds;
        }
        return hundreds + 'to' + ' ' + tens;
    }
    return hundreds && tens ? hundreds + ' ' + tens : hundreds || tens;
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
            let large = exports.NUMBERS.large[pos];
            const huns = hundredsToWords_(hundreds);
            if (!pos) {
                str = huns;
            }
            else if (hundreds === 1) {
                large = large.match('/^mil( |$)/') ? large : 'un ' + large;
                str = large + (str ? ' ' + str : '');
            }
            else {
                large = large.replace(/\u00f3n$/, 'ones');
                str = hundredsToWords_(hundreds) + ' ' + large + (str ? ' ' + str : '');
            }
        }
        num = Math.floor(num / 1000);
        pos++;
    }
    return str;
}
function numberToOrdinal(num, _plural) {
    if (num > 1999) {
        return num.toString() + 'a';
    }
    if (num <= 12) {
        return exports.NUMBERS.special.onesOrdinals[num - 1];
    }
    const result = [];
    if (num >= 1000) {
        num = num - 1000;
        result.push('milésima');
    }
    if (!num) {
        return result.join(' ');
    }
    let pos = 0;
    pos = Math.floor(num / 100);
    if (pos > 0) {
        result.push(exports.NUMBERS.special.hundredsOrdinals[pos - 1]);
        num = num % 100;
    }
    if (num <= 12) {
        result.push(exports.NUMBERS.special.onesOrdinals[num - 1]);
    }
    else {
        pos = Math.floor(num / 10);
        if (pos > 0) {
            result.push(exports.NUMBERS.special.tensOrdinals[pos - 1]);
            num = num % 10;
        }
        if (num > 0) {
            result.push(exports.NUMBERS.special.onesOrdinals[num - 1]);
        }
    }
    return result.join(' ');
}
function numericOrdinal(num) {
    const gender = grammar_js_1.Grammar.getInstance().getParameter('gender');
    return num.toString() + (gender === 'f' ? 'a' : 'o');
}
exports.NUMBERS = (0, messages_js_1.NUMBERS)({
    numericOrdinal: numericOrdinal,
    numberToWords: numberToWords,
    numberToOrdinal: numberToOrdinal
});
