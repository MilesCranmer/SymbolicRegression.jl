"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CaseEmbellished = void 0;
const DomUtil = require("../common/dom_util.js");
const semantic_meaning_js_1 = require("../semantic_tree/semantic_meaning.js");
const semantic_node_js_1 = require("../semantic_tree/semantic_node.js");
const semantic_util_js_1 = require("../semantic_tree/semantic_util.js");
const abstract_enrich_case_js_1 = require("./abstract_enrich_case.js");
const case_double_script_js_1 = require("./case_double_script.js");
const case_multiscripts_js_1 = require("./case_multiscripts.js");
const case_tensor_js_1 = require("./case_tensor.js");
const EnrichMathml = require("./enrich_mathml.js");
const enrich_attr_js_1 = require("./enrich_attr.js");
class CaseEmbellished extends abstract_enrich_case_js_1.AbstractEnrichCase {
    static test(semantic) {
        return !!(semantic.mathmlTree &&
            semantic.fencePointer &&
            !semantic.mathmlTree.getAttribute('data-semantic-type'));
    }
    static makeEmptyNode_(id) {
        const mrow = (0, enrich_attr_js_1.addMrow)();
        const empty = new semantic_node_js_1.SemanticNode(id);
        empty.type = semantic_meaning_js_1.SemanticType.EMPTY;
        empty.mathmlTree = mrow;
        return empty;
    }
    static fencedMap_(fence, ids) {
        ids[fence.id] = fence.mathmlTree;
        if (!fence.embellished) {
            return;
        }
        CaseEmbellished.fencedMap_(fence.childNodes[0], ids);
    }
    constructor(semantic) {
        super(semantic);
        this.fenced = null;
        this.fencedMml = null;
        this.fencedMmlNodes = [];
        this.ofence = null;
        this.ofenceMml = null;
        this.ofenceMap = {};
        this.cfence = null;
        this.cfenceMml = null;
        this.cfenceMap = {};
        this.parentCleanup = [];
    }
    getMathml() {
        this.getFenced_();
        this.fencedMml = EnrichMathml.walkTree(this.fenced);
        this.getFencesMml_();
        if (this.fenced.type === semantic_meaning_js_1.SemanticType.EMPTY && !this.fencedMml.parentNode) {
            this.fencedMml.setAttribute(enrich_attr_js_1.Attribute.ADDED, 'true');
            this.cfenceMml.parentNode.insertBefore(this.fencedMml, this.cfenceMml);
        }
        this.getFencedMml_();
        const rewrite = this.rewrite_();
        return rewrite;
    }
    fencedElement(node) {
        return (node.type === semantic_meaning_js_1.SemanticType.FENCED ||
            node.type === semantic_meaning_js_1.SemanticType.MATRIX ||
            node.type === semantic_meaning_js_1.SemanticType.VECTOR);
    }
    getFenced_() {
        let currentNode = this.semantic;
        while (!this.fencedElement(currentNode)) {
            currentNode = currentNode.childNodes[0];
        }
        this.fenced = currentNode.childNodes[0];
        this.ofence = currentNode.contentNodes[0];
        this.cfence = currentNode.contentNodes[1];
        CaseEmbellished.fencedMap_(this.ofence, this.ofenceMap);
        CaseEmbellished.fencedMap_(this.cfence, this.cfenceMap);
    }
    getFencedMml_() {
        let sibling = this.ofenceMml.nextSibling;
        sibling = sibling === this.fencedMml ? sibling : this.fencedMml;
        while (sibling && sibling !== this.cfenceMml) {
            this.fencedMmlNodes.push(sibling);
            sibling = sibling.nextSibling;
        }
    }
    getFencesMml_() {
        let currentNode = this.semantic;
        const ofenceIds = Object.keys(this.ofenceMap);
        const cfenceIds = Object.keys(this.cfenceMap);
        while ((!this.ofenceMml || !this.cfenceMml) &&
            currentNode !== this.fenced) {
            if (ofenceIds.indexOf(currentNode.fencePointer) !== -1 &&
                !this.ofenceMml) {
                this.ofenceMml = currentNode.mathmlTree;
            }
            if (cfenceIds.indexOf(currentNode.fencePointer) !== -1 &&
                !this.cfenceMml) {
                this.cfenceMml = currentNode.mathmlTree;
            }
            currentNode = currentNode.childNodes[0];
        }
        if (!this.ofenceMml) {
            this.ofenceMml = this.ofence.mathmlTree;
        }
        if (!this.cfenceMml) {
            this.cfenceMml = this.cfence.mathmlTree;
        }
        if (this.ofenceMml) {
            this.ofenceMml = EnrichMathml.ascendNewNode(this.ofenceMml);
        }
        if (this.cfenceMml) {
            this.cfenceMml = EnrichMathml.ascendNewNode(this.cfenceMml);
        }
    }
    rewrite_() {
        let currentNode = this.semantic;
        let result = null;
        const newNode = this.introduceNewLayer_();
        (0, enrich_attr_js_1.setAttributes)(newNode, this.fenced.parent);
        while (!this.fencedElement(currentNode)) {
            const mml = currentNode.mathmlTree;
            const specialCase = this.specialCase_(currentNode, mml);
            if (specialCase) {
                currentNode = specialCase;
            }
            else {
                (0, enrich_attr_js_1.setAttributes)(mml, currentNode);
                const mmlChildren = [];
                for (let i = 1, child; (child = currentNode.childNodes[i]); i++) {
                    mmlChildren.push(EnrichMathml.walkTree(child));
                }
                currentNode = currentNode.childNodes[0];
            }
            const dummy = DomUtil.createElement('dummy');
            const saveChild = mml.childNodes[0];
            DomUtil.replaceNode(mml, dummy);
            DomUtil.replaceNode(newNode, mml);
            DomUtil.replaceNode(mml.childNodes[0], newNode);
            DomUtil.replaceNode(dummy, saveChild);
            if (!result) {
                result = mml;
            }
        }
        EnrichMathml.walkTree(this.ofence);
        EnrichMathml.walkTree(this.cfence);
        this.cleanupParents_();
        return result || newNode;
    }
    specialCase_(semantic, mml) {
        const mmlTag = DomUtil.tagName(mml);
        let parent = null;
        let caller;
        if (mmlTag === semantic_util_js_1.MMLTAGS.MSUBSUP) {
            parent = semantic.childNodes[0];
            caller = case_double_script_js_1.CaseDoubleScript;
        }
        else if (mmlTag === semantic_util_js_1.MMLTAGS.MMULTISCRIPTS) {
            if (semantic.type === semantic_meaning_js_1.SemanticType.SUPERSCRIPT ||
                semantic.type === semantic_meaning_js_1.SemanticType.SUBSCRIPT) {
                caller = case_multiscripts_js_1.CaseMultiscripts;
            }
            else if (semantic.type === semantic_meaning_js_1.SemanticType.TENSOR) {
                caller = case_tensor_js_1.CaseTensor;
            }
            if (caller &&
                semantic.childNodes[0] &&
                semantic.childNodes[0].role === semantic_meaning_js_1.SemanticRole.SUBSUP) {
                parent = semantic.childNodes[0];
            }
            else {
                parent = semantic;
            }
        }
        if (!parent) {
            return null;
        }
        const base = parent.childNodes[0];
        const empty = CaseEmbellished.makeEmptyNode_(base.id);
        parent.childNodes[0] = empty;
        mml = new caller(semantic).getMathml();
        parent.childNodes[0] = base;
        this.parentCleanup.push(mml);
        return parent.childNodes[0];
    }
    introduceNewLayer_() {
        const fullOfence = this.fullFence(this.ofenceMml);
        const fullCfence = this.fullFence(this.cfenceMml);
        let newNode = (0, enrich_attr_js_1.addMrow)();
        DomUtil.replaceNode(this.fencedMml, newNode);
        this.fencedMmlNodes.forEach((node) => newNode.appendChild(node));
        newNode.insertBefore(fullOfence, this.fencedMml);
        newNode.appendChild(fullCfence);
        if (!newNode.parentNode) {
            const mrow = (0, enrich_attr_js_1.addMrow)();
            while (newNode.childNodes.length > 0) {
                mrow.appendChild(newNode.childNodes[0]);
            }
            newNode.appendChild(mrow);
            newNode = mrow;
        }
        return newNode;
    }
    fullFence(fence) {
        const parent = this.fencedMml.parentNode;
        let currentFence = fence;
        while (currentFence.parentNode && currentFence.parentNode !== parent) {
            currentFence = currentFence.parentNode;
        }
        return currentFence;
    }
    cleanupParents_() {
        this.parentCleanup.forEach(function (x) {
            const parent = x.childNodes[1].getAttribute(enrich_attr_js_1.Attribute.PARENT);
            x.childNodes[0].setAttribute(enrich_attr_js_1.Attribute.PARENT, parent);
        });
    }
}
exports.CaseEmbellished = CaseEmbellished;
