"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.EnginePromise = exports.Engine = exports.SREError = void 0;
const Dcstr = require("../rule_engine/dynamic_cstr.js");
const EngineConst = require("./engine_const.js");
const debugger_js_1 = require("./debugger.js");
const variables_js_1 = require("./variables.js");
class SREError extends Error {
    constructor(message = '') {
        super();
        this.message = message;
        this.name = 'SRE Error';
    }
}
exports.SREError = SREError;
class Engine {
    set defaultLocale(loc) {
        this._defaultLocale = variables_js_1.Variables.ensureLocale(loc, this._defaultLocale);
    }
    get defaultLocale() {
        return this._defaultLocale;
    }
    static getInstance() {
        Engine.instance = Engine.instance || new Engine();
        return Engine.instance;
    }
    static defaultEvaluator(str, _cstr) {
        return str;
    }
    static evaluateNode(node) {
        return Engine.nodeEvaluator(node);
    }
    getRate() {
        const numeric = parseInt(this.rate, 10);
        return isNaN(numeric) ? 100 : numeric;
    }
    setDynamicCstr(opt_dynamic) {
        if (this.defaultLocale) {
            Dcstr.DynamicCstr.DEFAULT_VALUES[Dcstr.Axis.LOCALE] = this.defaultLocale;
        }
        if (opt_dynamic) {
            const keys = Object.keys(opt_dynamic);
            for (let i = 0; i < keys.length; i++) {
                const feature = keys[i];
                if (Dcstr.DynamicCstr.DEFAULT_ORDER.indexOf(feature) !== -1) {
                    const value = opt_dynamic[feature];
                    this[feature] = value;
                }
            }
        }
        EngineConst.DOMAIN_TO_STYLES[this.domain] = this.style;
        const dynamic = [this.locale, this.modality, this.domain, this.style].join('.');
        const fallback = Dcstr.DynamicProperties.createProp([Dcstr.DynamicCstr.DEFAULT_VALUES[Dcstr.Axis.LOCALE]], [Dcstr.DynamicCstr.DEFAULT_VALUES[Dcstr.Axis.MODALITY]], [Dcstr.DynamicCstr.DEFAULT_VALUES[Dcstr.Axis.DOMAIN]], [Dcstr.DynamicCstr.DEFAULT_VALUES[Dcstr.Axis.STYLE]]);
        const comparator = this.comparators[this.domain];
        const parser = this.parsers[this.domain];
        this.parser = parser ? parser : this.defaultParser;
        this.dynamicCstr = this.parser.parse(dynamic);
        this.dynamicCstr.updateProperties(fallback.getProperties());
        this.comparator = comparator
            ? comparator()
            : new Dcstr.DefaultComparator(this.dynamicCstr);
    }
    constructor() {
        this.customLoader = null;
        this.parsers = {};
        this.comparator = null;
        this.mode = EngineConst.Mode.SYNC;
        this.init = true;
        this.delay = false;
        this.comparators = {};
        this.domain = 'mathspeak';
        this.style = Dcstr.DynamicCstr.DEFAULT_VALUES[Dcstr.Axis.STYLE];
        this._defaultLocale = Dcstr.DynamicCstr.DEFAULT_VALUES[Dcstr.Axis.LOCALE];
        this.locale = Dcstr.DynamicCstr.DEFAULT_VALUES[Dcstr.Axis.LOCALE];
        this.subiso = '';
        this.modality = Dcstr.DynamicCstr.DEFAULT_VALUES[Dcstr.Axis.MODALITY];
        this.speech = EngineConst.Speech.NONE;
        this.markup = EngineConst.Markup.NONE;
        this.mark = true;
        this.automark = false;
        this.character = true;
        this.cleanpause = true;
        this.cayleyshort = true;
        this.linebreaks = false;
        this.rate = '100';
        this.walker = 'Table';
        this.structure = false;
        this.aria = false;
        this.ruleSets = [];
        this.strict = false;
        this.isIE = false;
        this.isEdge = false;
        this.pprint = false;
        this.config = false;
        this.rules = '';
        this.prune = '';
        this.locale = this.defaultLocale;
        this.evaluator = Engine.defaultEvaluator;
        this.defaultParser = new Dcstr.DynamicCstrParser(Dcstr.DynamicCstr.DEFAULT_ORDER);
        this.parser = this.defaultParser;
        this.dynamicCstr = Dcstr.DynamicCstr.defaultCstr();
    }
    configurate(feature) {
        if (this.mode === EngineConst.Mode.HTTP && !this.config) {
            configBlocks(feature);
            this.config = true;
        }
        configFeature(feature);
    }
    setCustomLoader(fn) {
        if (fn) {
            this.customLoader = fn;
        }
    }
}
exports.Engine = Engine;
Engine.BINARY_FEATURES = [
    'automark',
    'mark',
    'character',
    'cleanpause',
    'strict',
    'structure',
    'aria',
    'pprint',
    'cayleyshort',
    'linebreaks'
];
Engine.STRING_FEATURES = [
    'markup',
    'style',
    'domain',
    'speech',
    'walker',
    'defaultLocale',
    'locale',
    'delay',
    'modality',
    'rate',
    'rules',
    'subiso',
    'prune'
];
Engine.nodeEvaluator = function (_node) {
    return [];
};
exports.default = Engine;
function configFeature(feature) {
    if (typeof SREfeature !== 'undefined') {
        for (const [name, feat] of Object.entries(SREfeature)) {
            feature[name] = feat;
        }
    }
}
function configBlocks(feature) {
    const scripts = document.documentElement.querySelectorAll('script[type="text/x-sre-config"]');
    for (let i = 0, m = scripts.length; i < m; i++) {
        let inner;
        try {
            inner = scripts[i].innerHTML;
            const config = JSON.parse(inner);
            for (const [key, val] of Object.entries(config)) {
                feature[key] = val;
            }
        }
        catch (_err) {
            debugger_js_1.Debugger.getInstance().output('Illegal configuration ', inner);
        }
    }
}
class EnginePromise {
    static get(locale = Engine.getInstance().locale) {
        return EnginePromise.promises[locale] || Promise.resolve('');
    }
    static getall() {
        return Promise.all(Object.values(EnginePromise.promises));
    }
}
exports.EnginePromise = EnginePromise;
EnginePromise.loaded = {};
EnginePromise.promises = {};
