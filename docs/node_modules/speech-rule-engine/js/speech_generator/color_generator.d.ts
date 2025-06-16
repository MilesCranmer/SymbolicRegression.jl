import { AbstractSpeechGenerator } from './abstract_speech_generator.js';
export declare class ColorGenerator extends AbstractSpeechGenerator {
    modality: any;
    contrast: any;
    private static visitStree_;
    getSpeech(node: Element, _xml: Element): string;
    generateSpeech(node: Element, xml: Element | string): string;
    private colorLeaves_;
    private colorLeave_;
}
