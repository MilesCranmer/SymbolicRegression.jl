import { SemanticType } from '../semantic_tree/semantic_meaning.js';
import { AbstractEnrichCase } from './abstract_enrich_case.js';
import * as EnrichMathml from './enrich_mathml.js';
import { setAttributes } from './enrich_attr.js';
export class CaseLine extends AbstractEnrichCase {
    static test(semantic) {
        return !!semantic.mathmlTree && semantic.type === SemanticType.LINE;
    }
    constructor(semantic) {
        super(semantic);
        this.mml = semantic.mathmlTree;
    }
    getMathml() {
        if (this.semantic.contentNodes.length) {
            EnrichMathml.walkTree(this.semantic.contentNodes[0]);
        }
        if (this.semantic.childNodes.length) {
            EnrichMathml.walkTree(this.semantic.childNodes[0]);
        }
        setAttributes(this.mml, this.semantic);
        return this.mml;
    }
}
