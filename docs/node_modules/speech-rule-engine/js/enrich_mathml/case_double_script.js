"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CaseDoubleScript = void 0;
const DomUtil = require("../common/dom_util.js");
const semantic_meaning_js_1 = require("../semantic_tree/semantic_meaning.js");
const semantic_util_js_1 = require("../semantic_tree/semantic_util.js");
const abstract_enrich_case_js_1 = require("./abstract_enrich_case.js");
const EnrichMathml = require("./enrich_mathml.js");
const enrich_attr_js_1 = require("./enrich_attr.js");
class CaseDoubleScript extends abstract_enrich_case_js_1.AbstractEnrichCase {
    static test(semantic) {
        if (!semantic.mathmlTree || !semantic.childNodes.length) {
            return false;
        }
        const mmlTag = DomUtil.tagName(semantic.mathmlTree);
        const role = semantic.childNodes[0].role;
        return ((mmlTag === semantic_util_js_1.MMLTAGS.MSUBSUP && role === semantic_meaning_js_1.SemanticRole.SUBSUP) ||
            (mmlTag === semantic_util_js_1.MMLTAGS.MUNDEROVER && role === semantic_meaning_js_1.SemanticRole.UNDEROVER));
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
        (0, enrich_attr_js_1.setAttributes)(this.mml, this.semantic);
        this.mml.setAttribute(enrich_attr_js_1.Attribute.CHILDREN, (0, enrich_attr_js_1.makeIdList)([baseSem, subSem, supSem]));
        [baseMml, subMml, supMml].forEach((child) => EnrichMathml.getInnerNode(child).setAttribute(enrich_attr_js_1.Attribute.PARENT, this.mml.getAttribute(enrich_attr_js_1.Attribute.ID)));
        this.mml.setAttribute(enrich_attr_js_1.Attribute.TYPE, ignore.role);
        EnrichMathml.addCollapsedAttribute(this.mml, [
            this.semantic.id,
            [ignore.id, baseSem.id, subSem.id],
            supSem.id
        ]);
        return this.mml;
    }
}
exports.CaseDoubleScript = CaseDoubleScript;
