"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.TreeSpeechGenerator = void 0;
const enrich_attr_js_1 = require("../enrich_mathml/enrich_attr.js");
const WalkerUtil = require("../walker/walker_util.js");
const abstract_speech_generator_js_1 = require("./abstract_speech_generator.js");
const SpeechGeneratorUtil = require("./speech_generator_util.js");
class TreeSpeechGenerator extends abstract_speech_generator_js_1.AbstractSpeechGenerator {
    getSpeech(node, xml, root = null) {
        if (this.getRebuilt()) {
            SpeechGeneratorUtil.connectMactions(node, xml, this.getRebuilt().xml);
        }
        const speech = this.generateSpeech(node, xml);
        const nodes = this.getRebuilt().nodeDict;
        for (const [key, snode] of Object.entries(nodes)) {
            const innerMml = WalkerUtil.getBySemanticId(xml, key);
            const innerNode = WalkerUtil.getBySemanticId(node, key) ||
                (root && WalkerUtil.getBySemanticId(root, key));
            if (!innerMml || !innerNode) {
                continue;
            }
            if (!this.modality || this.modality === enrich_attr_js_1.Attribute.SPEECH) {
                SpeechGeneratorUtil.addSpeech(innerNode, snode, this.getRebuilt().xml);
            }
            else {
                SpeechGeneratorUtil.addModality(innerNode, snode, this.modality);
            }
            if (this.modality === enrich_attr_js_1.Attribute.SPEECH) {
                SpeechGeneratorUtil.addPrefix(innerNode, snode);
            }
        }
        return speech;
    }
}
exports.TreeSpeechGenerator = TreeSpeechGenerator;
