import { SemanticType } from '../semantic_tree/semantic_meaning.js';
import { AbstractEnrichCase } from './abstract_enrich_case.js';
import * as EnrichMathml from './enrich_mathml.js';
import { setAttributes } from './enrich_attr.js';
export class CaseProof extends AbstractEnrichCase {
    static test(semantic) {
        return (!!semantic.mathmlTree &&
            (semantic.type === SemanticType.INFERENCE ||
                semantic.type === SemanticType.PREMISES));
    }
    constructor(semantic) {
        super(semantic);
        this.mml = semantic.mathmlTree;
    }
    getMathml() {
        if (!this.semantic.childNodes.length) {
            return this.mml;
        }
        this.semantic.contentNodes.forEach(function (x) {
            EnrichMathml.walkTree(x);
            setAttributes(x.mathmlTree, x);
        });
        this.semantic.childNodes.forEach(function (x) {
            EnrichMathml.walkTree(x);
        });
        setAttributes(this.mml, this.semantic);
        if (this.mml.getAttribute('data-semantic-id') ===
            this.mml.getAttribute('data-semantic-parent')) {
            this.mml.removeAttribute('data-semantic-parent');
        }
        return this.mml;
    }
}
