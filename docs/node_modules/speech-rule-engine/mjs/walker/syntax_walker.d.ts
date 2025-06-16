import { Highlighter } from '../highlighter/highlighter.js';
import { SemanticRole, SemanticType } from '../semantic_tree/semantic_meaning.js';
import { SpeechGenerator } from '../speech_generator/speech_generator.js';
import { AbstractWalker } from './abstract_walker.js';
import { Levels } from './levels.js';
export declare class SyntaxWalker extends AbstractWalker<string> {
    node: Element;
    generator: SpeechGenerator;
    highlighter: Highlighter;
    levels: Levels<string>;
    constructor(node: Element, generator: SpeechGenerator, highlighter: Highlighter, xml: string);
    initLevels(): Levels<string>;
    up(): import("./focus.js").Focus;
    down(): import("./focus.js").Focus;
    combineContentChildren(type: SemanticType, role: SemanticRole, content: string[], children: string[]): string[];
    left(): import("./focus.js").Focus;
    right(): import("./focus.js").Focus;
    findFocusOnLevel(id: number): import("./focus.js").Focus;
    focusDomNodes(): Element[];
    focusSemanticNodes(): import("../semantic_tree/semantic_node.js").SemanticNode[];
}
