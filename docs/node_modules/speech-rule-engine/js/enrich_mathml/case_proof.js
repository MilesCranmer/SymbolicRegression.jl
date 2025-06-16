"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CaseProof = void 0;
const semantic_meaning_js_1 = require("../semantic_tree/semantic_meaning.js");
const abstract_enrich_case_js_1 = require("./abstract_enrich_case.js");
const EnrichMathml = require("./enrich_mathml.js");
const enrich_attr_js_1 = require("./enrich_attr.js");
class CaseProof extends abstract_enrich_case_js_1.AbstractEnrichCase {
    static test(semantic) {
        return (!!semantic.mathmlTree &&
            (semantic.type === semantic_meaning_js_1.SemanticType.INFERENCE ||
                semantic.type === semantic_meaning_js_1.SemanticType.PREMISES));
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
            (0, enrich_attr_js_1.setAttributes)(x.mathmlTree, x);
        });
        this.semantic.childNodes.forEach(function (x) {
            EnrichMathml.walkTree(x);
        });
        (0, enrich_attr_js_1.setAttributes)(this.mml, this.semantic);
        if (this.mml.getAttribute('data-semantic-id') ===
            this.mml.getAttribute('data-semantic-parent')) {
            this.mml.removeAttribute('data-semantic-parent');
        }
        return this.mml;
    }
}
exports.CaseProof = CaseProof;
