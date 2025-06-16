"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ClearspeakPreferences = void 0;
const engine_js_1 = require("../common/engine.js");
const EngineConst = require("../common/engine_const.js");
const dynamic_cstr_js_1 = require("../rule_engine/dynamic_cstr.js");
const dynamic_cstr_js_2 = require("../rule_engine/dynamic_cstr.js");
const MathCompoundStore = require("../rule_engine/math_compound_store.js");
const speech_rule_engine_js_1 = require("../rule_engine/speech_rule_engine.js");
const semantic_meaning_js_1 = require("../semantic_tree/semantic_meaning.js");
class ClearspeakPreferences extends dynamic_cstr_js_1.DynamicCstr {
    static comparator() {
        return new Comparator(engine_js_1.Engine.getInstance().dynamicCstr, dynamic_cstr_js_2.DynamicProperties.createProp([dynamic_cstr_js_1.DynamicCstr.DEFAULT_VALUES[dynamic_cstr_js_2.Axis.LOCALE]], [dynamic_cstr_js_1.DynamicCstr.DEFAULT_VALUES[dynamic_cstr_js_2.Axis.MODALITY]], [dynamic_cstr_js_1.DynamicCstr.DEFAULT_VALUES[dynamic_cstr_js_2.Axis.DOMAIN]], [dynamic_cstr_js_1.DynamicCstr.DEFAULT_VALUES[dynamic_cstr_js_2.Axis.STYLE]]));
    }
    static fromPreference(pref) {
        const pairs = pref.split(':');
        const preferences = {};
        const properties = PREFERENCES.getProperties();
        const validKeys = Object.keys(properties);
        for (let i = 0, key; (key = pairs[i]); i++) {
            const pair = key.split('_');
            if (validKeys.indexOf(pair[0]) === -1) {
                continue;
            }
            const value = pair[1];
            if (value &&
                value !== ClearspeakPreferences.AUTO &&
                properties[pair[0]].indexOf(value) !== -1) {
                preferences[pair[0]] = pair[1];
            }
        }
        return preferences;
    }
    static toPreference(pref) {
        const keys = Object.keys(pref);
        const str = [];
        for (let i = 0; i < keys.length; i++) {
            str.push(keys[i] + '_' + pref[keys[i]]);
        }
        return str.length ? str.join(':') : dynamic_cstr_js_1.DynamicCstr.DEFAULT_VALUE;
    }
    static getLocalePreferences(opt_dynamic) {
        const dynamic = opt_dynamic ||
            MathCompoundStore.enumerate(speech_rule_engine_js_1.SpeechRuleEngine.getInstance().enumerate());
        return ClearspeakPreferences.getLocalePreferences_(dynamic);
    }
    static currentPreference() {
        return EngineConst.DOMAIN_TO_STYLES['clearspeak'];
    }
    static relevantPreferences(node) {
        const roles = SEMANTIC_MAPPING_[node.type];
        if (!roles) {
            return 'ImpliedTimes';
        }
        return roles[node.role] || roles[''] || 'ImpliedTimes';
    }
    static findPreference(prefs, kind) {
        if (prefs === 'default') {
            return ClearspeakPreferences.AUTO;
        }
        const parsed = ClearspeakPreferences.fromPreference(prefs);
        return parsed[kind] || ClearspeakPreferences.AUTO;
    }
    static addPreference(prefs, kind, value) {
        if (prefs === 'default') {
            return kind + '_' + value;
        }
        const parsed = ClearspeakPreferences.fromPreference(prefs);
        parsed[kind] = value;
        return ClearspeakPreferences.toPreference(parsed);
    }
    static getLocalePreferences_(dynamic) {
        const result = {};
        for (const locale of Object.keys(dynamic)) {
            if (!dynamic[locale]['speech'] ||
                !dynamic[locale]['speech']['clearspeak']) {
                continue;
            }
            const locPrefs = Object.keys(dynamic[locale]['speech']['clearspeak']);
            if (locPrefs.length < 3)
                continue;
            const prefs = (result[locale] = {});
            for (const axis in PREFERENCES.getProperties()) {
                const allSty = PREFERENCES.getProperties()[axis];
                const values = [axis + '_Auto'];
                if (allSty) {
                    for (const sty of allSty) {
                        if (locPrefs.indexOf(axis + '_' + sty) !== -1) {
                            values.push(axis + '_' + sty);
                        }
                    }
                }
                prefs[axis] = values;
            }
        }
        return result;
    }
    constructor(cstr, preference) {
        super(cstr);
        this.preference = preference;
    }
    equal(cstr) {
        const top = super.equal(cstr);
        if (!top) {
            return false;
        }
        const keys = Object.keys(this.preference);
        const preference = cstr.preference;
        if (keys.length !== Object.keys(preference).length) {
            return false;
        }
        for (let i = 0, key; (key = keys[i]); i++) {
            if (this.preference[key] !== preference[key]) {
                return false;
            }
        }
        return true;
    }
}
exports.ClearspeakPreferences = ClearspeakPreferences;
ClearspeakPreferences.AUTO = 'Auto';
const PREFERENCES = new dynamic_cstr_js_2.DynamicProperties({
    AbsoluteValue: ['Auto', 'AbsEnd', 'Cardinality', 'Determinant'],
    Bar: ['Auto', 'Conjugate'],
    Caps: ['Auto', 'SayCaps'],
    CombinationPermutation: ['Auto', 'ChoosePermute'],
    Currency: ['Auto', 'Position', 'Prefix'],
    Ellipses: ['Auto', 'AndSoOn'],
    Enclosed: ['Auto', 'EndEnclose'],
    Exponent: [
        'Auto',
        'AfterPower',
        'Ordinal',
        'OrdinalPower',
        'Exponent'
    ],
    Fraction: [
        'Auto',
        'EndFrac',
        'FracOver',
        'General',
        'GeneralEndFrac',
        'Ordinal',
        'Over',
        'OverEndFrac',
        'Per'
    ],
    Functions: [
        'Auto',
        'None',
        'Reciprocal'
    ],
    ImpliedTimes: ['Auto', 'MoreImpliedTimes', 'None'],
    Log: ['Auto', 'LnAsNaturalLog'],
    Matrix: [
        'Auto',
        'Combinatoric',
        'EndMatrix',
        'EndVector',
        'SilentColNum',
        'SpeakColNum',
        'Vector'
    ],
    MultiLineLabel: [
        'Auto',
        'Case',
        'Constraint',
        'Equation',
        'Line',
        'None',
        'Row',
        'Step'
    ],
    MultiLineOverview: ['Auto', 'None'],
    MultiLinePausesBetweenColumns: ['Auto', 'Long', 'Short'],
    MultsymbolDot: ['Auto', 'Dot'],
    MultsymbolX: ['Auto', 'By', 'Cross'],
    Paren: [
        'Auto',
        'CoordPoint',
        'Interval',
        'Silent',
        'Speak',
        'SpeakNestingLevel'
    ],
    Prime: ['Auto', 'Angle', 'Length'],
    Roots: ['Auto', 'PosNegSqRoot', 'PosNegSqRootEnd', 'RootEnd'],
    SetMemberSymbol: ['Auto', 'Belongs', 'Element', 'Member', 'In'],
    Sets: ['Auto', 'SilentBracket', 'woAll'],
    TriangleSymbol: ['Auto', 'Delta'],
    Trig: [
        'Auto',
        'ArcTrig',
        'TrigInverse',
        'Reciprocal'
    ],
    VerticalLine: ['Auto', 'Divides', 'Given', 'SuchThat']
});
class Comparator extends dynamic_cstr_js_2.DefaultComparator {
    constructor(cstr, props) {
        super(cstr, props);
        this.preference =
            cstr instanceof ClearspeakPreferences ? cstr.preference : {};
    }
    match(cstr) {
        if (!(cstr instanceof ClearspeakPreferences)) {
            return super.match(cstr);
        }
        if (cstr.getComponents()[dynamic_cstr_js_2.Axis.STYLE] === 'default') {
            return true;
        }
        const keys = Object.keys(cstr.preference);
        for (let i = 0, key; (key = keys[i]); i++) {
            if (this.preference[key] !== cstr.preference[key]) {
                return false;
            }
        }
        return true;
    }
    compare(cstr1, cstr2) {
        const top = super.compare(cstr1, cstr2);
        if (top !== 0) {
            return top;
        }
        const pref1 = cstr1 instanceof ClearspeakPreferences;
        const pref2 = cstr2 instanceof ClearspeakPreferences;
        if (!pref1 && pref2) {
            return 1;
        }
        if (pref1 && !pref2) {
            return -1;
        }
        if (!pref1 && !pref2) {
            return 0;
        }
        const length1 = Object.keys(cstr1.preference).length;
        const length2 = Object.keys(cstr2.preference).length;
        return length1 > length2 ? -1 : length1 < length2 ? 1 : 0;
    }
}
class Parser extends dynamic_cstr_js_2.DynamicCstrParser {
    constructor() {
        super([dynamic_cstr_js_2.Axis.LOCALE, dynamic_cstr_js_2.Axis.MODALITY, dynamic_cstr_js_2.Axis.DOMAIN, dynamic_cstr_js_2.Axis.STYLE]);
    }
    parse(str) {
        const initial = super.parse(str);
        let style = initial.getValue(dynamic_cstr_js_2.Axis.STYLE);
        const locale = initial.getValue(dynamic_cstr_js_2.Axis.LOCALE);
        const modality = initial.getValue(dynamic_cstr_js_2.Axis.MODALITY);
        let pref = {};
        if (style !== dynamic_cstr_js_1.DynamicCstr.DEFAULT_VALUE) {
            pref = this.fromPreference(style);
            style = this.toPreference(pref);
        }
        return new ClearspeakPreferences({
            locale: locale,
            modality: modality,
            domain: 'clearspeak',
            style: style
        }, pref);
    }
    fromPreference(pref) {
        return ClearspeakPreferences.fromPreference(pref);
    }
    toPreference(pref) {
        return ClearspeakPreferences.toPreference(pref);
    }
}
const REVERSE_MAPPING = [
    [
        'AbsoluteValue',
        semantic_meaning_js_1.SemanticType.FENCED,
        semantic_meaning_js_1.SemanticRole.NEUTRAL,
        semantic_meaning_js_1.SemanticRole.METRIC
    ],
    ['Bar', semantic_meaning_js_1.SemanticType.OVERSCORE, semantic_meaning_js_1.SemanticRole.OVERACCENT],
    ['Caps', semantic_meaning_js_1.SemanticType.IDENTIFIER, semantic_meaning_js_1.SemanticRole.LATINLETTER],
    ['CombinationPermutation', semantic_meaning_js_1.SemanticType.APPL, semantic_meaning_js_1.SemanticRole.UNKNOWN],
    ['Ellipses', semantic_meaning_js_1.SemanticType.PUNCTUATION, semantic_meaning_js_1.SemanticRole.ELLIPSIS],
    ['Exponent', semantic_meaning_js_1.SemanticType.SUPERSCRIPT, ''],
    ['Fraction', semantic_meaning_js_1.SemanticType.FRACTION, ''],
    ['Functions', semantic_meaning_js_1.SemanticType.APPL, semantic_meaning_js_1.SemanticRole.SIMPLEFUNC],
    ['ImpliedTimes', semantic_meaning_js_1.SemanticType.OPERATOR, semantic_meaning_js_1.SemanticRole.IMPLICIT],
    ['Log', semantic_meaning_js_1.SemanticType.APPL, semantic_meaning_js_1.SemanticRole.PREFIXFUNC],
    ['Matrix', semantic_meaning_js_1.SemanticType.MATRIX, ''],
    ['Matrix', semantic_meaning_js_1.SemanticType.VECTOR, ''],
    ['MultiLineLabel', semantic_meaning_js_1.SemanticType.MULTILINE, semantic_meaning_js_1.SemanticRole.LABEL],
    ['MultiLineOverview', semantic_meaning_js_1.SemanticType.MULTILINE, semantic_meaning_js_1.SemanticRole.TABLE],
    ['MultiLinePausesBetweenColumns', semantic_meaning_js_1.SemanticType.MULTILINE, semantic_meaning_js_1.SemanticRole.TABLE],
    ['MultiLineLabel', semantic_meaning_js_1.SemanticType.TABLE, semantic_meaning_js_1.SemanticRole.LABEL],
    ['MultiLineOverview', semantic_meaning_js_1.SemanticType.TABLE, semantic_meaning_js_1.SemanticRole.TABLE],
    ['MultiLinePausesBetweenColumns', semantic_meaning_js_1.SemanticType.TABLE, semantic_meaning_js_1.SemanticRole.TABLE],
    ['MultiLineLabel', semantic_meaning_js_1.SemanticType.CASES, semantic_meaning_js_1.SemanticRole.LABEL],
    ['MultiLineOverview', semantic_meaning_js_1.SemanticType.CASES, semantic_meaning_js_1.SemanticRole.TABLE],
    ['MultiLinePausesBetweenColumns', semantic_meaning_js_1.SemanticType.CASES, semantic_meaning_js_1.SemanticRole.TABLE],
    ['MultsymbolDot', semantic_meaning_js_1.SemanticType.OPERATOR, semantic_meaning_js_1.SemanticRole.MULTIPLICATION],
    ['MultsymbolX', semantic_meaning_js_1.SemanticType.OPERATOR, semantic_meaning_js_1.SemanticRole.MULTIPLICATION],
    ['Paren', semantic_meaning_js_1.SemanticType.FENCED, semantic_meaning_js_1.SemanticRole.LEFTRIGHT],
    ['Prime', semantic_meaning_js_1.SemanticType.SUPERSCRIPT, semantic_meaning_js_1.SemanticRole.PRIME],
    ['Roots', semantic_meaning_js_1.SemanticType.ROOT, ''],
    ['Roots', semantic_meaning_js_1.SemanticType.SQRT, ''],
    ['SetMemberSymbol', semantic_meaning_js_1.SemanticType.RELATION, semantic_meaning_js_1.SemanticRole.ELEMENT],
    ['Sets', semantic_meaning_js_1.SemanticType.FENCED, semantic_meaning_js_1.SemanticRole.SETEXT],
    ['TriangleSymbol', semantic_meaning_js_1.SemanticType.IDENTIFIER, semantic_meaning_js_1.SemanticRole.GREEKLETTER],
    ['Trig', semantic_meaning_js_1.SemanticType.APPL, semantic_meaning_js_1.SemanticRole.PREFIXFUNC],
    ['VerticalLine', semantic_meaning_js_1.SemanticType.PUNCTUATED, semantic_meaning_js_1.SemanticRole.VBAR]
];
const SEMANTIC_MAPPING_ = (function () {
    const result = {};
    for (let i = 0, triple; (triple = REVERSE_MAPPING[i]); i++) {
        const pref = triple[0];
        let role = result[triple[1]];
        if (!role) {
            role = {};
            result[triple[1]] = role;
        }
        role[triple[2]] = pref;
    }
    return result;
})();
engine_js_1.Engine.getInstance().comparators['clearspeak'] =
    ClearspeakPreferences.comparator;
engine_js_1.Engine.getInstance().parsers['clearspeak'] = new Parser();
