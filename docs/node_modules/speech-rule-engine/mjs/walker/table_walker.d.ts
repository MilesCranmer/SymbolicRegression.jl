import { KeyCode } from '../common/event_util.js';
import { Highlighter } from '../highlighter/highlighter.js';
import { SemanticRole, SemanticType } from '../semantic_tree/semantic_meaning.js';
import { SpeechGenerator } from '../speech_generator/speech_generator.js';
import { Focus } from './focus.js';
import { SyntaxWalker } from './syntax_walker.js';
export declare class TableWalker extends SyntaxWalker {
    node: Element;
    generator: SpeechGenerator;
    highlighter: Highlighter;
    static ELIGIBLE_CELL_ROLES: SemanticRole[];
    static ELIGIBLE_TABLE_TYPES: SemanticType[];
    firstJump: Focus;
    private key_;
    private row_;
    private currentTable_;
    constructor(node: Element, generator: SpeechGenerator, highlighter: Highlighter, xml: string);
    move(key: KeyCode): boolean;
    up(): Focus;
    down(): Focus;
    protected jumpCell(): Focus | null;
    undo(): Focus;
    private eligibleCell_;
    private verticalMove_;
    private jumpCell_;
    private isLegalJump_;
    private isInTable_;
}
