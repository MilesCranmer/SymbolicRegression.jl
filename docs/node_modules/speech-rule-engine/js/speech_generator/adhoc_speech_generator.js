"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AdhocSpeechGenerator = void 0;
const abstract_speech_generator_js_1 = require("./abstract_speech_generator.js");
class AdhocSpeechGenerator extends abstract_speech_generator_js_1.AbstractSpeechGenerator {
    getSpeech(node, xml) {
        const speech = this.generateSpeech(node, xml);
        node.setAttribute(this.modality, speech);
        return speech;
    }
}
exports.AdhocSpeechGenerator = AdhocSpeechGenerator;
