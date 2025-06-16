import { AbstractSpeechGenerator } from './abstract_speech_generator.js';
export declare class AdhocSpeechGenerator extends AbstractSpeechGenerator {
    getSpeech(node: Element, xml: Element): string;
}
