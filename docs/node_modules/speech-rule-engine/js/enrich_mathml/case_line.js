"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CaseLine = void 0;
const semantic_meaning_js_1 = require("../semantic_tree/semantic_meaning.js");
const abstract_enrich_case_js_1 = require("./abstract_enrich_case.js");
const EnrichMathml = require("./enrich_mathml.js");
const enrich_attr_js_1 = require("./enrich_attr.js");
class CaseLine extends abstract_enrich_case_js_1.AbstractEnrichCase {
    static test(semantic) {
        return !!semantic.mathmlTree && semantic.type === semantic_meaning_js_1.SemanticType.LINE;
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
        (0, enrich_attr_js_1.setAttributes)(this.mml, this.semantic);
        return this.mml;
    }
}
exports.CaseLine = CaseLine;
