import { Attribute } from '../enrich_mathml/enrich_attr.js';
export declare function splitAttribute(attr: string | null): string[];
export declare function getAttribute(node: Element, attr: Attribute): string;
export declare function getSemanticRoot(node: Element): Element;
export declare function getBySemanticId(root: Element, id: string): Element;
export declare function getAllBySemanticId(root: Element, id: string): Element[];
