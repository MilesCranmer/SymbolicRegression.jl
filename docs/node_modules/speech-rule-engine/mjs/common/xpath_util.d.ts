export declare const xpath: {
    currentDocument: Document;
    evaluate: (x: string, node: Element, nsr: Resolver, rt: number, result: XPathResult) => XPathResult;
    result: any;
    createNSResolver: (nodeResolver: Element) => XPathNSResolver;
};
export declare function resolveNameSpace(prefix: string): string;
declare class Resolver {
    lookupNamespaceURI: any;
    constructor();
}
export declare function evalXPath(expression: string, rootNode: Element): Element[];
export declare function evaluateBoolean(expression: string, rootNode: Element): boolean;
export declare function evaluateString(expression: string, rootNode: Element): string;
export declare function updateEvaluator(node: Element): void;
export {};
