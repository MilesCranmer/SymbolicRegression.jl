"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.Grammar = exports.ATTRIBUTE = void 0;
exports.correctFont = correctFont;
const DomUtil = require("../common/dom_util.js");
const engine_js_1 = require("../common/engine.js");
const LocaleUtil = require("../l10n/locale_util.js");
const locale_js_1 = require("../l10n/locale.js");
exports.ATTRIBUTE = 'grammar';
class Grammar {
    static getInstance() {
        Grammar.instance = Grammar.instance || new Grammar();
        return Grammar.instance;
    }
    static parseInput(grammar) {
        const attributes = {};
        const components = grammar.split(':');
        for (const component of components) {
            const comp = component.split('=');
            const key = comp[0].trim();
            if (comp[1]) {
                attributes[key] = comp[1].trim();
                continue;
            }
            key.match(/^!/)
                ? (attributes[key.slice(1)] = false)
                : (attributes[key] = true);
        }
        return attributes;
    }
    static parseState(stateStr) {
        const state = {};
        const corrections = stateStr.split(' ');
        for (const correction of corrections) {
            const corr = correction.split(':');
            const key = corr[0];
            const value = corr[1];
            state[key] = value ? value : true;
        }
        return state;
    }
    static translateString(text) {
        if (text.match(/:unit$/)) {
            return Grammar.translateUnit(text);
        }
        const engine = engine_js_1.Engine.getInstance();
        let result = engine.evaluator(text, engine.dynamicCstr);
        result = result === null ? text : result;
        if (Grammar.getInstance().getParameter('plural')) {
            result = locale_js_1.LOCALE.FUNCTIONS.plural(result);
        }
        return result;
    }
    static translateUnit(text) {
        text = Grammar.prepareUnit(text);
        const engine = engine_js_1.Engine.getInstance();
        const plural = Grammar.getInstance().getParameter('plural');
        const strict = engine.strict;
        const baseCstr = `${engine.locale}.${engine.modality}.default`;
        engine.strict = true;
        let cstr;
        let result;
        if (plural) {
            cstr = engine.defaultParser.parse(baseCstr + '.plural');
            result = engine.evaluator(text, cstr);
        }
        if (result) {
            engine.strict = strict;
            return result;
        }
        cstr = engine.defaultParser.parse(baseCstr + '.default');
        result = engine.evaluator(text, cstr);
        engine.strict = strict;
        if (!result) {
            return Grammar.cleanUnit(text);
        }
        if (plural) {
            result = locale_js_1.LOCALE.FUNCTIONS.plural(result);
        }
        return result;
    }
    static prepareUnit(text) {
        const match = text.match(/:unit$/);
        return match
            ? text.slice(0, match.index).replace(/\s+/g, ' ') +
                text.slice(match.index)
            : text;
    }
    static cleanUnit(text) {
        if (text.match(/:unit$/)) {
            return text.replace(/:unit$/, '');
        }
        return text;
    }
    clear() {
        this.parameters_ = {};
        this.stateStack_ = [];
    }
    setParameter(parameter, value) {
        const oldValue = this.parameters_[parameter];
        value
            ? (this.parameters_[parameter] = value)
            : delete this.parameters_[parameter];
        return oldValue;
    }
    getParameter(parameter) {
        return this.parameters_[parameter];
    }
    setCorrection(correction, func) {
        this.corrections_[correction] = func;
    }
    setPreprocessor(preprocessor, func) {
        this.preprocessors_[preprocessor] = func;
    }
    getCorrection(correction) {
        return this.corrections_[correction];
    }
    getState() {
        const pairs = [];
        for (const [key, val] of Object.entries(this.parameters_)) {
            pairs.push(typeof val === 'string' ? key + ':' + val : key);
        }
        return pairs.join(' ');
    }
    processSingles() {
        const assignment = {};
        for (const single of this.singles) {
            assignment[single] = false;
        }
        this.singles = [];
        this.pushState(assignment);
    }
    pushState(assignment) {
        for (let [key, value] of Object.entries(assignment)) {
            if (key.match(/^\?/)) {
                delete assignment[key];
                key = key.slice(1);
                this.singles.push(key);
            }
            assignment[key] = this.setParameter(key, value);
        }
        this.stateStack_.push(assignment);
    }
    popState() {
        const assignment = this.stateStack_.pop();
        for (const [key, val] of Object.entries(assignment)) {
            this.setParameter(key, val);
        }
    }
    setAttribute(node) {
        if (node && node.nodeType === DomUtil.NodeType.ELEMENT_NODE) {
            const state = this.getState();
            if (state) {
                node.setAttribute(exports.ATTRIBUTE, state);
            }
        }
    }
    preprocess(text) {
        return this.runProcessors(text, this.preprocessors_);
    }
    correct(text) {
        return this.runProcessors(text, this.corrections_);
    }
    apply(text, opt_flags) {
        this.currentFlags = opt_flags || {};
        text =
            this.currentFlags.adjust || this.currentFlags.preprocess
                ? Grammar.getInstance().preprocess(text)
                : text;
        if (this.parameters_['translate'] || this.currentFlags.translate) {
            text = Grammar.translateString(text);
        }
        text =
            this.currentFlags.adjust || this.currentFlags.correct
                ? Grammar.getInstance().correct(text)
                : text;
        this.currentFlags = {};
        return text;
    }
    runProcessors(text, funcs) {
        for (const [key, val] of Object.entries(this.parameters_)) {
            const func = funcs[key];
            if (!func) {
                continue;
            }
            text = val === true ? func(text) : func(text, val);
        }
        return text;
    }
    constructor() {
        this.currentFlags = {};
        this.parameters_ = {};
        this.corrections_ = {};
        this.preprocessors_ = {};
        this.stateStack_ = [];
        this.singles = [];
    }
}
exports.Grammar = Grammar;
function correctFont(text, correction) {
    if (!correction || !text) {
        return text;
    }
    const regexp = locale_js_1.LOCALE.FUNCTIONS.fontRegexp(LocaleUtil.localFont(correction));
    return text.replace(regexp, '');
}
function correctCaps(text) {
    let cap = locale_js_1.LOCALE.ALPHABETS.capPrefix[engine_js_1.Engine.getInstance().domain];
    if (typeof cap === 'undefined') {
        cap = locale_js_1.LOCALE.ALPHABETS.capPrefix['default'];
    }
    return correctFont(text, cap);
}
function addAnnotation(text, annotation) {
    return text + ':' + annotation;
}
function numbersToAlpha(text) {
    return text.match(/\d+/)
        ? locale_js_1.LOCALE.NUMBERS.numberToWords(parseInt(text, 10))
        : text;
}
function noTranslateText(text) {
    if (text.match(new RegExp('^[' + locale_js_1.LOCALE.MESSAGES.regexp.TEXT + ']+$'))) {
        Grammar.getInstance().currentFlags['translate'] = false;
    }
    return text;
}
Grammar.getInstance().setCorrection('localFont', LocaleUtil.localFont);
Grammar.getInstance().setCorrection('localRole', LocaleUtil.localRole);
Grammar.getInstance().setCorrection('localEnclose', LocaleUtil.localEnclose);
Grammar.getInstance().setCorrection('ignoreFont', correctFont);
Grammar.getInstance().setPreprocessor('annotation', addAnnotation);
Grammar.getInstance().setPreprocessor('noTranslateText', noTranslateText);
Grammar.getInstance().setCorrection('ignoreCaps', correctCaps);
Grammar.getInstance().setPreprocessor('numbers2alpha', numbersToAlpha);
