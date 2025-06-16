"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.generator = generator;
const adhoc_speech_generator_js_1 = require("./adhoc_speech_generator.js");
const color_generator_js_1 = require("./color_generator.js");
const direct_speech_generator_js_1 = require("./direct_speech_generator.js");
const dummy_speech_generator_js_1 = require("./dummy_speech_generator.js");
const node_speech_generator_js_1 = require("./node_speech_generator.js");
const summary_speech_generator_js_1 = require("./summary_speech_generator.js");
const tree_speech_generator_js_1 = require("./tree_speech_generator.js");
function generator(type) {
    const constructor = generatorMapping[type] || generatorMapping.Direct;
    return constructor();
}
const generatorMapping = {
    Adhoc: () => new adhoc_speech_generator_js_1.AdhocSpeechGenerator(),
    Color: () => new color_generator_js_1.ColorGenerator(),
    Direct: () => new direct_speech_generator_js_1.DirectSpeechGenerator(),
    Dummy: () => new dummy_speech_generator_js_1.DummySpeechGenerator(),
    Node: () => new node_speech_generator_js_1.NodeSpeechGenerator(),
    Summary: () => new summary_speech_generator_js_1.SummarySpeechGenerator(),
    Tree: () => new tree_speech_generator_js_1.TreeSpeechGenerator()
};
