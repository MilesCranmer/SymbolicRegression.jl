import { SemanticNode } from '../semantic_tree/semantic_node.js';
import { EnrichCase } from './enrich_case.js';
export declare abstract class AbstractEnrichCase implements EnrichCase {
    semantic: SemanticNode;
    abstract getMathml(): Element;
    constructor(semantic: SemanticNode);
}
