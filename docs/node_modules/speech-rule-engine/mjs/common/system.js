var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
import { Engine, EnginePromise, SREError } from './engine.js';
import { setup } from './engine_setup.js';
import * as EngineConst from './engine_const.js';
import * as FileUtil from './file_util.js';
import * as ProcessorFactory from './processor_factory.js';
import { SystemExternal } from './system_external.js';
import { Variables } from './variables.js';
import { standardLoader } from '../speech_rules/math_map.js';
export const version = Variables.VERSION;
export function setupEngine(feature) {
    return __awaiter(this, void 0, void 0, function* () {
        return setup(feature);
    });
}
export function engineSetup() {
    const engineFeatures = ['mode'].concat(Engine.STRING_FEATURES, Engine.BINARY_FEATURES);
    const engine = Engine.getInstance();
    const features = {};
    engineFeatures.forEach(function (x) {
        features[x] = engine[x];
    });
    features.json = SystemExternal.jsonPath;
    features.xpath = SystemExternal.WGXpath;
    features.rules = engine.ruleSets.slice();
    return features;
}
export function engineReady() {
    return __awaiter(this, void 0, void 0, function* () {
        return setupEngine({}).then(() => EnginePromise.getall());
    });
}
export const localeLoader = standardLoader;
export function toSpeech(expr) {
    return processString('speech', expr);
}
export function toSemantic(expr) {
    return processString('semantic', expr);
}
export function toJson(expr) {
    return processString('json', expr);
}
export function toDescription(expr) {
    return processString('description', expr);
}
export function toEnriched(expr) {
    return processString('enriched', expr);
}
export function number(expr) {
    return processString('number', expr);
}
export function ordinal(expr) {
    return processString('ordinal', expr);
}
export function numericOrdinal(expr) {
    return processString('numericOrdinal', expr);
}
export function vulgar(expr) {
    return processString('vulgar', expr);
}
function processString(processor, input) {
    return ProcessorFactory.process(processor, input);
}
export const file = {};
file.toSpeech = function (input, opt_output) {
    return processFile('speech', input, opt_output);
};
file.toSemantic = function (input, opt_output) {
    return processFile('semantic', input, opt_output);
};
file.toJson = function (input, opt_output) {
    return processFile('json', input, opt_output);
};
file.toDescription = function (input, opt_output) {
    return processFile('description', input, opt_output);
};
file.toEnriched = function (input, opt_output) {
    return processFile('enriched', input, opt_output);
};
export function processFile(processor, input, opt_output) {
    switch (Engine.getInstance().mode) {
        case EngineConst.Mode.ASYNC:
            return processFileAsync(processor, input, opt_output);
        case EngineConst.Mode.SYNC:
            return processFileSync(processor, input, opt_output);
        default:
            throw new SREError(`Can process files in ${Engine.getInstance().mode} mode`);
    }
}
function processFileSync(processor, input, opt_output) {
    const expr = inputFileSync_(input);
    const result = ProcessorFactory.output(processor, expr);
    if (opt_output) {
        try {
            SystemExternal.fs.writeFileSync(opt_output, result);
        }
        catch (_err) {
            throw new SREError('Can not write to file: ' + opt_output);
        }
    }
    return result;
}
function inputFileSync_(file) {
    let expr;
    try {
        expr = SystemExternal.fs.readFileSync(file, { encoding: 'utf8' });
    }
    catch (_err) {
        throw new SREError('Can not open file: ' + file);
    }
    return expr;
}
function processFileAsync(processor, file, output) {
    return __awaiter(this, void 0, void 0, function* () {
        const expr = yield SystemExternal.fs.promises.readFile(file, {
            encoding: 'utf8'
        });
        const result = ProcessorFactory.output(processor, expr);
        if (output) {
            try {
                SystemExternal.fs.promises.writeFile(output, result);
            }
            catch (_err) {
                throw new SREError('Can not write to file: ' + output);
            }
        }
        return result;
    });
}
export function walk(expr) {
    return ProcessorFactory.output('walker', expr);
}
export function move(direction) {
    return ProcessorFactory.keypress('move', direction);
}
export function exit(opt_value) {
    const value = opt_value || 0;
    EnginePromise.getall().then(() => process.exit(value));
}
export const localePath = FileUtil.localePath;
if (SystemExternal.documentSupported) {
    setupEngine({ mode: EngineConst.Mode.HTTP }).then(() => setupEngine({}));
}
else {
    setupEngine({ mode: EngineConst.Mode.SYNC }).then(() => setupEngine({ mode: EngineConst.Mode.ASYNC }));
}
