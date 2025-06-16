"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.MESSAGES = MESSAGES;
exports.NUMBERS = NUMBERS;
exports.ALPHABETS = ALPHABETS;
exports.FUNCTIONS = FUNCTIONS;
exports.SUBISO = SUBISO;
const tr = require("./transformers.js");
function MESSAGES() {
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
function NUMBERS(numbers = {}) {
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
function ALPHABETS() {
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
function FUNCTIONS() {
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
function SUBISO() {
    return {
        default: '',
        current: '',
        all: []
    };
}
