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
exports.localePath = exports.file = exports.localeLoader = exports.version = void 0;
exports.setupEngine = setupEngine;
exports.engineSetup = engineSetup;
exports.engineReady = engineReady;
exports.toSpeech = toSpeech;
exports.toSemantic = toSemantic;
exports.toJson = toJson;
exports.toDescription = toDescription;
exports.toEnriched = toEnriched;
exports.number = number;
exports.ordinal = ordinal;
exports.numericOrdinal = numericOrdinal;
exports.vulgar = vulgar;
exports.processFile = processFile;
exports.walk = walk;
exports.move = move;
exports.exit = exit;
const engine_js_1 = require("./engine.js");
const engine_setup_js_1 = require("./engine_setup.js");
const EngineConst = require("./engine_const.js");
const FileUtil = require("./file_util.js");
const ProcessorFactory = require("./processor_factory.js");
const system_external_js_1 = require("./system_external.js");
const variables_js_1 = require("./variables.js");
const math_map_js_1 = require("../speech_rules/math_map.js");
exports.version = variables_js_1.Variables.VERSION;
function setupEngine(feature) {
    return __awaiter(this, void 0, void 0, function* () {
        return (0, engine_setup_js_1.setup)(feature);
    });
}
function engineSetup() {
    const engineFeatures = ['mode'].concat(engine_js_1.Engine.STRING_FEATURES, engine_js_1.Engine.BINARY_FEATURES);
    const engine = engine_js_1.Engine.getInstance();
    const features = {};
    engineFeatures.forEach(function (x) {
        features[x] = engine[x];
    });
    features.json = system_external_js_1.SystemExternal.jsonPath;
    features.xpath = system_external_js_1.SystemExternal.WGXpath;
    features.rules = engine.ruleSets.slice();
    return features;
}
function engineReady() {
    return __awaiter(this, void 0, void 0, function* () {
        return setupEngine({}).then(() => engine_js_1.EnginePromise.getall());
    });
}
exports.localeLoader = math_map_js_1.standardLoader;
function toSpeech(expr) {
    return processString('speech', expr);
}
function toSemantic(expr) {
    return processString('semantic', expr);
}
function toJson(expr) {
    return processString('json', expr);
}
function toDescription(expr) {
    return processString('description', expr);
}
function toEnriched(expr) {
    return processString('enriched', expr);
}
function number(expr) {
    return processString('number', expr);
}
function ordinal(expr) {
    return processString('ordinal', expr);
}
function numericOrdinal(expr) {
    return processString('numericOrdinal', expr);
}
function vulgar(expr) {
    return processString('vulgar', expr);
}
function processString(processor, input) {
    return ProcessorFactory.process(processor, input);
}
exports.file = {};
exports.file.toSpeech = function (input, opt_output) {
    return processFile('speech', input, opt_output);
};
exports.file.toSemantic = function (input, opt_output) {
    return processFile('semantic', input, opt_output);
};
exports.file.toJson = function (input, opt_output) {
    return processFile('json', input, opt_output);
};
exports.file.toDescription = function (input, opt_output) {
    return processFile('description', input, opt_output);
};
exports.file.toEnriched = function (input, opt_output) {
    return processFile('enriched', input, opt_output);
};
function processFile(processor, input, opt_output) {
    switch (engine_js_1.Engine.getInstance().mode) {
        case EngineConst.Mode.ASYNC:
            return processFileAsync(processor, input, opt_output);
        case EngineConst.Mode.SYNC:
            return processFileSync(processor, input, opt_output);
        default:
            throw new engine_js_1.SREError(`Can process files in ${engine_js_1.Engine.getInstance().mode} mode`);
    }
}
function processFileSync(processor, input, opt_output) {
    const expr = inputFileSync_(input);
    const result = ProcessorFactory.output(processor, expr);
    if (opt_output) {
        try {
            system_external_js_1.SystemExternal.fs.writeFileSync(opt_output, result);
        }
        catch (_err) {
            throw new engine_js_1.SREError('Can not write to file: ' + opt_output);
        }
    }
    return result;
}
function inputFileSync_(file) {
    let expr;
    try {
        expr = system_external_js_1.SystemExternal.fs.readFileSync(file, { encoding: 'utf8' });
    }
    catch (_err) {
        throw new engine_js_1.SREError('Can not open file: ' + file);
    }
    return expr;
}
function processFileAsync(processor, file, output) {
    return __awaiter(this, void 0, void 0, function* () {
        const expr = yield system_external_js_1.SystemExternal.fs.promises.readFile(file, {
            encoding: 'utf8'
        });
        const result = ProcessorFactory.output(processor, expr);
        if (output) {
            try {
                system_external_js_1.SystemExternal.fs.promises.writeFile(output, result);
            }
            catch (_err) {
                throw new engine_js_1.SREError('Can not write to file: ' + output);
            }
        }
        return result;
    });
}
function walk(expr) {
    return ProcessorFactory.output('walker', expr);
}
function move(direction) {
    return ProcessorFactory.keypress('move', direction);
}
function exit(opt_value) {
    const value = opt_value || 0;
    engine_js_1.EnginePromise.getall().then(() => process.exit(value));
}
exports.localePath = FileUtil.localePath;
if (system_external_js_1.SystemExternal.documentSupported) {
    setupEngine({ mode: EngineConst.Mode.HTTP }).then(() => setupEngine({}));
}
else {
    setupEngine({ mode: EngineConst.Mode.SYNC }).then(() => setupEngine({ mode: EngineConst.Mode.ASYNC }));
}
