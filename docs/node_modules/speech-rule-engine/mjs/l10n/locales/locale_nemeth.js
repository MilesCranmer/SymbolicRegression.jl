import { createLocale } from '../locale.js';
import { NUMBERS } from '../numbers/numbers_nemeth.js';
import { identityTransformer } from '../transformers.js';
const simpleEnglish = function (letter) {
    return letter.match(RegExp('^' + locale.ALPHABETS.languagePrefix.english))
        ? letter.slice(1)
        : letter;
};
const postfixCombiner = function (letter, font, _number) {
    letter = simpleEnglish(letter);
    return font ? letter + font : letter;
};
const germanCombiner = function (letter, font, _cap) {
    return font + simpleEnglish(letter);
};
const embellishCombiner = function (letter, font, num) {
    letter = simpleEnglish(letter);
    return font + (num ? num : '') + letter + '⠻';
};
const doubleEmbellishCombiner = function (letter, font, num) {
    letter = simpleEnglish(letter);
    return font + (num ? num : '') + letter + '⠻⠻';
};
const parensCombiner = function (letter, font, _number) {
    letter = simpleEnglish(letter);
    return font + letter + '⠾';
};
let locale = null;
export function nemeth() {
    if (!locale) {
        locale = create();
    }
    return locale;
}
function create() {
    const loc = createLocale();
    loc.NUMBERS = NUMBERS;
    loc.COMBINERS = {
        postfixCombiner: postfixCombiner,
        germanCombiner: germanCombiner,
        embellishCombiner: embellishCombiner,
        doubleEmbellishCombiner: doubleEmbellishCombiner,
        parensCombiner: parensCombiner
    };
    loc.FUNCTIONS.fracNestDepth = (_node) => false;
    loc.FUNCTIONS.fontRegexp = (font) => RegExp('^' + font);
    loc.FUNCTIONS.si = identityTransformer;
    loc.ALPHABETS.combiner = (letter, font, num) => {
        return font ? font + num + letter : simpleEnglish(letter);
    };
    loc.ALPHABETS.digitTrans = { default: NUMBERS.numberToWords };
    return loc;
}
