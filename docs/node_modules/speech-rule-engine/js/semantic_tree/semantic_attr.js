"use strict";
var __rest = (this && this.__rest) || function (s, e) {
    var t = {};
    for (var p in s) if (Object.prototype.hasOwnProperty.call(s, p) && e.indexOf(p) < 0)
        t[p] = s[p];
    if (s != null && typeof Object.getOwnPropertySymbols === "function")
        for (var i = 0, p = Object.getOwnPropertySymbols(s); i < p.length; i++) {
            if (e.indexOf(p[i]) < 0 && Object.prototype.propertyIsEnumerable.call(s, p[i]))
                t[p[i]] = s[p[i]];
        }
    return t;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.SemanticMap = exports.NamedSymbol = void 0;
exports.addFunctionSemantic = addFunctionSemantic;
exports.equal = equal;
exports.isMatchingFence = isMatchingFence;
const semantic_meaning_js_1 = require("./semantic_meaning.js");
const Alphabet = require("../speech_rules/alphabet.js");
exports.NamedSymbol = {
    functionApplication: String.fromCodePoint(0x2061),
    invisibleTimes: String.fromCodePoint(0x2062),
    invisibleComma: String.fromCodePoint(0x2063),
    invisiblePlus: String.fromCodePoint(0x2064)
};
class meaningMap extends Map {
    get(symbol) {
        return (super.get(symbol) || {
            role: semantic_meaning_js_1.SemanticRole.UNKNOWN,
            type: semantic_meaning_js_1.SemanticType.UNKNOWN,
            font: semantic_meaning_js_1.SemanticFont.UNKNOWN
        });
    }
}
class secondaryMap extends Map {
    set(char, kind, annotation = '') {
        super.set(this.secKey(kind, char), annotation || kind);
        return this;
    }
    has(char, kind) {
        return super.has(this.secKey(kind, char));
    }
    get(char, kind) {
        return super.get(this.secKey(kind, char));
    }
    secKey(kind, char) {
        return char ? `${kind} ${char}` : `${kind}`;
    }
}
exports.SemanticMap = {
    Meaning: new meaningMap(),
    Secondary: new secondaryMap(),
    FencesHoriz: new Map(),
    FencesVert: new Map(),
    LatexCommands: new Map()
};
function addMeaning(symbols, meaning) {
    for (const symbol of symbols) {
        exports.SemanticMap.Meaning.set(symbol, {
            role: meaning.role || semantic_meaning_js_1.SemanticRole.UNKNOWN,
            type: meaning.type || semantic_meaning_js_1.SemanticType.UNKNOWN,
            font: meaning.font || semantic_meaning_js_1.SemanticFont.UNKNOWN
        });
        if (meaning.secondary) {
            exports.SemanticMap.Secondary.set(symbol, meaning.secondary);
        }
    }
}
function initMeaning() {
    const sets = [
        {
            set: [
                '23',
                '26',
                '40',
                '5c',
                'a1',
                'a7',
                'b6',
                'bf',
                '2017',
                ['2022', '2025'],
                '2027',
                '203b',
                '203c',
                ['2041', '2043'],
                ['2047', '2049'],
                ['204b', '204d'],
                '2050',
                '2055',
                '2056',
                ['2058', '205e'],
                '2234',
                '2235',
                'fe45',
                'fe46',
                'fe5f',
                'fe60',
                'fe68',
                'fe6b',
                'ff03',
                'ff06',
                'ff0f',
                'ff20',
                'ff3c'
            ],
            type: semantic_meaning_js_1.SemanticType.PUNCTUATION,
            role: semantic_meaning_js_1.SemanticRole.UNKNOWN
        },
        {
            set: [
                '22',
                'ab',
                'bb',
                '2dd',
                ['2018', '201f'],
                '2039',
                '203a',
                ['301d', '301f'],
                'fe10',
                'ff02',
                'ff07'
            ],
            type: semantic_meaning_js_1.SemanticType.PUNCTUATION,
            role: semantic_meaning_js_1.SemanticRole.QUOTES
        },
        {
            set: ['3b', '204f', '2a1f', '2a3e', 'fe14', 'fe54', 'ff1b'],
            type: semantic_meaning_js_1.SemanticType.PUNCTUATION,
            role: semantic_meaning_js_1.SemanticRole.SEMICOLON
        },
        {
            set: ['3f', '203d', 'fe16', 'fe56', 'ff1f'],
            type: semantic_meaning_js_1.SemanticType.PUNCTUATION,
            role: semantic_meaning_js_1.SemanticRole.QUESTION
        },
        {
            set: ['21', 'fe15', 'fe57', 'ff01'],
            type: semantic_meaning_js_1.SemanticType.PUNCTUATION,
            role: semantic_meaning_js_1.SemanticRole.EXCLAMATION
        },
        {
            set: [
                '5e',
                '60',
                'a8',
                'aa',
                'b4',
                'ba',
                '2c7',
                ['2d8', '2da'],
                '2040',
                '207a',
                '207d',
                '207e',
                'ff3e',
                'ff40'
            ],
            type: semantic_meaning_js_1.SemanticType.PUNCTUATION,
            role: semantic_meaning_js_1.SemanticRole.OVERACCENT
        },
        {
            set: ['b8', '2db', '2038', '203f', '2054', '208a', '208d', '208e'],
            type: semantic_meaning_js_1.SemanticType.PUNCTUATION,
            role: semantic_meaning_js_1.SemanticRole.UNDERACCENT
        },
        {
            set: ['3a', '2982', 'fe13', 'fe30', 'fe55', 'ff1a'],
            type: semantic_meaning_js_1.SemanticType.PUNCTUATION,
            role: semantic_meaning_js_1.SemanticRole.COLON
        },
        {
            set: ['2c', '2063', 'fe50', 'ff0c'],
            type: semantic_meaning_js_1.SemanticType.PUNCTUATION,
            role: semantic_meaning_js_1.SemanticRole.COMMA
        },
        {
            set: ['2026', ['22ee', '22f1'], 'fe19'],
            type: semantic_meaning_js_1.SemanticType.PUNCTUATION,
            role: semantic_meaning_js_1.SemanticRole.ELLIPSIS
        },
        {
            set: ['2e', 'fe52', 'ff0e'],
            type: semantic_meaning_js_1.SemanticType.PUNCTUATION,
            role: semantic_meaning_js_1.SemanticRole.FULLSTOP
        },
        {
            set: ['2d', '207b', '208b', '2212', '2796', 'fe63', 'ff0d'],
            type: semantic_meaning_js_1.SemanticType.OPERATOR,
            role: semantic_meaning_js_1.SemanticRole.DASH,
            secondary: semantic_meaning_js_1.SemanticSecondary.BAR
        },
        {
            set: [
                '5f',
                'af',
                ['2010', '2015'],
                '203e',
                '208b',
                ['fe49', 'fe4f'],
                'fe58',
                'ff3f',
                'ffe3'
            ],
            type: semantic_meaning_js_1.SemanticType.PUNCTUATION,
            role: semantic_meaning_js_1.SemanticRole.DASH,
            secondary: semantic_meaning_js_1.SemanticSecondary.BAR
        },
        {
            set: [
                '7e',
                '2dc',
                '2f7',
                '303',
                '330',
                '334',
                '2053',
                '223c',
                '223d',
                '301c',
                'ff5e'
            ],
            type: semantic_meaning_js_1.SemanticType.OPERATOR,
            role: semantic_meaning_js_1.SemanticRole.TILDE,
            secondary: semantic_meaning_js_1.SemanticSecondary.TILDE
        },
        {
            set: ['27', '2b9', '2ba', ['2032', '2037'], '2057'],
            type: semantic_meaning_js_1.SemanticType.PUNCTUATION,
            role: semantic_meaning_js_1.SemanticRole.PRIME
        },
        {
            set: ['b0'],
            type: semantic_meaning_js_1.SemanticType.PUNCTUATION,
            role: semantic_meaning_js_1.SemanticRole.DEGREE
        },
        {
            set: [
                '2b',
                'b1',
                '2064',
                '2213',
                '2214',
                '2228',
                '222a',
                ['228c', '228e'],
                '2294',
                '2295',
                '229d',
                '229e',
                '22bb',
                '22bd',
                '22c4',
                '22ce',
                '22d3',
                '2304',
                '271b',
                '271c',
                '2795',
                '27cf',
                '29fa',
                '29fb',
                '29fe',
                ['2a22', '2a28'],
                '2a2d',
                '2a2e',
                '2a39',
                '2a42',
                '2a45',
                '2a46',
                '2a48',
                '2a4a',
                '2a4c',
                '2a4f',
                '2a50',
                '2a52',
                '2a54',
                '2a56',
                '2a57',
                '2a59',
                '2a5b',
                '2a5d',
                ['2a61', '2a63'],
                '2adc',
                '2add',
                'fe62',
                'ff0b'
            ],
            type: semantic_meaning_js_1.SemanticType.OPERATOR,
            role: semantic_meaning_js_1.SemanticRole.ADDITION
        },
        {
            set: [
                '2a',
                'b7',
                'd7',
                '2020',
                '2021',
                '204e',
                '2051',
                '2062',
                ['2217', '2219'],
                '2227',
                '2229',
                '2240',
                '2293',
                '2297',
                ['2299', '229b'],
                '22a0',
                '22a1',
                '22b9',
                '22bc',
                ['22c5', '22cc'],
                '22cf',
                '22d2',
                '22d4',
                '2303',
                '2305',
                '2306',
                '25cb',
                '2715',
                '2716',
                '27ce',
                '27d1',
                ['29d1', '29d7'],
                '29e2',
                '2a1d',
                ['2a2f', '2a37'],
                ['2a3b', '2a3d'],
                '2a40',
                '2a43',
                '2a44',
                '2a47',
                '2a49',
                '2a4b',
                '2a4d',
                '2a4e',
                '2a51',
                '2a53',
                '2a55',
                '2a58',
                '2a5a',
                '2a5c',
                ['2a5e', '2a60'],
                '2ada',
                '2adb',
                'fe61',
                'ff0a'
            ],
            type: semantic_meaning_js_1.SemanticType.OPERATOR,
            role: semantic_meaning_js_1.SemanticRole.MULTIPLICATION
        },
        {
            set: [
                '2d',
                'af',
                '2010',
                '2011',
                '2052',
                '207b',
                '208b',
                '2212',
                '2216',
                '2238',
                '2242',
                '2296',
                '229f',
                '2796',
                '29ff',
                ['2a29', '2a2c'],
                '2a3a',
                '2a41',
                'fe63',
                'ff0d'
            ],
            type: semantic_meaning_js_1.SemanticType.OPERATOR,
            role: semantic_meaning_js_1.SemanticRole.SUBTRACTION
        },
        {
            set: [
                '2f',
                'f7',
                '2044',
                '2215',
                '2298',
                '2797',
                '27cc',
                '29bc',
                ['29f5', '29f9'],
                '2a38'
            ],
            type: semantic_meaning_js_1.SemanticType.OPERATOR,
            role: semantic_meaning_js_1.SemanticRole.DIVISION
        },
        {
            set: ['25', '2030', '2031', 'ff05', 'fe6a'],
            type: semantic_meaning_js_1.SemanticType.OPERATOR,
            role: semantic_meaning_js_1.SemanticRole.POSTFIXOP
        },
        {
            set: [
                'ac',
                '2200',
                '2201',
                '2203',
                '2204',
                '2206',
                ['221a', '221c'],
                '2310',
                'ffe2'
            ],
            type: semantic_meaning_js_1.SemanticType.OPERATOR,
            role: semantic_meaning_js_1.SemanticRole.PREFIXOP
        },
        {
            set: [
                '2320',
                '2321',
                '23aa',
                '23ae',
                '23af',
                '23b2',
                '23b3',
                '23b6',
                '23b7'
            ],
            type: semantic_meaning_js_1.SemanticType.OPERATOR,
            role: semantic_meaning_js_1.SemanticRole.PREFIXOP
        },
        {
            set: ['1d7ca', '1d7cb'],
            type: semantic_meaning_js_1.SemanticType.OPERATOR,
            role: semantic_meaning_js_1.SemanticRole.PREFIXOP,
            font: semantic_meaning_js_1.SemanticFont.BOLD
        },
        {
            set: [
                '3d',
                '7e',
                '207c',
                '208c',
                '221d',
                '2237',
                ['223a', '223f'],
                '2243',
                '2245',
                '2248',
                ['224a', '224e'],
                ['2251', '225f'],
                '2261',
                '2263',
                '229c',
                '22cd',
                '22d5',
                '29e4',
                '29e6',
                '2a66',
                '2a67',
                ['2a6a', '2a6c'],
                ['2a6c', '2a78'],
                'fe66',
                'ff1d'
            ],
            type: semantic_meaning_js_1.SemanticType.RELATION,
            role: semantic_meaning_js_1.SemanticRole.EQUALITY
        },
        {
            set: [
                '3c',
                '3e',
                '2241',
                '2242',
                '2244',
                '2246',
                '2247',
                '2249',
                '224f',
                '2250',
                '2260',
                '2262',
                ['2264', '2281'],
                '22b0',
                '22b1',
                ['22d6', '22e1'],
                ['22e6', '22e9'],
                ['2976', '2978'],
                '29c0',
                '29c1',
                '29e1',
                '29e3',
                '29e5',
                ['2a79', '2abc'],
                ['2af7', '2afa'],
                'fe64',
                'fe65',
                'ff1c',
                'ff1e'
            ],
            type: semantic_meaning_js_1.SemanticType.RELATION,
            role: semantic_meaning_js_1.SemanticRole.INEQUALITY
        },
        {
            set: [
                ['2282', '228b'],
                ['228f', '2292'],
                ['22b2', '22b8'],
                '22d0',
                '22d1',
                ['22e2', '22e5'],
                ['22ea', '22ed'],
                '27c3',
                '27c4',
                ['27c7', '27c9'],
                ['27d5', '27d7'],
                '27dc',
                ['2979', '297b'],
                '29df',
                ['2abd', '2ad8']
            ],
            type: semantic_meaning_js_1.SemanticType.RELATION,
            role: semantic_meaning_js_1.SemanticRole.SET
        },
        {
            set: [
                '2236',
                ['27e0', '27e5'],
                '292b',
                '292c',
                ['29b5', '29bb'],
                '29be',
                '29bf',
                ['29c2', '29d0']
            ],
            type: semantic_meaning_js_1.SemanticType.RELATION,
            role: semantic_meaning_js_1.SemanticRole.UNKNOWN
        },
        {
            set: ['2205', ['29b0', '29b4']],
            type: semantic_meaning_js_1.SemanticType.IDENTIFIER,
            role: semantic_meaning_js_1.SemanticRole.SETEMPTY
        },
        {
            set: ['1ab2', '221e', ['29dc', '29de']],
            type: semantic_meaning_js_1.SemanticType.IDENTIFIER,
            role: semantic_meaning_js_1.SemanticRole.INFTY
        },
        {
            set: [
                '22a2',
                '22a3',
                ['22a6', '22af'],
                '27da',
                '27db',
                '27dd',
                '27de',
                '2ade',
                ['2ae2', '2ae6'],
                '2aec',
                '2aed'
            ],
            type: semantic_meaning_js_1.SemanticType.RELATION,
            role: semantic_meaning_js_1.SemanticRole.LOGIC
        },
        {
            set: [
                '22a4',
                '22a5',
                '22ba',
                '27d8',
                '27d9',
                '27df',
                '2adf',
                '2ae0',
                ['2ae7', '2aeb'],
                '2af1'
            ],
            type: semantic_meaning_js_1.SemanticType.IDENTIFIER,
            role: semantic_meaning_js_1.SemanticRole.LOGIC
        },
        {
            set: [
                ['2190', '21ff'],
                '2301',
                '2324',
                '238b',
                '2794',
                ['2798', '27af'],
                ['27b1', '27be'],
                ['27f0', '27ff'],
                ['2900', '292a'],
                ['292d', '2975'],
                ['297c', '297f'],
                ['2b00', '2b11'],
                ['2b30', '2b4c'],
                ['ffe9', 'ffec']
            ],
            type: semantic_meaning_js_1.SemanticType.RELATION,
            role: semantic_meaning_js_1.SemanticRole.ARROW
        },
        {
            set: ['2208', '220a', ['22f2', '22f9'], '22ff', '27d2', '2ad9'],
            type: semantic_meaning_js_1.SemanticType.OPERATOR,
            role: semantic_meaning_js_1.SemanticRole.ELEMENT
        },
        {
            set: ['2209'],
            type: semantic_meaning_js_1.SemanticType.OPERATOR,
            role: semantic_meaning_js_1.SemanticRole.NONELEMENT
        },
        {
            set: ['220b', '220d', ['22fa', '22fe']],
            type: semantic_meaning_js_1.SemanticType.OPERATOR,
            role: semantic_meaning_js_1.SemanticRole.REELEMENT
        },
        {
            set: ['220c'],
            type: semantic_meaning_js_1.SemanticType.OPERATOR,
            role: semantic_meaning_js_1.SemanticRole.RENONELEMENT
        },
        {
            set: [
                ['220f', '2211'],
                ['22c0', '22c3'],
                ['2a00', '2a0b'],
                '2a3f',
                '2afc',
                '2aff'
            ],
            type: semantic_meaning_js_1.SemanticType.LARGEOP,
            role: semantic_meaning_js_1.SemanticRole.SUM
        },
        {
            set: ['2140'],
            type: semantic_meaning_js_1.SemanticType.LARGEOP,
            role: semantic_meaning_js_1.SemanticRole.SUM,
            font: semantic_meaning_js_1.SemanticFont.DOUBLESTRUCK
        },
        {
            set: [
                ['222b', '2233'],
                ['2a0c', '2a17'],
                ['2a17', '2a1c']
            ],
            type: semantic_meaning_js_1.SemanticType.LARGEOP,
            role: semantic_meaning_js_1.SemanticRole.INTEGRAL
        },
        {
            set: [['2500', '257F']],
            type: semantic_meaning_js_1.SemanticType.RELATION,
            role: semantic_meaning_js_1.SemanticRole.BOX
        },
        {
            set: [['2580', '259F']],
            type: semantic_meaning_js_1.SemanticType.IDENTIFIER,
            role: semantic_meaning_js_1.SemanticRole.BLOCK
        },
        {
            set: [
                ['25A0', '25FF'],
                ['2B12', '2B2F'],
                ['2B50', '2B59']
            ],
            type: semantic_meaning_js_1.SemanticType.RELATION,
            role: semantic_meaning_js_1.SemanticRole.GEOMETRY
        },
        {
            set: [
                '220e',
                '2300',
                '2302',
                '2311',
                '29bd',
                '29e0',
                ['29e8', '29f3'],
                '2a1e',
                '2afe',
                'ffed',
                'ffee'
            ],
            type: semantic_meaning_js_1.SemanticType.OPERATOR,
            role: semantic_meaning_js_1.SemanticRole.GEOMETRY
        },
        {
            set: [
                ['221f', '2222'],
                '22be',
                '22bf',
                ['2312', '2314'],
                '237c',
                '27c0',
                ['299b', '29af']
            ],
            type: semantic_meaning_js_1.SemanticType.OPERATOR,
            role: semantic_meaning_js_1.SemanticRole.GEOMETRY
        },
        {
            set: [
                '24',
                ['a2', 'a5'],
                'b5',
                '2123',
                ['2125', '2127'],
                '212a',
                '212b',
                'fe69',
                'ff04',
                'ffe0',
                'ffe1',
                'ffe5',
                'ffe6'
            ],
            type: semantic_meaning_js_1.SemanticType.IDENTIFIER,
            role: semantic_meaning_js_1.SemanticRole.UNKNOWN
        },
        {
            set: [
                'a9',
                'ae',
                '210f',
                '2114',
                '2116',
                '2117',
                ['211e', '2122'],
                '212e',
                '2132',
                ['2139', '213b'],
                ['2141', '2144'],
                '214d',
                '214e',
                ['1f12a', '1f12c'],
                '1f18a'
            ],
            type: semantic_meaning_js_1.SemanticType.IDENTIFIER,
            role: semantic_meaning_js_1.SemanticRole.OTHERLETTER
        },
        {
            set: [
                '2224',
                '2226',
                '2239',
                '2307',
                '27b0',
                '27bf',
                '27c1',
                '27c2',
                '27ca',
                '27cb',
                '27cd',
                '27d0',
                '27d3',
                '27d4',
                '2981',
                '2999',
                '299a',
                '29e7',
                '29f4',
                '2a20',
                '2a21',
                '2a64',
                '2a65',
                '2a68',
                '2a69',
                '2ae1',
                ['2aee', '2af0'],
                '2af2',
                '2af3',
                '2af5',
                '2af6',
                '2afb',
                '2afd'
            ],
            type: semantic_meaning_js_1.SemanticType.OPERATOR,
            role: semantic_meaning_js_1.SemanticRole.UNKNOWN
        },
        {
            set: ['2605', '2606', '26aa', '26ab', ['2720', '274d']],
            type: semantic_meaning_js_1.SemanticType.OPERATOR,
            role: semantic_meaning_js_1.SemanticRole.UNKNOWN
        },
        {
            set: [['2145', '2149']],
            type: semantic_meaning_js_1.SemanticType.IDENTIFIER,
            role: semantic_meaning_js_1.SemanticRole.LATINLETTER,
            font: semantic_meaning_js_1.SemanticFont.DOUBLESTRUCKITALIC,
            secondary: semantic_meaning_js_1.SemanticSecondary.ALLLETTERS
        },
        {
            set: [['213c', '213f']],
            type: semantic_meaning_js_1.SemanticType.IDENTIFIER,
            role: semantic_meaning_js_1.SemanticRole.GREEKLETTER,
            font: semantic_meaning_js_1.SemanticFont.DOUBLESTRUCK,
            secondary: semantic_meaning_js_1.SemanticSecondary.ALLLETTERS
        },
        {
            set: [
                '3d0',
                '3d7',
                '3f6',
                ['1d26', '1d2a'],
                '1d5e',
                '1d60',
                ['1d66', '1d6a']
            ],
            type: semantic_meaning_js_1.SemanticType.IDENTIFIER,
            role: semantic_meaning_js_1.SemanticRole.GREEKLETTER,
            font: semantic_meaning_js_1.SemanticFont.NORMAL,
            secondary: semantic_meaning_js_1.SemanticSecondary.ALLLETTERS
        },
        {
            set: [['2135', '2138']],
            type: semantic_meaning_js_1.SemanticType.IDENTIFIER,
            role: semantic_meaning_js_1.SemanticRole.OTHERLETTER,
            font: semantic_meaning_js_1.SemanticFont.NORMAL,
            secondary: semantic_meaning_js_1.SemanticSecondary.ALLLETTERS
        },
        {
            set: ['131', '237'],
            type: semantic_meaning_js_1.SemanticType.IDENTIFIER,
            role: semantic_meaning_js_1.SemanticRole.LATINLETTER,
            font: semantic_meaning_js_1.SemanticFont.NORMAL
        },
        {
            set: ['1d6a4', '1d6a5'],
            type: semantic_meaning_js_1.SemanticType.IDENTIFIER,
            role: semantic_meaning_js_1.SemanticRole.LATINLETTER,
            font: semantic_meaning_js_1.SemanticFont.ITALIC
        },
        {
            set: ['2113', '2118'],
            type: semantic_meaning_js_1.SemanticType.IDENTIFIER,
            role: semantic_meaning_js_1.SemanticRole.LATINLETTER,
            font: semantic_meaning_js_1.SemanticFont.SCRIPT
        },
        {
            set: [
                ['c0', 'd6'],
                ['d8', 'f6'],
                ['f8', '1bf'],
                ['1c4', '2af'],
                ['1d00', '1d25'],
                ['1d6b', '1d9a'],
                ['1e00', '1ef9'],
                ['363', '36f'],
                ['1dd3', '1de6'],
                ['1d62', '1d65'],
                '1dca',
                '2071',
                '207f',
                ['2090', '209c'],
                '2c7c'
            ],
            type: semantic_meaning_js_1.SemanticType.IDENTIFIER,
            role: semantic_meaning_js_1.SemanticRole.LATINLETTER,
            font: semantic_meaning_js_1.SemanticFont.NORMAL
        },
        {
            set: [['00bc', '00be'], ['2150', '215f'], '2189'],
            type: semantic_meaning_js_1.SemanticType.NUMBER,
            role: semantic_meaning_js_1.SemanticRole.FLOAT
        },
        {
            set: ['23E8', ['3248', '324f']],
            type: semantic_meaning_js_1.SemanticType.NUMBER,
            role: semantic_meaning_js_1.SemanticRole.INTEGER
        },
        {
            set: [['214A', '214C'], '2705', '2713', '2714', '2717', '2718'],
            type: semantic_meaning_js_1.SemanticType.IDENTIFIER,
            role: semantic_meaning_js_1.SemanticRole.UNKNOWN
        },
        {
            set: [
                '20',
                'a0',
                'ad',
                ['2000', '200f'],
                ['2028', '202f'],
                ['205f', '2060'],
                '206a',
                '206b',
                '206e',
                '206f',
                'feff',
                ['fff9', 'fffb']
            ],
            type: semantic_meaning_js_1.SemanticType.TEXT,
            role: semantic_meaning_js_1.SemanticRole.SPACE
        },
        {
            set: [
                '7c',
                'a6',
                '2223',
                '23b8',
                '23b9',
                '23d0',
                '2758',
                ['fe31', 'fe34'],
                'ff5c',
                'ffe4',
                'ffe8'
            ],
            type: semantic_meaning_js_1.SemanticType.FENCE,
            role: semantic_meaning_js_1.SemanticRole.NEUTRAL
        },
        {
            set: ['2016', '2225', '2980', '2af4'],
            type: semantic_meaning_js_1.SemanticType.FENCE,
            role: semantic_meaning_js_1.SemanticRole.METRIC
        }
    ];
    sets.forEach((_a) => {
        var { set: s } = _a, m = __rest(_a, ["set"]);
        return addMeaning(Alphabet.makeMultiInterval(s), m);
    });
}
function addFences(map, ints, sep = 1) {
    const used = {};
    const codes = Alphabet.makeCodeInterval(ints);
    for (const code of codes) {
        if (used[code])
            continue;
        map.set(String.fromCodePoint(code), String.fromCodePoint(code + sep));
        used[code] = true;
        used[code + sep] = true;
    }
}
function initFences() {
    addFences(exports.SemanticMap.FencesVert, [
        '23b4',
        ['23dc', '23e1'],
        ['fe35', 'fe44'],
        'fe47'
    ]);
    addFences(exports.SemanticMap.FencesHoriz, [
        '28',
        '2045',
        ['2308', '230f'],
        ['231c', '231f'],
        '2329',
        '23b0',
        ['2768', '2775'],
        '27c5',
        ['27e6', '27ef'],
        ['2983', '2998'],
        ['29d8', '29db'],
        '29fc',
        ['2e22', '2e29'],
        ['3008', '3011'],
        ['3014', '301b'],
        'fd3e',
        'fe17',
        ['fe59', 'fe5e'],
        'ff08',
        'ff5f',
        'ff62'
    ]);
    addFences(exports.SemanticMap.FencesHoriz, ['5b', '7b', 'ff3b', 'ff5b'], 2);
    addFences(exports.SemanticMap.FencesHoriz, [['239b', '23a6']], 3);
    addFences(exports.SemanticMap.FencesHoriz, [['23a7', '23a9']], 4);
    addMeaning([...exports.SemanticMap.FencesHoriz.keys()], {
        type: semantic_meaning_js_1.SemanticType.FENCE,
        role: semantic_meaning_js_1.SemanticRole.OPEN
    });
    addMeaning([...exports.SemanticMap.FencesHoriz.values()], {
        type: semantic_meaning_js_1.SemanticType.FENCE,
        role: semantic_meaning_js_1.SemanticRole.CLOSE
    });
    addMeaning([...exports.SemanticMap.FencesVert.keys()], {
        type: semantic_meaning_js_1.SemanticType.FENCE,
        role: semantic_meaning_js_1.SemanticRole.TOP
    });
    addMeaning([...exports.SemanticMap.FencesVert.values()], {
        type: semantic_meaning_js_1.SemanticType.FENCE,
        role: semantic_meaning_js_1.SemanticRole.BOTTOM
    });
}
const trigonometricFunctions = [
    'cos',
    'cot',
    'csc',
    'sec',
    'sin',
    'tan',
    'arccos',
    'arccot',
    'arccsc',
    'arcsec',
    'arcsin',
    'arctan'
];
const hyperbolicFunctions = [
    'cosh',
    'coth',
    'csch',
    'sech',
    'sinh',
    'tanh',
    'arcosh',
    'arcoth',
    'arcsch',
    'arsech',
    'arsinh',
    'artanh'
];
const algebraicFunctions = ['deg', 'det', 'dim', 'hom', 'ker', 'Tr'];
const elementaryFunctions = [
    'log',
    'ln',
    'lg',
    'exp',
    'gcd',
    'lcm',
    'arg',
    'im',
    're',
    'Pr'
];
const prefixFunctions = trigonometricFunctions.concat(hyperbolicFunctions, algebraicFunctions, elementaryFunctions);
function initFunctions() {
    addMeaning([
        'inf',
        'lim',
        'liminf',
        'limsup',
        'max',
        'min',
        'sup',
        'injlim',
        'projlim'
    ], {
        type: semantic_meaning_js_1.SemanticType.FUNCTION,
        role: semantic_meaning_js_1.SemanticRole.LIMFUNC
    });
    addMeaning(prefixFunctions, {
        type: semantic_meaning_js_1.SemanticType.FUNCTION,
        role: semantic_meaning_js_1.SemanticRole.PREFIXFUNC
    });
    addMeaning(['mod', 'rem'], {
        type: semantic_meaning_js_1.SemanticType.OPERATOR,
        role: semantic_meaning_js_1.SemanticRole.PREFIXFUNC
    });
}
function addFunctionSemantic(base, names) {
    const meaning = exports.SemanticMap.Meaning.get(base) || {
        type: semantic_meaning_js_1.SemanticType.FUNCTION,
        role: semantic_meaning_js_1.SemanticRole.PREFIXFUNC
    };
    addMeaning(names, meaning);
}
function equal(meaning1, meaning2) {
    return (meaning1.type === meaning2.type &&
        meaning1.role === meaning2.role &&
        meaning1.font === meaning2.font);
}
function isMatchingFence(open, close) {
    const meaning = exports.SemanticMap.Meaning.get(open);
    if (meaning.type !== semantic_meaning_js_1.SemanticType.FENCE) {
        return false;
    }
    if (meaning.role === semantic_meaning_js_1.SemanticRole.NEUTRAL ||
        meaning.role === semantic_meaning_js_1.SemanticRole.METRIC) {
        return open === close;
    }
    return (exports.SemanticMap.FencesHoriz.get(open) === close ||
        exports.SemanticMap.FencesVert.get(open) === close);
}
function changeSemantics(alphabet, change) {
    for (const [pos, meaning] of Object.entries(change)) {
        const character = alphabet[pos];
        if (character !== undefined) {
            exports.SemanticMap.Meaning.set(character, meaning);
        }
    }
}
function addSecondaries(alphabet, change) {
    for (const [pos, meaning] of Object.entries(change)) {
        const character = alphabet[pos];
        if (character !== undefined) {
            exports.SemanticMap.Secondary.set(character, meaning);
        }
    }
}
function singleAlphabet(alphabet, type, role, font, semfont, secondaries = [], change = {}, secondary = {}) {
    const interval = Alphabet.INTERVALS.get(Alphabet.alphabetName(alphabet, font));
    if (interval) {
        interval.unicode.forEach((x) => {
            exports.SemanticMap.Meaning.set(x, {
                type: type,
                role: role,
                font: semfont
            });
            secondaries.forEach((sec) => exports.SemanticMap.Secondary.set(x, sec));
        });
        changeSemantics(interval.unicode, change);
        addSecondaries(interval.unicode, secondary);
    }
}
function initAlphabets() {
    for (const [name, font] of Object.entries(semantic_meaning_js_1.SemanticFont)) {
        const emb = !!Alphabet.Embellish[name];
        const semfont = emb
            ? semantic_meaning_js_1.SemanticFont.UNKNOWN
            : font === semantic_meaning_js_1.SemanticFont.FULLWIDTH
                ? semantic_meaning_js_1.SemanticFont.NORMAL
                : font;
        singleAlphabet(Alphabet.Base.LATINCAP, semantic_meaning_js_1.SemanticType.IDENTIFIER, semantic_meaning_js_1.SemanticRole.LATINLETTER, font, semfont, [semantic_meaning_js_1.SemanticSecondary.ALLLETTERS]);
        singleAlphabet(Alphabet.Base.LATINSMALL, semantic_meaning_js_1.SemanticType.IDENTIFIER, semantic_meaning_js_1.SemanticRole.LATINLETTER, font, semfont, [semantic_meaning_js_1.SemanticSecondary.ALLLETTERS], {}, { 3: semantic_meaning_js_1.SemanticSecondary.D });
        singleAlphabet(Alphabet.Base.GREEKCAP, semantic_meaning_js_1.SemanticType.IDENTIFIER, semantic_meaning_js_1.SemanticRole.GREEKLETTER, font, semfont, [semantic_meaning_js_1.SemanticSecondary.ALLLETTERS]);
        singleAlphabet(Alphabet.Base.GREEKSMALL, semantic_meaning_js_1.SemanticType.IDENTIFIER, semantic_meaning_js_1.SemanticRole.GREEKLETTER, font, semfont, [semantic_meaning_js_1.SemanticSecondary.ALLLETTERS], {
            0: {
                type: semantic_meaning_js_1.SemanticType.OPERATOR,
                role: semantic_meaning_js_1.SemanticRole.PREFIXOP,
                font: semfont
            },
            26: {
                type: semantic_meaning_js_1.SemanticType.OPERATOR,
                role: semantic_meaning_js_1.SemanticRole.PREFIXOP,
                font: semfont
            }
        });
        singleAlphabet(Alphabet.Base.DIGIT, semantic_meaning_js_1.SemanticType.NUMBER, semantic_meaning_js_1.SemanticRole.INTEGER, font, semfont);
    }
}
initMeaning();
initFences();
initAlphabets();
initFunctions();
