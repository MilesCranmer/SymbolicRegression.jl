"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CaseLimit = void 0;
const DomUtil = require("../common/dom_util.js");
const semantic_meaning_js_1 = require("../semantic_tree/semantic_meaning.js");
const semantic_util_js_1 = require("../semantic_tree/semantic_util.js");
const abstract_enrich_case_js_1 = require("./abstract_enrich_case.js");
const EnrichMathml = require("./enrich_mathml.js");
const enrich_attr_js_1 = require("./enrich_attr.js");
class CaseLimit extends abstract_enrich_case_js_1.AbstractEnrichCase {
    static test(semantic) {
        if (!semantic.mathmlTree || !semantic.childNodes.length) {
            return false;
        }
        const mmlTag = DomUtil.tagName(semantic.mathmlTree);
        const type = semantic.type;
        return (((type === semantic_meaning_js_1.SemanticType.LIMUPPER || type === semantic_meaning_js_1.SemanticType.LIMLOWER) &&
            (mmlTag === semantic_util_js_1.MMLTAGS.MSUBSUP || mmlTag === semantic_util_js_1.MMLTAGS.MUNDEROVER)) ||
            (type === semantic_meaning_js_1.SemanticType.LIMBOTH &&
                (mmlTag === semantic_util_js_1.MMLTAGS.MSUB ||
                    mmlTag === semantic_util_js_1.MMLTAGS.MUNDER ||
                    mmlTag === semantic_util_js_1.MMLTAGS.MSUP ||
                    mmlTag === semantic_util_js_1.MMLTAGS.MOVER)));
    }
    static walkTree_(node) {
        if (node) {
            EnrichMathml.walkTree(node);
        }
    }
    constructor(semantic) {
        super(semantic);
        this.mml = semantic.mathmlTree;
    }
    getMathml() {
        const children = this.semantic.childNodes;
        if (this.semantic.type !== semantic_meaning_js_1.SemanticType.LIMBOTH &&
            this.mml.childNodes.length >= 3) {
            this.mml = EnrichMathml.introduceNewLayer([this.mml], this.semantic);
        }
        (0, enrich_attr_js_1.setAttributes)(this.mml, this.semantic);
        if (!children[0].mathmlTree) {
            children[0].mathmlTree = this.semantic.mathmlTree;
        }
        children.forEach(CaseLimit.walkTree_);
        return this.mml;
    }
}
exports.CaseLimit = CaseLimit;
