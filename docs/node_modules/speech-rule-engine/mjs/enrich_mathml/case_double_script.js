import * as DomUtil from '../common/dom_util.js';
import { SemanticRole } from '../semantic_tree/semantic_meaning.js';
import { MMLTAGS } from '../semantic_tree/semantic_util.js';
import { AbstractEnrichCase } from './abstract_enrich_case.js';
import * as EnrichMathml from './enrich_mathml.js';
import { makeIdList, setAttributes, Attribute } from './enrich_attr.js';
export class CaseDoubleScript extends AbstractEnrichCase {
    static test(semantic) {
        if (!semantic.mathmlTree || !semantic.childNodes.length) {
            return false;
        }
        const mmlTag = DomUtil.tagName(semantic.mathmlTree);
        const role = semantic.childNodes[0].role;
        return ((mmlTag === MMLTAGS.MSUBSUP && role === SemanticRole.SUBSUP) ||
            (mmlTag === MMLTAGS.MUNDEROVER && role === SemanticRole.UNDEROVER));
    }
    constructor(semantic) {
        super(semantic);
        this.mml = semantic.mathmlTree;
    }
    getMathml() {
        const ignore = this.semantic.childNodes[0];
        const baseSem = ignore.childNodes[0];
        const supSem = this.semantic.childNodes[1];
        const subSem = ignore.childNodes[1];
        const supMml = EnrichMathml.walkTree(supSem);
        const baseMml = EnrichMathml.walkTree(baseSem);
        const subMml = EnrichMathml.walkTree(subSem);
        setAttributes(this.mml, this.semantic);
        this.mml.setAttribute(Attribute.CHILDREN, makeIdList([baseSem, subSem, supSem]));
        [baseMml, subMml, supMml].forEach((child) => EnrichMathml.getInnerNode(child).setAttribute(Attribute.PARENT, this.mml.getAttribute(Attribute.ID)));
        this.mml.setAttribute(Attribute.TYPE, ignore.role);
        EnrichMathml.addCollapsedAttribute(this.mml, [
            this.semantic.id,
            [ignore.id, baseSem.id, subSem.id],
            supSem.id
        ]);
        return this.mml;
    }
}
