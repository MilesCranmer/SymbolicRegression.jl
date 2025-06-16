"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.DirectSpeechGenerator = void 0;
const WalkerUtil = require("../walker/walker_util.js");
const abstract_speech_generator_js_1 = require("./abstract_speech_generator.js");
class DirectSpeechGenerator extends abstract_speech_generator_js_1.AbstractSpeechGenerator {
    getSpeech(node, _xml) {
        return WalkerUtil.getAttribute(node, this.modality);
    }
}
exports.DirectSpeechGenerator = DirectSpeechGenerator;
