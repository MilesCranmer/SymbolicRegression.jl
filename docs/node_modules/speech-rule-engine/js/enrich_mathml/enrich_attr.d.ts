import { SemanticNode } from '../semantic_tree/semantic_node.js';
export declare enum Attribute {
    ADDED = "data-semantic-added",
    ALTERNATIVE = "data-semantic-alternative",
    CHILDREN = "data-semantic-children",
    COLLAPSED = "data-semantic-collapsed",
    CONTENT = "data-semantic-content",
    EMBELLISHED = "data-semantic-embellished",
    FENCEPOINTER = "data-semantic-fencepointer",
    FONT = "data-semantic-font",
    ID = "data-semantic-id",
    ANNOTATION = "data-semantic-annotation",
    ATTRIBUTES = "data-semantic-attributes",
    OPERATOR = "data-semantic-operator",
    OWNS = "data-semantic-owns",
    PARENT = "data-semantic-parent",
    POSTFIX = "data-semantic-postfix",
    PREFIX = "data-semantic-prefix",
    ROLE = "data-semantic-role",
    SPEECH = "data-semantic-speech",
    STRUCTURE = "data-semantic-structure",
    SUMMARY = "data-semantic-summary",
    TYPE = "data-semantic-type"
}
export declare const EnrichAttributes: string[];
export declare function makeIdList(nodes: SemanticNode[]): string;
export declare function setAttributes(mml: Element, semantic: SemanticNode): void;
export declare function removeAttributePrefix(mml: string): string;
export declare function addPrefix(attr: string): Attribute;
export declare function addMrow(): Element;
