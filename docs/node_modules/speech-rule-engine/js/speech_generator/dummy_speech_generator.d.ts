import { AbstractSpeechGenerator } from './abstract_speech_generator.js';
export declare class DummySpeechGenerator extends AbstractSpeechGenerator {
    getSpeech(_node: Element, _xml: Element): string;
}
