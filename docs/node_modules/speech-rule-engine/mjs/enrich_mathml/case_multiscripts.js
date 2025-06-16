import * as DomUtil from '../common/dom_util.js';
import { SemanticRole, SemanticType } from '../semantic_tree/semantic_meaning.js';
import { SemanticSkeleton } from '../semantic_tree/semantic_skeleton.js';
import { MMLTAGS } from '../semantic_tree/semantic_util.js';
import { CaseMultiindex } from './case_multiindex.js';
import * as EnrichMathml from './enrich_mathml.js';
import { setAttributes, Attribute } from './enrich_attr.js';
export class CaseMultiscripts extends CaseMultiindex {
    static test(semantic) {
        if (!semantic.mathmlTree) {
            return false;
        }
        const mmlTag = DomUtil.tagName(semantic.mathmlTree);
        return (mmlTag === MMLTAGS.MMULTISCRIPTS &&
            (semantic.type === SemanticType.SUPERSCRIPT ||
                semantic.type === SemanticType.SUBSCRIPT));
    }
    constructor(semantic) {
        super(semantic);
    }
    getMathml() {
        setAttributes(this.mml, this.semantic);
        let baseSem, rsup, rsub;
        if (this.semantic.childNodes[0] &&
            this.semantic.childNodes[0].role === SemanticRole.SUBSUP) {
            const ignore = this.semantic.childNodes[0];
            baseSem = ignore.childNodes[0];
            rsup = CaseMultiindex.multiscriptIndex(this.semantic.childNodes[1]);
            rsub = CaseMultiindex.multiscriptIndex(ignore.childNodes[1]);
            const collapsed = [this.semantic.id, [ignore.id, baseSem.id, rsub], rsup];
            EnrichMathml.addCollapsedAttribute(this.mml, collapsed);
            this.mml.setAttribute(Attribute.TYPE, ignore.role);
            this.completeMultiscript(SemanticSkeleton.interleaveIds(rsub, rsup), []);
        }
        else {
            baseSem = this.semantic.childNodes[0];
            rsup = CaseMultiindex.multiscriptIndex(this.semantic.childNodes[1]);
            const collapsed = [this.semantic.id, baseSem.id, rsup];
            EnrichMathml.addCollapsedAttribute(this.mml, collapsed);
        }
        const childIds = SemanticSkeleton.collapsedLeafs(rsub || [], rsup);
        const base = EnrichMathml.walkTree(baseSem);
        EnrichMathml.getInnerNode(base).setAttribute(Attribute.PARENT, this.semantic.id.toString());
        childIds.unshift(baseSem.id);
        this.mml.setAttribute(Attribute.CHILDREN, childIds.join(','));
        return this.mml;
    }
}
