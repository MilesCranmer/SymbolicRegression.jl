export type SpanAttrs = {
    [key: string]: string;
};
export declare class Span {
    speech: string;
    attributes: SpanAttrs;
    constructor(speech: string, attributes: SpanAttrs);
    static empty(): Span;
    static stringEmpty(str: string): Span;
    static stringAttr(str: string, attr: SpanAttrs): Span;
    static singleton(str: string, def?: SpanAttrs): Span[];
    static node(str: string, node: Element, def?: SpanAttrs): Span;
    static attributeList: string[];
    static getAttributes(node: Element): SpanAttrs;
}
