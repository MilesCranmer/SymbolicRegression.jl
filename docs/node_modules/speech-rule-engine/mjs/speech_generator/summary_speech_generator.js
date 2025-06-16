import { AbstractSpeechGenerator } from './abstract_speech_generator.js';
import * as SpeechGeneratorUtil from './speech_generator_util.js';
import { setup as EngineSetup } from '../common/engine_setup.js';
import { Attribute } from '../enrich_mathml/enrich_attr.js';
export class SummarySpeechGenerator extends AbstractSpeechGenerator {
    getSpeech(node, _xml) {
        EngineSetup(this.getOptions());
        const id = node.getAttribute(Attribute.ID);
        const snode = this.getRebuilt().streeRoot.querySelectorAll((x) => x.id.toString() === id)[0];
        SpeechGeneratorUtil.addModality(node, snode, this.modality);
        const speech = node.getAttribute(Attribute.SUMMARY);
        return speech;
    }
}
