import { SemanticNode } from './semantic_node.js';
export declare type SemanticHeuristicTypes = Element | SemanticNode | SemanticNode[];
export interface SemanticHeuristic<T> {
    name: string;
    apply: (node: T) => void;
    applicable: (node: T) => boolean;
}
declare abstract class SemanticAbstractHeuristic<T extends SemanticHeuristicTypes> implements SemanticHeuristic<T> {
    name: string;
    apply: (node: T) => void;
    applicable: (_node: T) => boolean;
    constructor(name: string, method: (node: T) => void, predicate?: (node: T) => boolean);
}
export declare class SemanticTreeHeuristic extends SemanticAbstractHeuristic<SemanticNode> {
}
export declare class SemanticMultiHeuristic extends SemanticAbstractHeuristic<SemanticNode[]> {
}
export declare class SemanticMmlHeuristic extends SemanticAbstractHeuristic<Element> {
}
export {};
