import { AbstractSpeechGenerator } from './abstract_speech_generator.js';
export declare class TreeSpeechGenerator extends AbstractSpeechGenerator {
    getSpeech(node: Element, xml: Element, root?: Element): string;
}
