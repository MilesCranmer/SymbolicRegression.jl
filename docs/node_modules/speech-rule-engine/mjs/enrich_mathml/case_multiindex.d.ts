import { SemanticNode } from '../semantic_tree/semantic_node.js';
import { Sexp } from '../semantic_tree/semantic_skeleton.js';
import { AbstractEnrichCase } from './abstract_enrich_case.js';
export declare abstract class CaseMultiindex extends AbstractEnrichCase {
    mml: Element;
    static multiscriptIndex(index: SemanticNode): Sexp;
    private static createNone_;
    constructor(semantic: SemanticNode);
    protected completeMultiscript(rightIndices: Sexp, leftIndices: Sexp): void;
}
