var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
import * as L10n from '../l10n/l10n.js';
import * as MathMap from '../speech_rules/math_map.js';
import * as BrowserUtil from './browser_util.js';
import { Debugger } from './debugger.js';
import { Engine, EnginePromise } from './engine.js';
import * as FileUtil from './file_util.js';
import { SystemExternal } from './system_external.js';
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
        (!feature.modality && Engine.getInstance().modality !== 'speech')) {
        return;
    }
    if (!feature.domain) {
        return;
    }
    if (feature.domain === 'default') {
        feature.domain = 'mathspeak';
        return;
    }
    const locale = (feature.locale || Engine.getInstance().locale);
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
export function setup(feature) {
    return __awaiter(this, void 0, void 0, function* () {
        ensureDomain(feature);
        const engine = Engine.getInstance();
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
        Engine.BINARY_FEATURES.forEach(setIf);
        Engine.STRING_FEATURES.forEach(setMulti);
        if (feature.debug) {
            Debugger.getInstance().init();
        }
        if (feature.json) {
            SystemExternal.jsonPath = FileUtil.makePath(feature.json);
        }
        if (feature.xpath) {
            SystemExternal.WGXpath = feature.xpath;
        }
        engine.setCustomLoader(feature.custom);
        setupBrowsers(engine);
        L10n.setLocale();
        engine.setDynamicCstr();
        if (engine.init) {
            EnginePromise.promises['init'] = new Promise((res, _rej) => {
                setTimeout(() => {
                    res('init');
                }, 10);
            });
            engine.init = false;
            return EnginePromise.get();
        }
        if (engine.delay) {
            engine.delay = false;
            return EnginePromise.get();
        }
        return MathMap.loadLocale();
    });
}
function setupBrowsers(engine) {
    engine.isIE = BrowserUtil.detectIE();
    engine.isEdge = BrowserUtil.detectEdge();
}
