import * as DomUtil from '../common/dom_util.js';
import { SemanticRole, SemanticType } from '../semantic_tree/semantic_meaning.js';
import { AbstractEnrichCase } from './abstract_enrich_case.js';
import { walkTree } from './enrich_mathml.js';
import { addMrow, setAttributes, Attribute } from './enrich_attr.js';
export class CaseBinomial extends AbstractEnrichCase {
    static test(semantic) {
        return (!semantic.mathmlTree &&
            semantic.type === SemanticType.LINE &&
            semantic.role === SemanticRole.BINOMIAL);
    }
    constructor(semantic) {
        super(semantic);
        this.mml = semantic.mathmlTree;
    }
    getMathml() {
        if (!this.semantic.childNodes.length) {
            return this.mml;
        }
        const child = this.semantic.childNodes[0];
        this.mml = walkTree(child);
        if (this.mml.hasAttribute(Attribute.TYPE)) {
            const mrow = addMrow();
            DomUtil.replaceNode(this.mml, mrow);
            mrow.appendChild(this.mml);
            this.mml = mrow;
        }
        setAttributes(this.mml, this.semantic);
        return this.mml;
    }
}
