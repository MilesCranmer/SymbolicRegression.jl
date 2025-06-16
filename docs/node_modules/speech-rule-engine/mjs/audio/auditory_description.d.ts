import { Span } from './span.js';
interface AudioDescr {
    context?: string;
    text: string;
    userValue?: string;
    annotation?: string;
    attributes?: {
        [key: string]: string;
    };
    personality?: {
        [key: string]: string;
    };
    layout?: string;
}
interface AudioFlags {
    adjust?: boolean;
    preprocess?: boolean;
    correct?: boolean;
    translate?: boolean;
}
export declare class AuditoryItem {
    data: AuditoryDescription;
    prev: AuditoryItem;
    next: AuditoryItem;
    constructor(data?: AuditoryDescription);
}
export declare class AuditoryList extends Set<AuditoryItem> {
    annotations: AuditoryItem[];
    private anchor;
    constructor(descrs: AuditoryDescription[]);
    first(): AuditoryItem;
    last(): AuditoryItem;
    push(item: AuditoryItem): void;
    pop(): AuditoryItem;
    delete(item: AuditoryItem): boolean;
    insertAfter(descr: AuditoryDescription, item: AuditoryItem): void;
    insertBefore(descr: AuditoryDescription, item: AuditoryItem): void;
    prevText(item: AuditoryItem): AuditoryItem;
    [Symbol.iterator](): IterableIterator<AuditoryItem>;
    nextText(item: AuditoryItem): AuditoryItem;
    clear(): void;
    empty(): boolean;
    toList(): AuditoryDescription[];
}
export declare class AuditoryDescription {
    context: string;
    text: string;
    userValue: string;
    annotation: string;
    attributes: {
        [key: string]: string;
    };
    personality: {
        [key: string]: string;
    };
    layout: string;
    static create(args: AudioDescr, flags?: AudioFlags): AuditoryDescription;
    constructor({ context, text, userValue, annotation, attributes, personality, layout }: AudioDescr);
    isEmpty(): boolean;
    clone(): AuditoryDescription;
    toString(): string;
    descriptionString(): string;
    descriptionSpan(): Span;
    equals(that: AuditoryDescription): boolean;
}
export {};
