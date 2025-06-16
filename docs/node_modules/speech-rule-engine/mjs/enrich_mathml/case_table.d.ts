import { SemanticNode } from '../semantic_tree/semantic_node.js';
import { AbstractEnrichCase } from './abstract_enrich_case.js';
export declare class CaseTable extends AbstractEnrichCase {
    mml: Element;
    inner: Element[];
    static test(semantic: SemanticNode): boolean;
    constructor(semantic: SemanticNode);
    getMathml(): Element;
}
