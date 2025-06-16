import { SemanticRole, SemanticType } from '../semantic_tree/semantic_meaning.js';
import { AbstractWalker } from './abstract_walker.js';
import { Focus } from './focus.js';
import { Levels } from './levels.js';
export declare class DummyWalker extends AbstractWalker<void> {
    up(): Focus;
    down(): Focus;
    left(): Focus;
    right(): Focus;
    repeat(): Focus;
    depth(): Focus;
    home(): Focus;
    getDepth(): number;
    initLevels(): Levels<void>;
    combineContentChildren(_type: SemanticType, _role: SemanticRole, _content: string[], _children: string[]): void[];
    findFocusOnLevel(_id: number): Focus;
}
