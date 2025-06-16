import { SemanticFont, SemanticMeaning } from './semantic_meaning.js';
import { SemanticNode } from './semantic_node.js';
export declare class SemanticDefault extends Map<string, SemanticMeaning> {
    set(symbol: string, meaning: SemanticMeaning): this;
    setNode(node: SemanticNode): void;
    get(symbol: string, font?: SemanticFont): SemanticMeaning;
    getNode(node: SemanticNode): SemanticMeaning;
}
declare abstract class SemanticCollator<T> extends Map<string, T[]> {
    add(symbol: string, entry: T): void;
    abstract addNode(node: SemanticNode): void;
    get(symbol: string, font?: SemanticFont): T[];
    getNode(node: SemanticNode): T[];
    minimize(): void;
    isMultiValued(): boolean;
}
export declare class SemanticNodeCollator extends SemanticCollator<SemanticNode> {
    add(symbol: string, entry: SemanticNode): void;
    addNode(node: SemanticNode): void;
    toString(): string;
    collateMeaning(): SemanticMeaningCollator;
}
export declare class SemanticMeaningCollator extends SemanticCollator<SemanticMeaning> {
    add(symbol: string, entry: SemanticMeaning): void;
    addNode(node: SemanticNode): void;
    toString(): string;
    reduce(): void;
    default(): SemanticDefault;
    newDefault(): SemanticDefault | null;
}
export {};
