"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CaseMultiscripts = void 0;
const DomUtil = require("../common/dom_util.js");
const semantic_meaning_js_1 = require("../semantic_tree/semantic_meaning.js");
const semantic_skeleton_js_1 = require("../semantic_tree/semantic_skeleton.js");
const semantic_util_js_1 = require("../semantic_tree/semantic_util.js");
const case_multiindex_js_1 = require("./case_multiindex.js");
const EnrichMathml = require("./enrich_mathml.js");
const enrich_attr_js_1 = require("./enrich_attr.js");
class CaseMultiscripts extends case_multiindex_js_1.CaseMultiindex {
    static test(semantic) {
        if (!semantic.mathmlTree) {
            return false;
        }
        const mmlTag = DomUtil.tagName(semantic.mathmlTree);
        return (mmlTag === semantic_util_js_1.MMLTAGS.MMULTISCRIPTS &&
            (semantic.type === semantic_meaning_js_1.SemanticType.SUPERSCRIPT ||
                semantic.type === semantic_meaning_js_1.SemanticType.SUBSCRIPT));
    }
    constructor(semantic) {
        super(semantic);
    }
    getMathml() {
        (0, enrich_attr_js_1.setAttributes)(this.mml, this.semantic);
        let baseSem, rsup, rsub;
        if (this.semantic.childNodes[0] &&
            this.semantic.childNodes[0].role === semantic_meaning_js_1.SemanticRole.SUBSUP) {
            const ignore = this.semantic.childNodes[0];
            baseSem = ignore.childNodes[0];
            rsup = case_multiindex_js_1.CaseMultiindex.multiscriptIndex(this.semantic.childNodes[1]);
            rsub = case_multiindex_js_1.CaseMultiindex.multiscriptIndex(ignore.childNodes[1]);
            const collapsed = [this.semantic.id, [ignore.id, baseSem.id, rsub], rsup];
            EnrichMathml.addCollapsedAttribute(this.mml, collapsed);
            this.mml.setAttribute(enrich_attr_js_1.Attribute.TYPE, ignore.role);
            this.completeMultiscript(semantic_skeleton_js_1.SemanticSkeleton.interleaveIds(rsub, rsup), []);
        }
        else {
            baseSem = this.semantic.childNodes[0];
            rsup = case_multiindex_js_1.CaseMultiindex.multiscriptIndex(this.semantic.childNodes[1]);
            const collapsed = [this.semantic.id, baseSem.id, rsup];
            EnrichMathml.addCollapsedAttribute(this.mml, collapsed);
        }
        const childIds = semantic_skeleton_js_1.SemanticSkeleton.collapsedLeafs(rsub || [], rsup);
        const base = EnrichMathml.walkTree(baseSem);
        EnrichMathml.getInnerNode(base).setAttribute(enrich_attr_js_1.Attribute.PARENT, this.semantic.id.toString());
        childIds.unshift(baseSem.id);
        this.mml.setAttribute(enrich_attr_js_1.Attribute.CHILDREN, childIds.join(','));
        return this.mml;
    }
}
exports.CaseMultiscripts = CaseMultiscripts;
