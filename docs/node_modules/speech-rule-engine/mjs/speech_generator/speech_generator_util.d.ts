import { AuditoryDescription } from '../audio/auditory_description.js';
import { SemanticNode } from '../semantic_tree/semantic_node.js';
export declare function computeSpeech(xml: Element): AuditoryDescription[];
export declare function computeMarkup(tree: Element): string;
export declare function recomputeMarkup(semantic: SemanticNode): string;
export declare function addSpeech(mml: Element, semantic: SemanticNode, snode: Element): void;
export declare function addModality(mml: Element, semantic: SemanticNode, modality: string): void;
export declare function addPrefix(mml: Element, semantic: SemanticNode): void;
export declare function retrievePrefix(semantic: SemanticNode): string;
export declare function connectMactions(node: Element, mml: Element, stree: Element): void;
export declare function connectAllMactions(mml: Element, stree: Element): void;
export declare function retrieveSummary(node: Element, options?: {
    [key: string]: string;
}): string;
