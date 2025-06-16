import { SemanticAnnotator, SemanticVisitor } from './semantic_annotator.js';
import { SemanticNode } from './semantic_node.js';
export declare const annotators: Map<string, SemanticAnnotator>;
export declare const visitors: Map<string, SemanticVisitor>;
export declare function register(annotator: SemanticAnnotator | SemanticVisitor): void;
export declare function activate(domain: string, name: string): void;
export declare function deactivate(domain: string, name: string): void;
export declare function annotate(node: SemanticNode): void;
