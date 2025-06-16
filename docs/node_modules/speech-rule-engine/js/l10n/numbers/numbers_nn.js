"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.NUMBERS = void 0;
const engine_js_1 = require("../../common/engine.js");
const messages_js_1 = require("../messages.js");
function hundredsToWordsRo_(num, ordinal = false) {
    let n = num % 1000;
    let str = '';
    const count = Math.floor(n / 100);
    const ones = exports.NUMBERS.ones[count];
    str += ones ? (count === 1 ? '' : ones) + 'hundre' : '';
    n = n % 100;
    if (n) {
        str += str ? 'og' : '';
        if (ordinal) {
            const ord = exports.NUMBERS.special.smallOrdinals[n];
            if (ord) {
                return str + ord;
            }
            if (n % 10) {
                return (str +
                    exports.NUMBERS.tens[Math.floor(n / 10)] +
                    exports.NUMBERS.special.smallOrdinals[n % 10]);
            }
        }
        str +=
            exports.NUMBERS.ones[n] ||
                exports.NUMBERS.tens[Math.floor(n / 10)] + (n % 10 ? exports.NUMBERS.ones[n % 10] : '');
    }
    return ordinal ? replaceOrdinal(str) : str;
}
function numberToWordsRo(num, ordinal = false) {
    if (num === 0) {
        return ordinal ? exports.NUMBERS.special.smallOrdinals[0] : exports.NUMBERS.zero;
    }
    if (num >= Math.pow(10, 36)) {
        return num.toString();
    }
    let pos = 0;
    let str = '';
    while (num > 0) {
        const hundreds = num % 1000;
        if (hundreds) {
            const hund = hundredsToWordsRo_(num % 1000, pos ? false : ordinal);
            if (!pos && ordinal) {
                ordinal = !ordinal;
            }
            str =
                hund +
                    (pos
                        ? ' ' +
                            (exports.NUMBERS.large[pos] + (pos > 1 && hundreds > 1 ? 'er' : '')) +
                            (str ? ' ' : '')
                        : '') +
                    str;
        }
        num = Math.floor(num / 1000);
        pos++;
    }
    return ordinal ? str + (str.match(/tusen$/) ? 'de' : 'te') : str;
}
function numberToOrdinal(num, _plural) {
    return wordOrdinal(num);
}
function replaceOrdinal(str) {
    const letOne = exports.NUMBERS.special.endOrdinal[0];
    if (letOne === 'a' && str.match(/en$/)) {
        return str.slice(0, -2) + exports.NUMBERS.special.endOrdinal;
    }
    if (str.match(/(d|n)$/) || str.match(/hundre$/)) {
        return str + 'de';
    }
    if (str.match(/i$/)) {
        return str + exports.NUMBERS.special.endOrdinal;
    }
    if (letOne === 'a' && str.match(/e$/)) {
        return str.slice(0, -1) + exports.NUMBERS.special.endOrdinal;
    }
    if (str.match(/e$/)) {
        return str + 'nde';
    }
    return str + 'nde';
}
function wordOrdinal(num) {
    const ordinal = numberToWords(num, true);
    return ordinal;
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
function onePrefix_(num, thd = false) {
    const numOne = exports.NUMBERS.ones[1];
    return num === numOne ? (num === 'ein' ? 'eitt ' : thd ? 'et' : 'ett') : num;
}
function hundredsToWordsGe_(num, ordinal = false) {
    let n = num % 1000;
    let str = '';
    let ones = exports.NUMBERS.ones[Math.floor(n / 100)];
    str += ones ? onePrefix_(ones) + 'hundre' : '';
    n = n % 100;
    if (n) {
        str += str ? 'og' : '';
        if (ordinal) {
            const ord = exports.NUMBERS.special.smallOrdinals[n];
            if (ord) {
                return (str += ord);
            }
        }
        ones = exports.NUMBERS.ones[n];
        if (ones) {
            str += ones;
        }
        else {
            const tens = exports.NUMBERS.tens[Math.floor(n / 10)];
            ones = exports.NUMBERS.ones[n % 10];
            str += ones ? ones + 'og' + tens : tens;
        }
    }
    return ordinal ? replaceOrdinal(str) : str;
}
function numberToWordsGe(num, ordinal = false) {
    if (num === 0) {
        return ordinal ? exports.NUMBERS.special.smallOrdinals[0] : exports.NUMBERS.zero;
    }
    if (num >= Math.pow(10, 36)) {
        return num.toString();
    }
    let pos = 0;
    let str = '';
    while (num > 0) {
        const hundreds = num % 1000;
        if (hundreds) {
            const hund = hundredsToWordsGe_(num % 1000, pos ? false : ordinal);
            if (!pos && ordinal) {
                ordinal = !ordinal;
            }
            str =
                (pos === 1 ? onePrefix_(hund, true) : hund) +
                    (pos > 1 ? exports.NUMBERS.numSep : '') +
                    (pos
                        ?
                            exports.NUMBERS.large[pos] + (pos > 1 && hundreds > 1 ? 'er' : '')
                        : '') +
                    (pos > 1 && str ? exports.NUMBERS.numSep : '') +
                    str;
        }
        num = Math.floor(num / 1000);
        pos++;
    }
    return ordinal ? str + (str.match(/tusen$/) ? 'de' : 'te') : str;
}
function numberToWords(num, ordinal = false) {
    const word = engine_js_1.Engine.getInstance().subiso === 'alt'
        ? numberToWordsGe(num, ordinal)
        : numberToWordsRo(num, ordinal);
    return word;
}
