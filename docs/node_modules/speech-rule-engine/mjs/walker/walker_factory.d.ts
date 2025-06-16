import { Highlighter } from '../highlighter/highlighter.js';
import { SpeechGenerator } from '../speech_generator/speech_generator.js';
import { Walker } from './walker.js';
export declare function walker(type: string, node: Element, generator: SpeechGenerator, highlighter: Highlighter, xml: string): Walker;
