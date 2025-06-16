import { SemanticHeuristic, SemanticHeuristicTypes } from './semantic_heuristic.js';
import { SemanticNodeFactory } from './semantic_node_factory.js';
export declare const SemanticHeuristics: {
    factory: SemanticNodeFactory;
    updateFactory: (nodeFactory: SemanticNodeFactory) => void;
    heuristics: Map<string, SemanticHeuristic<SemanticHeuristicTypes>>;
    flags: {
        [key: string]: boolean;
    };
    blacklist: {
        [key: string]: boolean;
    };
    add: (heuristic: SemanticHeuristic<SemanticHeuristicTypes>) => void;
    run: (name: string, root: SemanticHeuristicTypes, opt_alternative?: (p1: SemanticHeuristicTypes) => SemanticHeuristicTypes) => SemanticHeuristicTypes | void;
};
