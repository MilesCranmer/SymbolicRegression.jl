import * as DomUtil from '../common/dom_util.js';
import { SemanticType } from '../semantic_tree/semantic_meaning.js';
import { MMLTAGS } from '../semantic_tree/semantic_util.js';
import { AbstractEnrichCase } from './abstract_enrich_case.js';
import * as EnrichMathml from './enrich_mathml.js';
import { setAttributes } from './enrich_attr.js';
export class CaseTable extends AbstractEnrichCase {
    static test(semantic) {
        return (semantic.type === SemanticType.MATRIX ||
            semantic.type === SemanticType.VECTOR ||
            semantic.type === SemanticType.CASES);
    }
    constructor(semantic) {
        super(semantic);
        this.inner = [];
        this.mml = semantic.mathmlTree;
    }
    getMathml() {
        const lfence = EnrichMathml.cloneContentNode(this.semantic.contentNodes[0]);
        const rfence = this.semantic.contentNodes[1]
            ? EnrichMathml.cloneContentNode(this.semantic.contentNodes[1])
            : null;
        this.inner = this.semantic.childNodes.map(EnrichMathml.walkTree);
        if (!this.mml) {
            this.mml = EnrichMathml.introduceNewLayer([lfence].concat(this.inner, [rfence]), this.semantic);
        }
        else if (DomUtil.tagName(this.mml) === MMLTAGS.MFENCED) {
            const children = this.mml.childNodes;
            this.mml.insertBefore(lfence, children[0] || null);
            if (rfence) {
                this.mml.appendChild(rfence);
            }
            this.mml = EnrichMathml.rewriteMfenced(this.mml);
        }
        else {
            const newChildren = [lfence, this.mml];
            if (rfence) {
                newChildren.push(rfence);
            }
            this.mml = EnrichMathml.introduceNewLayer(newChildren, this.semantic);
        }
        setAttributes(this.mml, this.semantic);
        return this.mml;
    }
}
