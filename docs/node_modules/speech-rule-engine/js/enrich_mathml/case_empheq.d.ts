import { SemanticNode } from '../semantic_tree/semantic_node.js';
import { AbstractEnrichCase } from './abstract_enrich_case.js';
export declare class CaseEmpheq extends AbstractEnrichCase {
    mml: Element;
    private mrows;
    static test(semantic: SemanticNode): boolean;
    constructor(semantic: SemanticNode);
    getMathml(): Element;
    private recurseToTable;
    private finalizeTable;
}
