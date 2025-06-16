"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.DummySpeechGenerator = void 0;
const abstract_speech_generator_js_1 = require("./abstract_speech_generator.js");
class DummySpeechGenerator extends abstract_speech_generator_js_1.AbstractSpeechGenerator {
    getSpeech(_node, _xml) {
        return '';
    }
}
exports.DummySpeechGenerator = DummySpeechGenerator;
