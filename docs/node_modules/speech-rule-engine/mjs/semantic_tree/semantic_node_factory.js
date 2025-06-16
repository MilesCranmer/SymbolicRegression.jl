import { SemanticType } from './semantic_meaning.js';
import { SemanticDefault } from './semantic_default.js';
import { SemanticNodeCollator } from './semantic_default.js';
import { SemanticNode } from './semantic_node.js';
export class SemanticNodeFactory {
    constructor() {
        this.leafMap = new SemanticNodeCollator();
        this.defaultMap = new SemanticDefault();
        this.idCounter_ = -1;
    }
    makeNode(id) {
        return this.createNode_(id);
    }
    makeUnprocessed(mml) {
        const node = this.createNode_();
        node.mathml = [mml];
        node.mathmlTree = mml;
        return node;
    }
    makeEmptyNode() {
        const node = this.createNode_();
        node.type = SemanticType.EMPTY;
        return node;
    }
    makeContentNode(content) {
        const node = this.createNode_();
        node.updateContent(content);
        return node;
    }
    makeMultipleContentNodes(num, content) {
        const nodes = [];
        for (let i = 0; i < num; i++) {
            nodes.push(this.makeContentNode(content));
        }
        return nodes;
    }
    makeLeafNode(content, font) {
        if (!content) {
            return this.makeEmptyNode();
        }
        const node = this.makeContentNode(content);
        node.font = font || node.font;
        const meaning = this.defaultMap.getNode(node);
        if (meaning) {
            node.type = meaning.type;
            node.role = meaning.role;
            node.font = meaning.font;
        }
        this.leafMap.addNode(node);
        return node;
    }
    makeBranchNode(type, children, contentNodes, opt_content) {
        const node = this.createNode_();
        if (opt_content) {
            node.updateContent(opt_content);
        }
        node.type = type;
        node.childNodes = children;
        node.contentNodes = contentNodes;
        children.concat(contentNodes).forEach(function (x) {
            x.parent = node;
            node.addMathmlNodes(x.mathml);
        });
        return node;
    }
    createNode_(id) {
        if (typeof id !== 'undefined') {
            this.idCounter_ = Math.max(this.idCounter_, id);
        }
        else {
            id = ++this.idCounter_;
        }
        return new SemanticNode(id);
    }
}
