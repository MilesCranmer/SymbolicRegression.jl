"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CaseText = void 0;
const semantic_meaning_js_1 = require("../semantic_tree/semantic_meaning.js");
const abstract_enrich_case_js_1 = require("./abstract_enrich_case.js");
const EnrichMathml = require("./enrich_mathml.js");
const enrich_attr_js_1 = require("./enrich_attr.js");
class CaseText extends abstract_enrich_case_js_1.AbstractEnrichCase {
    static test(semantic) {
        return (semantic.type === semantic_meaning_js_1.SemanticType.PUNCTUATED &&
            (semantic.role === semantic_meaning_js_1.SemanticRole.TEXT ||
                semantic.contentNodes.every((x) => x.role === semantic_meaning_js_1.SemanticRole.DUMMY)));
    }
    constructor(semantic) {
        super(semantic);
        this.mml = semantic.mathmlTree;
    }
    getMathml() {
        const children = [];
        const collapsed = EnrichMathml.collapsePunctuated(this.semantic, children);
        this.mml = EnrichMathml.introduceNewLayer(children, this.semantic);
        (0, enrich_attr_js_1.setAttributes)(this.mml, this.semantic);
        this.mml.removeAttribute(enrich_attr_js_1.Attribute.CONTENT);
        EnrichMathml.addCollapsedAttribute(this.mml, collapsed);
        return this.mml;
    }
}
exports.CaseText = CaseText;
