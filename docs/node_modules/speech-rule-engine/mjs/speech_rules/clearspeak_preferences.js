import { Engine } from '../common/engine.js';
import * as EngineConst from '../common/engine_const.js';
import { DynamicCstr } from '../rule_engine/dynamic_cstr.js';
import { Axis, DefaultComparator, DynamicCstrParser, DynamicProperties } from '../rule_engine/dynamic_cstr.js';
import * as MathCompoundStore from '../rule_engine/math_compound_store.js';
import { SpeechRuleEngine } from '../rule_engine/speech_rule_engine.js';
import { SemanticRole, SemanticType } from '../semantic_tree/semantic_meaning.js';
export class ClearspeakPreferences extends DynamicCstr {
    static comparator() {
        return new Comparator(Engine.getInstance().dynamicCstr, DynamicProperties.createProp([DynamicCstr.DEFAULT_VALUES[Axis.LOCALE]], [DynamicCstr.DEFAULT_VALUES[Axis.MODALITY]], [DynamicCstr.DEFAULT_VALUES[Axis.DOMAIN]], [DynamicCstr.DEFAULT_VALUES[Axis.STYLE]]));
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
        return str.length ? str.join(':') : DynamicCstr.DEFAULT_VALUE;
    }
    static getLocalePreferences(opt_dynamic) {
        const dynamic = opt_dynamic ||
            MathCompoundStore.enumerate(SpeechRuleEngine.getInstance().enumerate());
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
ClearspeakPreferences.AUTO = 'Auto';
const PREFERENCES = new DynamicProperties({
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
class Comparator extends DefaultComparator {
    constructor(cstr, props) {
        super(cstr, props);
        this.preference =
            cstr instanceof ClearspeakPreferences ? cstr.preference : {};
    }
    match(cstr) {
        if (!(cstr instanceof ClearspeakPreferences)) {
            return super.match(cstr);
        }
        if (cstr.getComponents()[Axis.STYLE] === 'default') {
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
class Parser extends DynamicCstrParser {
    constructor() {
        super([Axis.LOCALE, Axis.MODALITY, Axis.DOMAIN, Axis.STYLE]);
    }
    parse(str) {
        const initial = super.parse(str);
        let style = initial.getValue(Axis.STYLE);
        const locale = initial.getValue(Axis.LOCALE);
        const modality = initial.getValue(Axis.MODALITY);
        let pref = {};
        if (style !== DynamicCstr.DEFAULT_VALUE) {
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
        SemanticType.FENCED,
        SemanticRole.NEUTRAL,
        SemanticRole.METRIC
    ],
    ['Bar', SemanticType.OVERSCORE, SemanticRole.OVERACCENT],
    ['Caps', SemanticType.IDENTIFIER, SemanticRole.LATINLETTER],
    ['CombinationPermutation', SemanticType.APPL, SemanticRole.UNKNOWN],
    ['Ellipses', SemanticType.PUNCTUATION, SemanticRole.ELLIPSIS],
    ['Exponent', SemanticType.SUPERSCRIPT, ''],
    ['Fraction', SemanticType.FRACTION, ''],
    ['Functions', SemanticType.APPL, SemanticRole.SIMPLEFUNC],
    ['ImpliedTimes', SemanticType.OPERATOR, SemanticRole.IMPLICIT],
    ['Log', SemanticType.APPL, SemanticRole.PREFIXFUNC],
    ['Matrix', SemanticType.MATRIX, ''],
    ['Matrix', SemanticType.VECTOR, ''],
    ['MultiLineLabel', SemanticType.MULTILINE, SemanticRole.LABEL],
    ['MultiLineOverview', SemanticType.MULTILINE, SemanticRole.TABLE],
    ['MultiLinePausesBetweenColumns', SemanticType.MULTILINE, SemanticRole.TABLE],
    ['MultiLineLabel', SemanticType.TABLE, SemanticRole.LABEL],
    ['MultiLineOverview', SemanticType.TABLE, SemanticRole.TABLE],
    ['MultiLinePausesBetweenColumns', SemanticType.TABLE, SemanticRole.TABLE],
    ['MultiLineLabel', SemanticType.CASES, SemanticRole.LABEL],
    ['MultiLineOverview', SemanticType.CASES, SemanticRole.TABLE],
    ['MultiLinePausesBetweenColumns', SemanticType.CASES, SemanticRole.TABLE],
    ['MultsymbolDot', SemanticType.OPERATOR, SemanticRole.MULTIPLICATION],
    ['MultsymbolX', SemanticType.OPERATOR, SemanticRole.MULTIPLICATION],
    ['Paren', SemanticType.FENCED, SemanticRole.LEFTRIGHT],
    ['Prime', SemanticType.SUPERSCRIPT, SemanticRole.PRIME],
    ['Roots', SemanticType.ROOT, ''],
    ['Roots', SemanticType.SQRT, ''],
    ['SetMemberSymbol', SemanticType.RELATION, SemanticRole.ELEMENT],
    ['Sets', SemanticType.FENCED, SemanticRole.SETEXT],
    ['TriangleSymbol', SemanticType.IDENTIFIER, SemanticRole.GREEKLETTER],
    ['Trig', SemanticType.APPL, SemanticRole.PREFIXFUNC],
    ['VerticalLine', SemanticType.PUNCTUATED, SemanticRole.VBAR]
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
Engine.getInstance().comparators['clearspeak'] =
    ClearspeakPreferences.comparator;
Engine.getInstance().parsers['clearspeak'] = new Parser();
