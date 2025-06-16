import { SemanticNode } from '../semantic_tree/semantic_node.js';
import { CaseMultiindex } from './case_multiindex.js';
export declare class CaseMultiscripts extends CaseMultiindex {
    static test(semantic: SemanticNode): boolean;
    constructor(semantic: SemanticNode);
    getMathml(): Element;
}
