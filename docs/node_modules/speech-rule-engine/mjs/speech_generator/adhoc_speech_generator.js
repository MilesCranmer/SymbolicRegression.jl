import { AbstractSpeechGenerator } from './abstract_speech_generator.js';
export class AdhocSpeechGenerator extends AbstractSpeechGenerator {
    getSpeech(node, xml) {
        const speech = this.generateSpeech(node, xml);
        node.setAttribute(this.modality, speech);
        return speech;
    }
}
