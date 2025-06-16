"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.SpeechRuleEngine = void 0;
const auditory_description_js_1 = require("../audio/auditory_description.js");
const span_js_1 = require("../audio/span.js");
const debugger_js_1 = require("../common/debugger.js");
const DomUtil = require("../common/dom_util.js");
const engine_js_1 = require("../common/engine.js");
const EngineConst = require("../common/engine_const.js");
const xpath_util_js_1 = require("../common/xpath_util.js");
const SpeechRules = require("../speech_rules/speech_rules.js");
const SpeechRuleStores = require("../speech_rules/speech_rule_stores.js");
const braille_store_js_1 = require("./braille_store.js");
const dynamic_cstr_js_1 = require("./dynamic_cstr.js");
const grammar_js_1 = require("./grammar.js");
const math_store_js_1 = require("./math_store.js");
const speech_rule_js_1 = require("./speech_rule.js");
const trie_js_1 = require("../indexing/trie.js");
class SpeechRuleEngine {
    static getInstance() {
        SpeechRuleEngine.instance =
            SpeechRuleEngine.instance || new SpeechRuleEngine();
        return SpeechRuleEngine.instance;
    }
    static debugSpeechRule(rule, node) {
        const prec = rule.precondition;
        const queryResult = rule.context.applyQuery(node, prec.query);
        debugger_js_1.Debugger.getInstance().output(prec.query, queryResult ? queryResult.toString() : queryResult);
        prec.constraints.forEach((cstr) => debugger_js_1.Debugger.getInstance().output(cstr, rule.context.applyConstraint(node, cstr)));
    }
    static debugNamedSpeechRule(name, node) {
        const rules = SpeechRuleEngine.getInstance().trie.collectRules();
        const allRules = rules.filter((rule) => rule.name == name);
        for (let i = 0, rule; (rule = allRules[i]); i++) {
            debugger_js_1.Debugger.getInstance().output('Rule', name, 'DynamicCstr:', rule.dynamicCstr.toString(), 'number', i);
            SpeechRuleEngine.debugSpeechRule(rule, node);
        }
    }
    evaluateNode(node) {
        (0, xpath_util_js_1.updateEvaluator)(node);
        const timeIn = new Date().getTime();
        let result = [];
        try {
            result = this.evaluateNode_(node);
        }
        catch (err) {
            console.log(err);
            console.error('Something went wrong computing speech.');
            debugger_js_1.Debugger.getInstance().output(err);
        }
        const timeOut = new Date().getTime();
        debugger_js_1.Debugger.getInstance().output('Time:', timeOut - timeIn);
        return result;
    }
    toString() {
        const allRules = this.trie.collectRules();
        return allRules.map((rule) => rule.toString()).join('\n');
    }
    runInSetting(settings, callback) {
        const engine = engine_js_1.Engine.getInstance();
        const save = {};
        for (const [key, val] of Object.entries(settings)) {
            save[key] = engine[key];
            engine[key] = val;
        }
        engine.setDynamicCstr();
        const result = callback();
        for (const [key, val] of Object.entries(save)) {
            engine[key] = val;
        }
        engine.setDynamicCstr();
        return result;
    }
    static addStore(set) {
        const store = storeFactory(set);
        if (store.kind !== 'abstract') {
            store
                .getSpeechRules()
                .forEach((x) => SpeechRuleEngine.getInstance().trie.addRule(x));
        }
        SpeechRuleEngine.getInstance().addEvaluator(store);
    }
    processGrammar(context, node, grammar) {
        const assignment = {};
        for (const [key, val] of Object.entries(grammar)) {
            assignment[key] =
                typeof val === 'string' ? context.constructString(node, val) : val;
        }
        grammar_js_1.Grammar.getInstance().pushState(assignment);
    }
    addEvaluator(store) {
        const fun = store.evaluateDefault.bind(store);
        const loc = this.evaluators_[store.locale];
        if (loc) {
            loc[store.modality] = fun;
            return;
        }
        const mod = {};
        mod[store.modality] = fun;
        this.evaluators_[store.locale] = mod;
    }
    getEvaluator(locale, modality) {
        const loc = this.evaluators_[locale] ||
            this.evaluators_[dynamic_cstr_js_1.DynamicCstr.DEFAULT_VALUES[dynamic_cstr_js_1.Axis.LOCALE]];
        return loc[modality] || loc[dynamic_cstr_js_1.DynamicCstr.DEFAULT_VALUES[dynamic_cstr_js_1.Axis.MODALITY]];
    }
    enumerate(opt_info) {
        return this.trie.enumerate(opt_info);
    }
    constructor() {
        this.trie = null;
        this.evaluators_ = {};
        this.trie = new trie_js_1.Trie();
    }
    evaluateNode_(node) {
        if (!node) {
            return [];
        }
        this.updateConstraint_();
        let result = this.evaluateTree_(node);
        result = processAnnotations(result);
        return result;
    }
    evaluateTree_(node) {
        const engine = engine_js_1.Engine.getInstance();
        let result;
        debugger_js_1.Debugger.getInstance().output(engine.mode !== EngineConst.Mode.HTTP ? node.toString() : node);
        grammar_js_1.Grammar.getInstance().setAttribute(node);
        const rule = this.lookupRule(node, engine.dynamicCstr);
        if (!rule) {
            if (engine.strict) {
                return [];
            }
            result = this.getEvaluator(engine.locale, engine.modality)(node);
            if (node.attributes) {
                this.addPersonality_(result, {}, false, node);
            }
            return result;
        }
        debugger_js_1.Debugger.getInstance().generateOutput(() => [
            'Apply Rule:',
            rule.name,
            rule.dynamicCstr.toString(),
            engine.mode === EngineConst.Mode.HTTP
                ? DomUtil.serializeXml(node)
                : node.toString()
        ]);
        grammar_js_1.Grammar.getInstance().processSingles();
        const context = rule.context;
        const components = rule.action.components;
        result = [];
        for (let i = 0, component; (component = components[i]); i++) {
            let descrs = [];
            const content = component.content || '';
            const attributes = component.attributes || {};
            let multi = false;
            if (component.grammar) {
                this.processGrammar(context, node, component.grammar);
            }
            let saveEngine = null;
            if (attributes.engine) {
                saveEngine = engine_js_1.Engine.getInstance().dynamicCstr.getComponents();
                const features = Object.assign({}, saveEngine, grammar_js_1.Grammar.parseInput(attributes.engine));
                engine_js_1.Engine.getInstance().setDynamicCstr(features);
                this.updateConstraint_();
            }
            switch (component.type) {
                case speech_rule_js_1.ActionType.NODE:
                    {
                        const selected = context.applyQuery(node, content);
                        if (selected) {
                            descrs = this.evaluateTree_(selected);
                        }
                    }
                    break;
                case speech_rule_js_1.ActionType.MULTI:
                    {
                        multi = true;
                        const selects = context.applySelector(node, content);
                        if (selects.length > 0) {
                            descrs = this.evaluateNodeList_(context, selects, attributes['sepFunc'], context.constructString(node, attributes['separator']), attributes['ctxtFunc'], context.constructString(node, attributes['context']));
                        }
                    }
                    break;
                case speech_rule_js_1.ActionType.TEXT:
                    {
                        const xpath = attributes['span'];
                        let attrs = {};
                        if (xpath) {
                            const nodes = (0, xpath_util_js_1.evalXPath)(xpath, node);
                            attrs = nodes.length
                                ? span_js_1.Span.getAttributes(nodes[0])
                                : { kind: xpath };
                        }
                        const str = context.constructSpan(node, content, attrs);
                        descrs = str.map(function (span) {
                            return auditory_description_js_1.AuditoryDescription.create({ text: span.speech, attributes: span.attributes }, { adjust: true });
                        });
                    }
                    break;
                case speech_rule_js_1.ActionType.PERSONALITY:
                default:
                    descrs = [auditory_description_js_1.AuditoryDescription.create({ text: content })];
            }
            if (descrs[0] && !multi) {
                if (attributes['context']) {
                    descrs[0]['context'] =
                        context.constructString(node, attributes['context']) +
                            (descrs[0]['context'] || '');
                }
                if (attributes['annotation']) {
                    descrs[0]['annotation'] = attributes['annotation'];
                }
            }
            this.addLayout(descrs, attributes, multi);
            if (component.grammar) {
                grammar_js_1.Grammar.getInstance().popState();
            }
            result = result.concat(this.addPersonality_(descrs, attributes, multi, node));
            if (saveEngine) {
                engine_js_1.Engine.getInstance().setDynamicCstr(saveEngine);
                this.updateConstraint_();
            }
        }
        grammar_js_1.Grammar.getInstance().popState();
        return result;
    }
    evaluateNodeList_(context, nodes, sepFunc, sepStr, ctxtFunc, ctxtStr) {
        if (!nodes.length) {
            return [];
        }
        const sep = sepStr || '';
        const cont = ctxtStr || '';
        const cFunc = context.contextFunctions.lookup(ctxtFunc);
        const ctxtClosure = cFunc
            ? cFunc(nodes, cont)
            : function () {
                return cont;
            };
        const sFunc = context.contextFunctions.lookup(sepFunc);
        const sepClosure = sFunc
            ? sFunc(nodes, sep)
            : function () {
                return [
                    auditory_description_js_1.AuditoryDescription.create({ text: sep }, { translate: true })
                ];
            };
        let result = [];
        for (let i = 0, node; (node = nodes[i]); i++) {
            const descrs = this.evaluateTree_(node);
            if (descrs.length > 0) {
                descrs[0]['context'] = ctxtClosure() + (descrs[0]['context'] || '');
                result = result.concat(descrs);
                if (i < nodes.length - 1) {
                    const text = sepClosure();
                    result = result.concat(text);
                }
            }
        }
        return result;
    }
    addLayout(descrs, props, _multi) {
        const layout = props.layout;
        if (!layout) {
            return;
        }
        if (layout.match(/^begin/)) {
            descrs.unshift(new auditory_description_js_1.AuditoryDescription({ text: '', layout: layout }));
            return;
        }
        if (layout.match(/^end/)) {
            descrs.push(new auditory_description_js_1.AuditoryDescription({ text: '', layout: layout }));
            return;
        }
        descrs.unshift(new auditory_description_js_1.AuditoryDescription({ text: '', layout: `begin${layout}` }));
        descrs.push(new auditory_description_js_1.AuditoryDescription({ text: '', layout: `end${layout}` }));
    }
    addPersonality_(descrs, props, multi, node) {
        const personality = {};
        let pause = null;
        for (const key of EngineConst.personalityPropList) {
            const value = props[key];
            if (typeof value === 'undefined') {
                continue;
            }
            const numeral = parseFloat(value);
            const realValue = isNaN(numeral)
                ? value.charAt(0) === '"'
                    ? value.slice(1, -1)
                    : value
                : numeral;
            if (key === EngineConst.personalityProps.PAUSE) {
                pause = realValue;
            }
            else {
                personality[key] = realValue;
            }
        }
        for (let i = 0, descr; (descr = descrs[i]); i++) {
            this.addRelativePersonality_(descr, personality);
            this.addExternalAttributes_(descr, node);
        }
        if (multi && descrs.length) {
            delete descrs[descrs.length - 1].personality[EngineConst.personalityProps.JOIN];
        }
        if (pause && descrs.length) {
            const last = descrs[descrs.length - 1];
            if (last.text || Object.keys(last.personality).length) {
                descrs.push(auditory_description_js_1.AuditoryDescription.create({
                    text: '',
                    personality: { pause: pause }
                }));
            }
            else {
                last.personality[EngineConst.personalityProps.PAUSE] = pause;
            }
        }
        return descrs;
    }
    addExternalAttributes_(descr, node) {
        if (descr.attributes['id'] === undefined) {
            descr.attributes['id'] = node.getAttribute('id');
        }
        if (node.hasAttributes()) {
            const attrs = node.attributes;
            for (let i = attrs.length - 1; i >= 0; i--) {
                const key = attrs[i].name;
                if (!descr.attributes[key] && key.match(/^ext/)) {
                    descr.attributes[key] = attrs[i].value;
                }
            }
        }
    }
    addRelativePersonality_(descr, personality) {
        if (!descr['personality']) {
            descr['personality'] = personality;
            return descr;
        }
        const descrPersonality = descr['personality'];
        for (const [key, val] of Object.entries(personality)) {
            if (descrPersonality[key] &&
                typeof descrPersonality[key] == 'number' &&
                typeof val == 'number') {
                descrPersonality[key] = (descrPersonality[key] + val).toString();
            }
            else if (!descrPersonality[key]) {
                descrPersonality[key] = val;
            }
        }
        return descr;
    }
    updateConstraint_() {
        const dynamic = engine_js_1.Engine.getInstance().dynamicCstr;
        const strict = engine_js_1.Engine.getInstance().strict;
        const trie = this.trie;
        const props = {};
        let locale = dynamic.getValue(dynamic_cstr_js_1.Axis.LOCALE);
        let modality = dynamic.getValue(dynamic_cstr_js_1.Axis.MODALITY);
        let domain = dynamic.getValue(dynamic_cstr_js_1.Axis.DOMAIN);
        if (!trie.hasSubtrie([locale, modality, domain])) {
            domain = dynamic_cstr_js_1.DynamicCstr.DEFAULT_VALUES[dynamic_cstr_js_1.Axis.DOMAIN];
            if (!trie.hasSubtrie([locale, modality, domain])) {
                modality = dynamic_cstr_js_1.DynamicCstr.DEFAULT_VALUES[dynamic_cstr_js_1.Axis.MODALITY];
                if (!trie.hasSubtrie([locale, modality, domain])) {
                    locale = dynamic_cstr_js_1.DynamicCstr.DEFAULT_VALUES[dynamic_cstr_js_1.Axis.LOCALE];
                }
            }
        }
        props[dynamic_cstr_js_1.Axis.LOCALE] = [locale];
        props[dynamic_cstr_js_1.Axis.MODALITY] = [
            modality !== 'summary'
                ? modality
                : dynamic_cstr_js_1.DynamicCstr.DEFAULT_VALUES[dynamic_cstr_js_1.Axis.MODALITY]
        ];
        props[dynamic_cstr_js_1.Axis.DOMAIN] = [
            modality !== 'speech' ? dynamic_cstr_js_1.DynamicCstr.DEFAULT_VALUES[dynamic_cstr_js_1.Axis.DOMAIN] : domain
        ];
        const order = dynamic.getOrder();
        for (let i = 0, axis; (axis = order[i]); i++) {
            if (!props[axis]) {
                const value = dynamic.getValue(axis);
                const valueSet = this.makeSet_(value, dynamic.preference);
                const def = dynamic_cstr_js_1.DynamicCstr.DEFAULT_VALUES[axis];
                if (!strict && value !== def) {
                    valueSet.push(def);
                }
                props[axis] = valueSet;
            }
        }
        dynamic.updateProperties(props);
    }
    makeSet_(value, preferences) {
        if (!preferences || !Object.keys(preferences).length) {
            return [value];
        }
        return value.split(':');
    }
    lookupRule(node, dynamic) {
        if (!node ||
            (node.nodeType !== DomUtil.NodeType.ELEMENT_NODE &&
                node.nodeType !== DomUtil.NodeType.TEXT_NODE)) {
            return null;
        }
        const matchingRules = this.lookupRules(node, dynamic);
        return matchingRules.length > 0
            ? this.pickMostConstraint_(dynamic, matchingRules)
            : null;
    }
    lookupRules(node, dynamic) {
        return this.trie.lookupRules(node, dynamic.allProperties());
    }
    pickMostConstraint_(_dynamic, rules) {
        const comparator = engine_js_1.Engine.getInstance().comparator;
        rules.sort(function (r1, r2) {
            return (comparator.compare(r1.dynamicCstr, r2.dynamicCstr) ||
                r2.precondition.priority - r1.precondition.priority ||
                r2.precondition.constraints.length -
                    r1.precondition.constraints.length ||
                r2.precondition.rank - r1.precondition.rank);
        });
        debugger_js_1.Debugger.getInstance().generateOutput((() => {
            return rules.map((x) => x.name + '(' + x.dynamicCstr.toString() + ')');
        }).bind(this));
        return rules[0];
    }
}
exports.SpeechRuleEngine = SpeechRuleEngine;
const stores = new Map();
function getStore(locale, modality) {
    if (modality === 'braille' && locale === 'euro') {
        return new braille_store_js_1.EuroStore();
    }
    if (modality === 'braille') {
        return new braille_store_js_1.BrailleStore();
    }
    return new math_store_js_1.MathStore();
}
function storeFactory(set) {
    const name = `${set.locale}.${set.modality}.${set.domain}`;
    if (set.kind === 'actions') {
        const store = stores.get(name);
        store.parse(set);
        return store;
    }
    SpeechRuleStores.init();
    if (set && !set.functions) {
        set.functions = SpeechRules.getStore(set.locale, set.modality, set.domain);
    }
    const store = getStore(set.locale, set.modality);
    stores.set(name, store);
    if (set.inherits) {
        store.inherits = stores.get(`${set.inherits}.${set.modality}.${set.domain}`);
    }
    store.parse(set);
    store.initialize();
    return store;
}
engine_js_1.Engine.nodeEvaluator = SpeechRuleEngine.getInstance().evaluateNode.bind(SpeechRuleEngine.getInstance());
const punctuationMarks = ['⠆', '⠒', '⠲', '⠦', '⠴', '⠄'];
function processAnnotations(descrs) {
    const alist = new auditory_description_js_1.AuditoryList(descrs);
    for (const item of alist.annotations) {
        const descr = item.data;
        if (descr.annotation === 'punctuation') {
            const prev = alist.prevText(item);
            if (!prev)
                continue;
            const last = prev.data;
            if (last.annotation !== 'punctuation' &&
                last.text !== '⠀' &&
                descr.text.length === 1 &&
                punctuationMarks.indexOf(descr.text) !== -1) {
                descr.text = '⠸' + descr.text;
            }
        }
    }
    return alist.toList();
}
