import * as tr from './transformers.js';
export function MESSAGES() {
    return {
        MS: {},
        MSroots: {},
        font: {},
        embellish: {},
        role: {},
        enclose: {},
        navigate: {},
        regexp: {},
        unitTimes: ''
    };
}
export function NUMBERS(numbers = {}) {
    return Object.assign({
        zero: 'zero',
        ones: [],
        tens: [],
        large: [],
        special: {},
        wordOrdinal: tr.identityTransformer,
        numericOrdinal: tr.identityTransformer,
        numberToWords: tr.identityTransformer,
        numberToOrdinal: tr.pluralCase,
        vulgarSep: ' ',
        numSep: ' '
    }, numbers);
}
export function ALPHABETS() {
    return {
        latinSmall: [],
        latinCap: [],
        greekSmall: [],
        greekCap: [],
        capPrefix: { default: '' },
        smallPrefix: { default: '' },
        digitPrefix: { default: '' },
        languagePrefix: {},
        digitTrans: {
            default: tr.identityTransformer,
            mathspeak: tr.identityTransformer,
            clearspeak: tr.identityTransformer
        },
        letterTrans: { default: tr.identityTransformer },
        combiner: (letter, _font, _cap) => {
            return letter;
        }
    };
}
export function FUNCTIONS() {
    return {
        fracNestDepth: (n) => tr.vulgarFractionSmall(n, 10, 100),
        radicalNestDepth: (_count) => '',
        combineRootIndex: function (postfix, _index) {
            return postfix;
        },
        combineNestedFraction: tr.Combiners.identityCombiner,
        combineNestedRadical: tr.Combiners.identityCombiner,
        fontRegexp: function (font) {
            return new RegExp('^' + font.split(/ |-/).join('( |-)') + '( |-)');
        },
        si: tr.siCombiner,
        plural: tr.identityTransformer
    };
}
export function SUBISO() {
    return {
        default: '',
        current: '',
        all: []
    };
}
