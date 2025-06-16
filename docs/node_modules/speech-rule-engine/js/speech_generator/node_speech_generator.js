"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.NodeSpeechGenerator = void 0;
const WalkerUtil = require("../walker/walker_util.js");
const tree_speech_generator_js_1 = require("./tree_speech_generator.js");
class NodeSpeechGenerator extends tree_speech_generator_js_1.TreeSpeechGenerator {
    getSpeech(node, _xml) {
        super.getSpeech(node, _xml);
        return WalkerUtil.getAttribute(node, this.modality);
    }
}
exports.NodeSpeechGenerator = NodeSpeechGenerator;
