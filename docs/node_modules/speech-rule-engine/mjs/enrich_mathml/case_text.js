import { SemanticRole, SemanticType } from '../semantic_tree/semantic_meaning.js';
import { AbstractEnrichCase } from './abstract_enrich_case.js';
import * as EnrichMathml from './enrich_mathml.js';
import { setAttributes, Attribute } from './enrich_attr.js';
export class CaseText extends AbstractEnrichCase {
    static test(semantic) {
        return (semantic.type === SemanticType.PUNCTUATED &&
            (semantic.role === SemanticRole.TEXT ||
                semantic.contentNodes.every((x) => x.role === SemanticRole.DUMMY)));
    }
    constructor(semantic) {
        super(semantic);
        this.mml = semantic.mathmlTree;
    }
    getMathml() {
        const children = [];
        const collapsed = EnrichMathml.collapsePunctuated(this.semantic, children);
        this.mml = EnrichMathml.introduceNewLayer(children, this.semantic);
        setAttributes(this.mml, this.semantic);
        this.mml.removeAttribute(Attribute.CONTENT);
        EnrichMathml.addCollapsedAttribute(this.mml, collapsed);
        return this.mml;
    }
}
