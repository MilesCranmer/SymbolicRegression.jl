import { SemanticType } from '../semantic_tree/semantic_meaning.js';
import { SemanticSkeleton } from '../semantic_tree/semantic_skeleton.js';
import { CaseMultiindex } from './case_multiindex.js';
import * as EnrichMathml from './enrich_mathml.js';
import { setAttributes, Attribute } from './enrich_attr.js';
export class CaseTensor extends CaseMultiindex {
    static test(semantic) {
        return !!semantic.mathmlTree && semantic.type === SemanticType.TENSOR;
    }
    constructor(semantic) {
        super(semantic);
    }
    getMathml() {
        EnrichMathml.walkTree(this.semantic.childNodes[0]);
        const lsub = CaseMultiindex.multiscriptIndex(this.semantic.childNodes[1]);
        const lsup = CaseMultiindex.multiscriptIndex(this.semantic.childNodes[2]);
        const rsub = CaseMultiindex.multiscriptIndex(this.semantic.childNodes[3]);
        const rsup = CaseMultiindex.multiscriptIndex(this.semantic.childNodes[4]);
        setAttributes(this.mml, this.semantic);
        const collapsed = [
            this.semantic.id,
            this.semantic.childNodes[0].id,
            lsub,
            lsup,
            rsub,
            rsup
        ];
        EnrichMathml.addCollapsedAttribute(this.mml, collapsed);
        const childIds = SemanticSkeleton.collapsedLeafs(lsub, lsup, rsub, rsup);
        childIds.unshift(this.semantic.childNodes[0].id);
        this.mml.setAttribute(Attribute.CHILDREN, childIds.join(','));
        this.completeMultiscript(SemanticSkeleton.interleaveIds(rsub, rsup), SemanticSkeleton.interleaveIds(lsub, lsup));
        return this.mml;
    }
}
