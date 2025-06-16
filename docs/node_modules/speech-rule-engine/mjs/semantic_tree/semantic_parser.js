import { SemanticNodeFactory } from './semantic_node_factory.js';
export class SemanticAbstractParser {
    constructor(type) {
        this.type = type;
        this.factory_ = new SemanticNodeFactory();
    }
    getFactory() {
        return this.factory_;
    }
    setFactory(factory) {
        this.factory_ = factory;
    }
    getType() {
        return this.type;
    }
    parseList(list) {
        const result = [];
        for (let i = 0, element; (element = list[i]); i++) {
            result.push(this.parse(element));
        }
        return result;
    }
}
