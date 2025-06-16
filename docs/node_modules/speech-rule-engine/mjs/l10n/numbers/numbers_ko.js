import { NUMBERS as NUMB } from '../messages.js';
function thousandsToWords_(num) {
    let n = num % 10000;
    let str = '';
    str += NUMBERS.ones[Math.floor(n / 1000)]
        ? Math.floor(n / 1000) === 1
            ? '천'
            : NUMBERS.ones[Math.floor(n / 1000)] + '천'
        : '';
    n = n % 1000;
    if (n) {
        str += NUMBERS.ones[Math.floor(n / 100)]
            ? Math.floor(n / 100) === 1
                ? '백'
                : NUMBERS.ones[Math.floor(n / 100)] + '백'
            : '';
        n = n % 100;
        str +=
            NUMBERS.tens[Math.floor(n / 10)] + (n % 10 ? NUMBERS.ones[n % 10] : '');
    }
    return str;
}
function numberToWords(num) {
    if (num === 0)
        return NUMBERS.zero;
    if (num >= Math.pow(10, 36))
        return num.toString();
    let pos = 0;
    let str = '';
    while (num > 0) {
        const thousands = num % 10000;
        if (thousands) {
            str =
                thousandsToWords_(num % 10000) +
                    (pos ? NUMBERS.large[pos] + NUMBERS.numSep : '') +
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
    const tens = num === 20 ? '스무' : NUMBERS.tens[10 + Math.floor(num / 10)];
    const ones = NUMBERS.ones[10 + Math.floor(num % 10)];
    return ordinal.slice(0, -label.length) + tens + ones;
}
function numericOrdinal(num) {
    return numberToOrdinal(num, false);
}
export const NUMBERS = NUMB({
    wordOrdinal: wordOrdinal,
    numericOrdinal: numericOrdinal,
    numberToWords: numberToWords,
    numberToOrdinal: numberToOrdinal
});
