import { SemanticNode } from './semantic_node.js';
export declare enum MMLTAGS {
    ANNOTATION = "ANNOTATION",
    ANNOTATIONXML = "ANNOTATION-XML",
    MACTION = "MACTION",
    MALIGNGROUP = "MALIGNGROUP",
    MALIGNMARK = "MALIGNMARK",
    MATH = "MATH",
    MENCLOSE = "MENCLOSE",
    MERROR = "MERROR",
    MFENCED = "MFENCED",
    MFRAC = "MFRAC",
    MGLYPH = "MGLYPH",
    MI = "MI",
    MLABELEDTR = "MLABELEDTR",
    MMULTISCRIPTS = "MMULTISCRIPTS",
    MN = "MN",
    MO = "MO",
    MOVER = "MOVER",
    MPADDED = "MPADDED",
    MPHANTOM = "MPHANTOM",
    MPRESCRIPTS = "MPRESCRIPTS",
    MROOT = "MROOT",
    MROW = "MROW",
    MS = "MS",
    MSPACE = "MSPACE",
    MSQRT = "MSQRT",
    MSTYLE = "MSTYLE",
    MSUB = "MSUB",
    MSUBSUP = "MSUBSUP",
    MSUP = "MSUP",
    MTABLE = "MTABLE",
    MTD = "MTD",
    MTEXT = "MTEXT",
    MTR = "MTR",
    MUNDER = "MUNDER",
    MUNDEROVER = "MUNDEROVER",
    NONE = "NONE",
    SEMANTICS = "SEMANTICS"
}
export declare function hasMathTag(node: Element): boolean;
export declare function hasIgnoreTag(node: Element): boolean;
export declare function hasEmptyTag(node: Element): boolean;
export declare function hasDisplayTag(node: Element): boolean;
export declare function isOrphanedGlyph(node: Element): boolean;
export declare function purgeNodes(nodes: Element[]): Element[];
export declare function isZeroLength(length: string): boolean;
export declare function addAttributes(to: SemanticNode, from: Element): void;
export declare function getEmbellishedInner(node: SemanticNode): SemanticNode;
export interface Slice {
    head: SemanticNode[];
    div: SemanticNode;
    tail: SemanticNode[];
}
export declare function sliceNodes(nodes: SemanticNode[], pred: (p1: SemanticNode) => boolean, opt_reverse?: boolean): Slice;
export interface Partition {
    rel: SemanticNode[];
    comp: SemanticNode[][];
}
export declare function partitionNodes(nodes: SemanticNode[], pred: (p1: SemanticNode) => boolean): Partition;
