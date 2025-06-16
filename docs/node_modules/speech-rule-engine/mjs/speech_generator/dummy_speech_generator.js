import { AbstractSpeechGenerator } from './abstract_speech_generator.js';
export class DummySpeechGenerator extends AbstractSpeechGenerator {
    getSpeech(_node, _xml) {
        return '';
    }
}
