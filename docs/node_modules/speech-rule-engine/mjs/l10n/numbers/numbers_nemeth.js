import { NUMBERS as NUMB } from '../messages.js';
function numberToWords(num) {
    const digits = num.toString().split('');
    return digits
        .map(function (digit) {
        return NUMBERS.ones[parseInt(digit, 10)];
    })
        .join('');
}
export const NUMBERS = NUMB({
    numberToWords: numberToWords,
    numberToOrdinal: numberToWords
});
