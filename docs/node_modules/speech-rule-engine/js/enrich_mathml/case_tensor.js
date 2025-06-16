"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CaseTensor = void 0;
const semantic_meaning_js_1 = require("../semantic_tree/semantic_meaning.js");
const semantic_skeleton_js_1 = require("../semantic_tree/semantic_skeleton.js");
const case_multiindex_js_1 = require("./case_multiindex.js");
const EnrichMathml = require("./enrich_mathml.js");
const enrich_attr_js_1 = require("./enrich_attr.js");
class CaseTensor extends case_multiindex_js_1.CaseMultiindex {
    static test(semantic) {
        return !!semantic.mathmlTree && semantic.type === semantic_meaning_js_1.SemanticType.TENSOR;
    }
    constructor(semantic) {
        super(semantic);
    }
    getMathml() {
        EnrichMathml.walkTree(this.semantic.childNodes[0]);
        const lsub = case_multiindex_js_1.CaseMultiindex.multiscriptIndex(this.semantic.childNodes[1]);
        const lsup = case_multiindex_js_1.CaseMultiindex.multiscriptIndex(this.semantic.childNodes[2]);
        const rsub = case_multiindex_js_1.CaseMultiindex.multiscriptIndex(this.semantic.childNodes[3]);
        const rsup = case_multiindex_js_1.CaseMultiindex.multiscriptIndex(this.semantic.childNodes[4]);
        (0, enrich_attr_js_1.setAttributes)(this.mml, this.semantic);
        const collapsed = [
            this.semantic.id,
            this.semantic.childNodes[0].id,
            lsub,
            lsup,
            rsub,
            rsup
        ];
        EnrichMathml.addCollapsedAttribute(this.mml, collapsed);
        const childIds = semantic_skeleton_js_1.SemanticSkeleton.collapsedLeafs(lsub, lsup, rsub, rsup);
        childIds.unshift(this.semantic.childNodes[0].id);
        this.mml.setAttribute(enrich_attr_js_1.Attribute.CHILDREN, childIds.join(','));
        this.completeMultiscript(semantic_skeleton_js_1.SemanticSkeleton.interleaveIds(rsub, rsup), semantic_skeleton_js_1.SemanticSkeleton.interleaveIds(lsub, lsup));
        return this.mml;
    }
}
exports.CaseTensor = CaseTensor;
