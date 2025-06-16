import * as DomUtil from '../common/dom_util.js';
import { SemanticRole, SemanticType } from '../semantic_tree/semantic_meaning.js';
import { SemanticNode } from '../semantic_tree/semantic_node.js';
import { MMLTAGS } from '../semantic_tree/semantic_util.js';
import { AbstractEnrichCase } from './abstract_enrich_case.js';
import { CaseDoubleScript } from './case_double_script.js';
import { CaseMultiscripts } from './case_multiscripts.js';
import { CaseTensor } from './case_tensor.js';
import * as EnrichMathml from './enrich_mathml.js';
import { addMrow, setAttributes, Attribute } from './enrich_attr.js';
export class CaseEmbellished extends AbstractEnrichCase {
    static test(semantic) {
        return !!(semantic.mathmlTree &&
            semantic.fencePointer &&
            !semantic.mathmlTree.getAttribute('data-semantic-type'));
    }
    static makeEmptyNode_(id) {
        const mrow = addMrow();
        const empty = new SemanticNode(id);
        empty.type = SemanticType.EMPTY;
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
        if (this.fenced.type === SemanticType.EMPTY && !this.fencedMml.parentNode) {
            this.fencedMml.setAttribute(Attribute.ADDED, 'true');
            this.cfenceMml.parentNode.insertBefore(this.fencedMml, this.cfenceMml);
        }
        this.getFencedMml_();
        const rewrite = this.rewrite_();
        return rewrite;
    }
    fencedElement(node) {
        return (node.type === SemanticType.FENCED ||
            node.type === SemanticType.MATRIX ||
            node.type === SemanticType.VECTOR);
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
        setAttributes(newNode, this.fenced.parent);
        while (!this.fencedElement(currentNode)) {
            const mml = currentNode.mathmlTree;
            const specialCase = this.specialCase_(currentNode, mml);
            if (specialCase) {
                currentNode = specialCase;
            }
            else {
                setAttributes(mml, currentNode);
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
        if (mmlTag === MMLTAGS.MSUBSUP) {
            parent = semantic.childNodes[0];
            caller = CaseDoubleScript;
        }
        else if (mmlTag === MMLTAGS.MMULTISCRIPTS) {
            if (semantic.type === SemanticType.SUPERSCRIPT ||
                semantic.type === SemanticType.SUBSCRIPT) {
                caller = CaseMultiscripts;
            }
            else if (semantic.type === SemanticType.TENSOR) {
                caller = CaseTensor;
            }
            if (caller &&
                semantic.childNodes[0] &&
                semantic.childNodes[0].role === SemanticRole.SUBSUP) {
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
        let newNode = addMrow();
        DomUtil.replaceNode(this.fencedMml, newNode);
        this.fencedMmlNodes.forEach((node) => newNode.appendChild(node));
        newNode.insertBefore(fullOfence, this.fencedMml);
        newNode.appendChild(fullCfence);
        if (!newNode.parentNode) {
            const mrow = addMrow();
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
            const parent = x.childNodes[1].getAttribute(Attribute.PARENT);
            x.childNodes[0].setAttribute(Attribute.PARENT, parent);
        });
    }
}
