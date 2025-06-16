import { Highlighter } from '../highlighter/highlighter.js';
import { SemanticRole, SemanticType } from '../semantic_tree/semantic_meaning.js';
import { SpeechGenerator } from '../speech_generator/speech_generator.js';
import { AbstractWalker } from './abstract_walker.js';
import { Focus } from './focus.js';
import { Levels } from './levels.js';
export declare class SemanticWalker extends AbstractWalker<Focus> {
    node: Element;
    generator: SpeechGenerator;
    highlighter: Highlighter;
    levels: Levels<Focus>;
    constructor(node: Element, generator: SpeechGenerator, highlighter: Highlighter, xml: string);
    initLevels(): Levels<Focus>;
    up(): Focus;
    down(): Focus;
    combineContentChildren(type: SemanticType, role: SemanticRole, content: string[], children: string[]): Focus[];
    combinePunctuations(children: string[], content: string[], prepunct: string[], acc: Focus[]): Focus[];
    makePairList(children: string[], content: string[]): Focus[];
    left(): Focus;
    right(): Focus;
    findFocusOnLevel(id: number): Focus;
}
