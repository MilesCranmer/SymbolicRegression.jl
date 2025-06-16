import { SemanticNode } from './semantic_node.js';
import { SemanticNodeFactory } from './semantic_node_factory.js';
export interface SemanticParser<T> {
    parse(representation: T): SemanticNode;
    parseList(list: T[]): SemanticNode[];
    getFactory(): SemanticNodeFactory;
    setFactory(factory: SemanticNodeFactory): void;
    getType(): string;
}
export declare abstract class SemanticAbstractParser<T> implements SemanticParser<T> {
    private type;
    private factory_;
    constructor(type: string);
    abstract parse(representation: T): SemanticNode;
    getFactory(): SemanticNodeFactory;
    setFactory(factory: SemanticNodeFactory): void;
    getType(): string;
    parseList(list: T[]): SemanticNode[];
}
