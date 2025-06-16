var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
import * as BrowserUtil from '../common/browser_util.js';
import { Engine, EnginePromise } from '../common/engine.js';
import * as EngineConst from '../common/engine_const.js';
import * as FileUtil from '../common/file_util.js';
import { SystemExternal } from '../common/system_external.js';
import { DynamicCstr } from '../rule_engine/dynamic_cstr.js';
import * as MathCompoundStore from '../rule_engine/math_compound_store.js';
import { SpeechRuleEngine } from '../rule_engine/speech_rule_engine.js';
import { completeLocale } from '../l10n/l10n.js';
import * as AlphabetGenerator from './alphabet_generator.js';
const addSymbols = {
    functions: MathCompoundStore.addFunctionRules,
    symbols: MathCompoundStore.addSymbolRules,
    units: MathCompoundStore.addUnitRules,
    si: (x) => x.forEach(MathCompoundStore.setSiPrefixes),
    messages: completeLocale,
    rules: SpeechRuleEngine.addStore,
    characters: MathCompoundStore.addCharacterRules
};
let _init = false;
export function loadLocale() {
    return __awaiter(this, arguments, void 0, function* (locale = Engine.getInstance().locale) {
        if (!_init) {
            AlphabetGenerator.generateBase();
            _loadLocale(DynamicCstr.BASE_LOCALE);
            _init = true;
        }
        return EnginePromise.promises[DynamicCstr.BASE_LOCALE].then(() => __awaiter(this, void 0, void 0, function* () {
            const defLoc = Engine.getInstance().defaultLocale;
            if (defLoc) {
                _loadLocale(defLoc);
                return EnginePromise.promises[defLoc].then(() => __awaiter(this, void 0, void 0, function* () {
                    _loadLocale(locale);
                    return EnginePromise.promises[locale];
                }));
            }
            _loadLocale(locale);
            return EnginePromise.promises[locale];
        }));
    });
}
function _loadLocale(locale = Engine.getInstance().locale) {
    if (!EnginePromise.loaded[locale]) {
        EnginePromise.loaded[locale] = [false, false];
        MathCompoundStore.reset();
        retrieveMaps(locale);
    }
}
function loadMethod() {
    if (Engine.getInstance().customLoader) {
        return Engine.getInstance().customLoader;
    }
    return standardLoader();
}
export function standardLoader() {
    switch (Engine.getInstance().mode) {
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
            EnginePromise.loaded[locale] = [true, true];
            res(locale);
        }, (_err) => {
            EnginePromise.loaded[locale] = [true, false];
            console.error(`Unable to load locale: ${locale}`);
            Engine.getInstance().locale = Engine.getInstance().defaultLocale;
            res(locale);
        });
    });
    EnginePromise.promises[locale] = promise;
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
    if (Engine.getInstance().isIE &&
        Engine.getInstance().mode === EngineConst.Mode.HTTP) {
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
        SystemExternal.fs.readFile(file, 'utf8', (err, json) => {
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
            str = SystemExternal.fs.readFileSync(file, 'utf8');
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
