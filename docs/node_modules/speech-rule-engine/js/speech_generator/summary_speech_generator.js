"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.SummarySpeechGenerator = void 0;
const abstract_speech_generator_js_1 = require("./abstract_speech_generator.js");
const SpeechGeneratorUtil = require("./speech_generator_util.js");
const engine_setup_js_1 = require("../common/engine_setup.js");
const enrich_attr_js_1 = require("../enrich_mathml/enrich_attr.js");
class SummarySpeechGenerator extends abstract_speech_generator_js_1.AbstractSpeechGenerator {
    getSpeech(node, _xml) {
        (0, engine_setup_js_1.setup)(this.getOptions());
        const id = node.getAttribute(enrich_attr_js_1.Attribute.ID);
        const snode = this.getRebuilt().streeRoot.querySelectorAll((x) => x.id.toString() === id)[0];
        SpeechGeneratorUtil.addModality(node, snode, this.modality);
        const speech = node.getAttribute(enrich_attr_js_1.Attribute.SUMMARY);
        return speech;
    }
}
exports.SummarySpeechGenerator = SummarySpeechGenerator;
