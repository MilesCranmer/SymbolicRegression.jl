import { SemanticNode } from '../semantic_tree/semantic_node.js';
import { RebuildStree } from './rebuild_stree.js';
export declare class Focus {
    private nodes;
    private primary;
    private domNodes;
    private domPrimary_;
    private allNodes;
    static factory(primaryId: string, nodeIds: string[], rebuilt: RebuildStree, dom: Element): Focus;
    private static generateAllVisibleNodes_;
    private static getAllVisibleNodes;
    constructor(nodes: SemanticNode[], primary: SemanticNode);
    getSemanticPrimary(): SemanticNode;
    getSemanticNodes(): SemanticNode[];
    getNodes(): Element[];
    getDomNodes(): (Element | null)[];
    getDomPrimary(): Element;
    toString(): string;
    clone(): Focus;
}
