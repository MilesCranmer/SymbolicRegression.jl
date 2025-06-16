"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.RebuildStree = void 0;
const enrich_attr_js_1 = require("../enrich_mathml/enrich_attr.js");
const semantic_attr_js_1 = require("../semantic_tree/semantic_attr.js");
const semantic_meaning_js_1 = require("../semantic_tree/semantic_meaning.js");
const semantic_node_factory_js_1 = require("../semantic_tree/semantic_node_factory.js");
const semantic_skeleton_js_1 = require("../semantic_tree/semantic_skeleton.js");
const semantic_tree_js_1 = require("../semantic_tree/semantic_tree.js");
const WalkerUtil = require("./walker_util.js");
class RebuildStree {
    static textContent(snode, node, ignore) {
        if (!ignore && node.textContent) {
            snode.textContent = node.textContent;
            return;
        }
        const operator = WalkerUtil.splitAttribute(WalkerUtil.getAttribute(node, enrich_attr_js_1.Attribute.OPERATOR));
        if (operator.length > 1) {
            snode.textContent = operator[1];
        }
    }
    static isPunctuated(collapsed) {
        return (!semantic_skeleton_js_1.SemanticSkeleton.simpleCollapseStructure(collapsed) &&
            collapsed[1] &&
            semantic_skeleton_js_1.SemanticSkeleton.contentCollapseStructure(collapsed[1]));
    }
    constructor(mathml) {
        this.mathml = mathml;
        this.factory = new semantic_node_factory_js_1.SemanticNodeFactory();
        this.nodeDict = {};
        this.mmlRoot = WalkerUtil.getSemanticRoot(mathml);
        this.streeRoot = this.assembleTree(this.mmlRoot);
        this.stree = semantic_tree_js_1.SemanticTree.fromNode(this.streeRoot, this.mathml);
        this.xml = this.stree.xml();
    }
    getTree() {
        return this.stree;
    }
    assembleTree(node) {
        const snode = this.makeNode(node);
        const children = WalkerUtil.splitAttribute(WalkerUtil.getAttribute(node, enrich_attr_js_1.Attribute.CHILDREN));
        const content = WalkerUtil.splitAttribute(WalkerUtil.getAttribute(node, enrich_attr_js_1.Attribute.CONTENT));
        if (content.length === 0 && children.length === 0) {
            RebuildStree.textContent(snode, node);
            return snode;
        }
        if (content.length > 0) {
            const fcontent = WalkerUtil.getBySemanticId(this.mathml, content[0]);
            if (fcontent) {
                RebuildStree.textContent(snode, fcontent, true);
            }
        }
        snode.contentNodes = content.map((id) => this.setParent(id, snode));
        snode.childNodes = children.map((id) => this.setParent(id, snode));
        const collapsed = WalkerUtil.getAttribute(node, enrich_attr_js_1.Attribute.COLLAPSED);
        return collapsed ? this.postProcess(snode, collapsed) : snode;
    }
    makeNode(node) {
        const type = WalkerUtil.getAttribute(node, enrich_attr_js_1.Attribute.TYPE);
        const role = WalkerUtil.getAttribute(node, enrich_attr_js_1.Attribute.ROLE);
        const font = WalkerUtil.getAttribute(node, enrich_attr_js_1.Attribute.FONT);
        const annotation = WalkerUtil.getAttribute(node, enrich_attr_js_1.Attribute.ANNOTATION) || '';
        const attributes = WalkerUtil.getAttribute(node, enrich_attr_js_1.Attribute.ATTRIBUTES) || '';
        const id = WalkerUtil.getAttribute(node, enrich_attr_js_1.Attribute.ID);
        const embellished = WalkerUtil.getAttribute(node, enrich_attr_js_1.Attribute.EMBELLISHED);
        const fencepointer = WalkerUtil.getAttribute(node, enrich_attr_js_1.Attribute.FENCEPOINTER);
        const snode = this.createNode(parseInt(id, 10));
        snode.type = type;
        snode.role = role;
        snode.font = font ? font : semantic_meaning_js_1.SemanticFont.UNKNOWN;
        snode.parseAnnotation(annotation);
        snode.parseAttributes(attributes);
        if (fencepointer) {
            snode.fencePointer = fencepointer;
        }
        if (embellished) {
            snode.embellished = embellished;
        }
        return snode;
    }
    makePunctuation(id) {
        const node = this.createNode(id);
        node.updateContent(semantic_attr_js_1.NamedSymbol.invisibleComma);
        node.role = semantic_meaning_js_1.SemanticRole.DUMMY;
        return node;
    }
    makePunctuated(snode, collapsed, role) {
        const punctuated = this.createNode(collapsed[0]);
        punctuated.type = semantic_meaning_js_1.SemanticType.PUNCTUATED;
        punctuated.embellished = snode.embellished;
        punctuated.fencePointer = snode.fencePointer;
        punctuated.role = role;
        const cont = collapsed.splice(1, 1)[0].slice(1);
        punctuated.contentNodes = cont.map(this.makePunctuation.bind(this));
        this.collapsedChildren_(collapsed);
    }
    makeEmpty(snode, collapsed, role) {
        const empty = this.createNode(collapsed);
        empty.type = semantic_meaning_js_1.SemanticType.EMPTY;
        empty.embellished = snode.embellished;
        empty.fencePointer = snode.fencePointer;
        empty.role = role;
    }
    makeIndex(snode, collapsed, role) {
        if (RebuildStree.isPunctuated(collapsed)) {
            this.makePunctuated(snode, collapsed, role);
            collapsed = collapsed[0];
            return;
        }
        if (semantic_skeleton_js_1.SemanticSkeleton.simpleCollapseStructure(collapsed) &&
            !this.nodeDict[collapsed.toString()]) {
            this.makeEmpty(snode, collapsed, role);
        }
    }
    postProcess(snode, collapsed) {
        const array = semantic_skeleton_js_1.SemanticSkeleton.fromString(collapsed).array;
        if (snode.type === semantic_meaning_js_1.SemanticRole.SUBSUP) {
            const subscript = this.createNode(array[1][0]);
            subscript.type = semantic_meaning_js_1.SemanticType.SUBSCRIPT;
            subscript.role = semantic_meaning_js_1.SemanticRole.SUBSUP;
            snode.type = semantic_meaning_js_1.SemanticType.SUPERSCRIPT;
            subscript.embellished = snode.embellished;
            subscript.fencePointer = snode.fencePointer;
            this.makeIndex(snode, array[1][2], semantic_meaning_js_1.SemanticRole.RIGHTSUB);
            this.makeIndex(snode, array[2], semantic_meaning_js_1.SemanticRole.RIGHTSUPER);
            this.collapsedChildren_(array);
            return snode;
        }
        if (snode.type === semantic_meaning_js_1.SemanticType.SUBSCRIPT) {
            this.makeIndex(snode, array[2], semantic_meaning_js_1.SemanticRole.RIGHTSUB);
            this.collapsedChildren_(array);
            return snode;
        }
        if (snode.type === semantic_meaning_js_1.SemanticType.SUPERSCRIPT) {
            this.makeIndex(snode, array[2], semantic_meaning_js_1.SemanticRole.RIGHTSUPER);
            this.collapsedChildren_(array);
            return snode;
        }
        if (snode.type === semantic_meaning_js_1.SemanticType.TENSOR) {
            this.makeIndex(snode, array[2], semantic_meaning_js_1.SemanticRole.LEFTSUB);
            this.makeIndex(snode, array[3], semantic_meaning_js_1.SemanticRole.LEFTSUPER);
            this.makeIndex(snode, array[4], semantic_meaning_js_1.SemanticRole.RIGHTSUB);
            this.makeIndex(snode, array[5], semantic_meaning_js_1.SemanticRole.RIGHTSUPER);
            this.collapsedChildren_(array);
            return snode;
        }
        if (snode.type === semantic_meaning_js_1.SemanticType.PUNCTUATED) {
            if (RebuildStree.isPunctuated(array)) {
                const cont = array.splice(1, 1)[0].slice(1);
                snode.contentNodes = cont.map(this.makePunctuation.bind(this));
            }
            return snode;
        }
        if (snode.type === semantic_meaning_js_1.SemanticRole.UNDEROVER) {
            const score = this.createNode(array[1][0]);
            if (snode.childNodes[1].role === semantic_meaning_js_1.SemanticRole.OVERACCENT) {
                score.type = semantic_meaning_js_1.SemanticType.OVERSCORE;
                snode.type = semantic_meaning_js_1.SemanticType.UNDERSCORE;
            }
            else {
                score.type = semantic_meaning_js_1.SemanticType.UNDERSCORE;
                snode.type = semantic_meaning_js_1.SemanticType.OVERSCORE;
            }
            score.role = semantic_meaning_js_1.SemanticRole.UNDEROVER;
            score.embellished = snode.embellished;
            score.fencePointer = snode.fencePointer;
            this.collapsedChildren_(array);
            return snode;
        }
        return snode;
    }
    createNode(id) {
        const node = this.factory.makeNode(id);
        this.nodeDict[id.toString()] = node;
        return node;
    }
    collapsedChildren_(collapsed) {
        const recurseCollapsed = (coll) => {
            const parent = this.nodeDict[coll[0]];
            parent.childNodes = [];
            for (let j = 1, l = coll.length; j < l; j++) {
                const id = coll[j];
                parent.childNodes.push(semantic_skeleton_js_1.SemanticSkeleton.simpleCollapseStructure(id)
                    ? this.nodeDict[id]
                    : recurseCollapsed(id));
            }
            return parent;
        };
        recurseCollapsed(collapsed);
    }
    setParent(id, snode) {
        const mml = WalkerUtil.getBySemanticId(this.mathml, id);
        const sn = this.assembleTree(mml);
        sn.parent = snode;
        return sn;
    }
}
exports.RebuildStree = RebuildStree;
