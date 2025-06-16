import * as DomUtil from '../common/dom_util.js';
import { annotate } from './semantic_annotations.js';
import { SemanticVisitor } from './semantic_annotator.js';
import { SemanticRole } from './semantic_meaning.js';
import { SemanticMathml } from './semantic_mathml.js';
import { SemanticNode } from './semantic_node.js';
import * as SemanticPred from './semantic_pred.js';
import './semantic_heuristics.js';
export class SemanticTree {
    static empty() {
        const empty = DomUtil.parseInput('<math/>');
        const stree = new SemanticTree(empty);
        stree.mathml = empty;
        return stree;
    }
    static fromNode(semantic, opt_mathml) {
        const stree = SemanticTree.empty();
        stree.root = semantic;
        if (opt_mathml) {
            stree.mathml = opt_mathml;
        }
        return stree;
    }
    static fromRoot(semantic, opt_mathml) {
        let root = semantic;
        while (root.parent) {
            root = root.parent;
        }
        const stree = SemanticTree.fromNode(root);
        if (opt_mathml) {
            stree.mathml = opt_mathml;
        }
        return stree;
    }
    static fromXml(xml) {
        const stree = SemanticTree.empty();
        if (xml.childNodes[0]) {
            stree.root = SemanticNode.fromXml(xml.childNodes[0]);
        }
        return stree;
    }
    constructor(mathml) {
        this.mathml = mathml;
        this.parser = new SemanticMathml();
        this.root = this.parser.parse(mathml);
        this.collator = this.parser.getFactory().leafMap.collateMeaning();
        const newDefault = this.collator.newDefault();
        if (newDefault) {
            this.parser = new SemanticMathml();
            this.parser.getFactory().defaultMap = newDefault;
            this.root = this.parser.parse(mathml);
        }
        unitVisitor.visit(this.root, {});
        annotate(this.root);
    }
    xml(opt_brief) {
        const xml = DomUtil.parseInput('<stree></stree>');
        const xmlRoot = this.root.xml(xml.ownerDocument, opt_brief);
        xml.appendChild(xmlRoot);
        return xml;
    }
    toString(opt_brief) {
        return DomUtil.serializeXml(this.xml(opt_brief));
    }
    formatXml(opt_brief) {
        const xml = this.toString(opt_brief);
        return DomUtil.formatXml(xml);
    }
    displayTree() {
        this.root.displayTree();
    }
    replaceNode(oldNode, newNode) {
        const parent = oldNode.parent;
        if (!parent) {
            this.root = newNode;
            return;
        }
        parent.replaceChild(oldNode, newNode);
    }
    toJson() {
        const json = {};
        json['stree'] = this.root.toJson();
        return json;
    }
}
const unitVisitor = new SemanticVisitor('general', 'unit', (node, _info) => {
    if (SemanticPred.isUnitProduct(node)) {
        node.role = SemanticRole.UNIT;
    }
    return false;
});
