import * as DomUtil from '../common/dom_util.js';
import { SemanticType } from '../semantic_tree/semantic_meaning.js';
import { MMLTAGS } from '../semantic_tree/semantic_util.js';
import { AbstractEnrichCase } from './abstract_enrich_case.js';
import * as EnrichMathml from './enrich_mathml.js';
import { setAttributes } from './enrich_attr.js';
export class CaseLimit extends AbstractEnrichCase {
    static test(semantic) {
        if (!semantic.mathmlTree || !semantic.childNodes.length) {
            return false;
        }
        const mmlTag = DomUtil.tagName(semantic.mathmlTree);
        const type = semantic.type;
        return (((type === SemanticType.LIMUPPER || type === SemanticType.LIMLOWER) &&
            (mmlTag === MMLTAGS.MSUBSUP || mmlTag === MMLTAGS.MUNDEROVER)) ||
            (type === SemanticType.LIMBOTH &&
                (mmlTag === MMLTAGS.MSUB ||
                    mmlTag === MMLTAGS.MUNDER ||
                    mmlTag === MMLTAGS.MSUP ||
                    mmlTag === MMLTAGS.MOVER)));
    }
    static walkTree_(node) {
        if (node) {
            EnrichMathml.walkTree(node);
        }
    }
    constructor(semantic) {
        super(semantic);
        this.mml = semantic.mathmlTree;
    }
    getMathml() {
        const children = this.semantic.childNodes;
        if (this.semantic.type !== SemanticType.LIMBOTH &&
            this.mml.childNodes.length >= 3) {
            this.mml = EnrichMathml.introduceNewLayer([this.mml], this.semantic);
        }
        setAttributes(this.mml, this.semantic);
        if (!children[0].mathmlTree) {
            children[0].mathmlTree = this.semantic.mathmlTree;
        }
        children.forEach(CaseLimit.walkTree_);
        return this.mml;
    }
}
