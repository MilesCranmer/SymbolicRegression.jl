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
exports.loadLocale = loadLocale;
exports.standardLoader = standardLoader;
const BrowserUtil = require("../common/browser_util.js");
const engine_js_1 = require("../common/engine.js");
const EngineConst = require("../common/engine_const.js");
const FileUtil = require("../common/file_util.js");
const system_external_js_1 = require("../common/system_external.js");
const dynamic_cstr_js_1 = require("../rule_engine/dynamic_cstr.js");
const MathCompoundStore = require("../rule_engine/math_compound_store.js");
const speech_rule_engine_js_1 = require("../rule_engine/speech_rule_engine.js");
const l10n_js_1 = require("../l10n/l10n.js");
const AlphabetGenerator = require("./alphabet_generator.js");
const addSymbols = {
    functions: MathCompoundStore.addFunctionRules,
    symbols: MathCompoundStore.addSymbolRules,
    units: MathCompoundStore.addUnitRules,
    si: (x) => x.forEach(MathCompoundStore.setSiPrefixes),
    messages: l10n_js_1.completeLocale,
    rules: speech_rule_engine_js_1.SpeechRuleEngine.addStore,
    characters: MathCompoundStore.addCharacterRules
};
let _init = false;
function loadLocale() {
    return __awaiter(this, arguments, void 0, function* (locale = engine_js_1.Engine.getInstance().locale) {
        if (!_init) {
            AlphabetGenerator.generateBase();
            _loadLocale(dynamic_cstr_js_1.DynamicCstr.BASE_LOCALE);
            _init = true;
        }
        return engine_js_1.EnginePromise.promises[dynamic_cstr_js_1.DynamicCstr.BASE_LOCALE].then(() => __awaiter(this, void 0, void 0, function* () {
            const defLoc = engine_js_1.Engine.getInstance().defaultLocale;
            if (defLoc) {
                _loadLocale(defLoc);
                return engine_js_1.EnginePromise.promises[defLoc].then(() => __awaiter(this, void 0, void 0, function* () {
                    _loadLocale(locale);
                    return engine_js_1.EnginePromise.promises[locale];
                }));
            }
            _loadLocale(locale);
            return engine_js_1.EnginePromise.promises[locale];
        }));
    });
}
function _loadLocale(locale = engine_js_1.Engine.getInstance().locale) {
    if (!engine_js_1.EnginePromise.loaded[locale]) {
        engine_js_1.EnginePromise.loaded[locale] = [false, false];
        MathCompoundStore.reset();
        retrieveMaps(locale);
    }
}
function loadMethod() {
    if (engine_js_1.Engine.getInstance().customLoader) {
        return engine_js_1.Engine.getInstance().customLoader;
    }
    return standardLoader();
}
function standardLoader() {
    switch (engine_js_1.Engine.getInstance().mode) {
        case EngineConst.Mode.ASYNC:
            return loadFile;
        case EngineConst.Mode.HTTP:
            return loadAjax;
        case EngineConst.Mode.SYNC:
        default:
            return loadFileSync;
    }
}
function retrieveFiles(locale) {
    const loader = loadMethod();
    const promise = new Promise((res) => {
        const inner = loader(locale);
        inner.then((str) => {
            parseMaps(str);
            engine_js_1.EnginePromise.loaded[locale] = [true, true];
            res(locale);
        }, (_err) => {
            engine_js_1.EnginePromise.loaded[locale] = [true, false];
            console.error(`Unable to load locale: ${locale}`);
            engine_js_1.Engine.getInstance().locale = engine_js_1.Engine.getInstance().defaultLocale;
            res(locale);
        });
    });
    engine_js_1.EnginePromise.promises[locale] = promise;
}
function parseMaps(json) {
    const js = typeof json === 'string'
        ? JSON.parse(json)
        : json;
    addMaps(js);
}
function addMaps(json, opt_locale) {
    let generate = true;
    for (let i = 0, key; (key = Object.keys(json)[i]); i++) {
        const info = key.split('/');
        if (opt_locale && opt_locale !== info[0]) {
            continue;
        }
        if (generate && info[1] === 'symbols' && info[0] !== 'base') {
            AlphabetGenerator.generate(info[0]);
            generate = false;
        }
        addSymbols[info[1]](json[key]);
    }
}
function retrieveMaps(locale) {
    if (engine_js_1.Engine.getInstance().isIE &&
        engine_js_1.Engine.getInstance().mode === EngineConst.Mode.HTTP) {
        getJsonIE_(locale);
        return;
    }
    retrieveFiles(locale);
}
function getJsonIE_(locale, opt_count) {
    let count = opt_count || 1;
    if (!BrowserUtil.mapsForIE) {
        if (count <= 5) {
            setTimeout((() => getJsonIE_(locale, count++)).bind(this), 300);
        }
        return;
    }
    addMaps(BrowserUtil.mapsForIE, locale);
}
function loadFile(locale) {
    const file = FileUtil.localePath(locale);
    return new Promise((res, rej) => {
        system_external_js_1.SystemExternal.fs.readFile(file, 'utf8', (err, json) => {
            if (err) {
                return rej(err);
            }
            res(json);
        });
    });
}
function loadFileSync(locale) {
    const file = FileUtil.localePath(locale);
    return new Promise((res, rej) => {
        let str = '{}';
        try {
            str = system_external_js_1.SystemExternal.fs.readFileSync(file, 'utf8');
        }
        catch (err) {
            return rej(err);
        }
        res(str);
    });
}
function loadAjax(locale) {
    const file = FileUtil.localePath(locale);
    const httpRequest = new XMLHttpRequest();
    return new Promise((res, rej) => {
        httpRequest.onreadystatechange = function () {
            if (httpRequest.readyState === 4) {
                const status = httpRequest.status;
                if (status === 0 || (status >= 200 && status < 400)) {
                    res(httpRequest.responseText);
                }
                else {
                    rej(status);
                }
            }
        };
        httpRequest.open('GET', file, true);
        httpRequest.send();
    });
}
