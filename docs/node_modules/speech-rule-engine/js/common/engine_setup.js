"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.setup = setup;
const L10n = require("../l10n/l10n.js");
const MathMap = require("../speech_rules/math_map.js");
const BrowserUtil = require("./browser_util.js");
const debugger_js_1 = require("./debugger.js");
const engine_js_1 = require("./engine.js");
const FileUtil = require("./file_util.js");
const system_external_js_1 = require("./system_external.js");
const MATHSPEAK_ONLY = ['ca', 'da', 'es'];
const EN_RULES = [
    'chromevox',
    'clearspeak',
    'mathspeak',
    'emacspeak',
    'html'
];
function ensureDomain(feature) {
    if ((feature.modality && feature.modality !== 'speech') ||
        (!feature.modality && engine_js_1.Engine.getInstance().modality !== 'speech')) {
        return;
    }
    if (!feature.domain) {
        return;
    }
    if (feature.domain === 'default') {
        feature.domain = 'mathspeak';
        return;
    }
    const locale = (feature.locale || engine_js_1.Engine.getInstance().locale);
    const domain = feature.domain;
    if (MATHSPEAK_ONLY.indexOf(locale) !== -1) {
        if (domain !== 'mathspeak') {
            feature.domain = 'mathspeak';
        }
        return;
    }
    if (locale === 'en') {
        if (EN_RULES.indexOf(domain) === -1) {
            feature.domain = 'mathspeak';
        }
        return;
    }
    if (domain !== 'mathspeak' && domain !== 'clearspeak') {
        feature.domain = 'mathspeak';
    }
}
function setup(feature) {
    return __awaiter(this, void 0, void 0, function* () {
        ensureDomain(feature);
        const engine = engine_js_1.Engine.getInstance();
        const setIf = (feat) => {
            if (typeof feature[feat] !== 'undefined') {
                engine[feat] = !!feature[feat];
            }
        };
        const setMulti = (feat) => {
            if (typeof feature[feat] !== 'undefined') {
                engine[feat] = feature[feat];
            }
        };
        setMulti('mode');
        engine.configurate(feature);
        engine_js_1.Engine.BINARY_FEATURES.forEach(setIf);
        engine_js_1.Engine.STRING_FEATURES.forEach(setMulti);
        if (feature.debug) {
            debugger_js_1.Debugger.getInstance().init();
        }
        if (feature.json) {
            system_external_js_1.SystemExternal.jsonPath = FileUtil.makePath(feature.json);
        }
        if (feature.xpath) {
            system_external_js_1.SystemExternal.WGXpath = feature.xpath;
        }
        engine.setCustomLoader(feature.custom);
        setupBrowsers(engine);
        L10n.setLocale();
        engine.setDynamicCstr();
        if (engine.init) {
            engine_js_1.EnginePromise.promises['init'] = new Promise((res, _rej) => {
                setTimeout(() => {
                    res('init');
                }, 10);
            });
            engine.init = false;
            return engine_js_1.EnginePromise.get();
        }
        if (engine.delay) {
            engine.delay = false;
            return engine_js_1.EnginePromise.get();
        }
        return MathMap.loadLocale();
    });
}
function setupBrowsers(engine) {
    engine.isIE = BrowserUtil.detectIE();
    engine.isEdge = BrowserUtil.detectEdge();
}
