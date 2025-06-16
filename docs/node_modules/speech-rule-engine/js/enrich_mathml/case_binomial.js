"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CaseBinomial = void 0;
const DomUtil = require("../common/dom_util.js");
const semantic_meaning_js_1 = require("../semantic_tree/semantic_meaning.js");
const abstract_enrich_case_js_1 = require("./abstract_enrich_case.js");
const enrich_mathml_js_1 = require("./enrich_mathml.js");
const enrich_attr_js_1 = require("./enrich_attr.js");
class CaseBinomial extends abstract_enrich_case_js_1.AbstractEnrichCase {
    static test(semantic) {
        return (!semantic.mathmlTree &&
            semantic.type === semantic_meaning_js_1.SemanticType.LINE &&
            semantic.role === semantic_meaning_js_1.SemanticRole.BINOMIAL);
    }
    constructor(semantic) {
        super(semantic);
        this.mml = semantic.mathmlTree;
    }
    getMathml() {
        if (!this.semantic.childNodes.length) {
            return this.mml;
        }
        const child = this.semantic.childNodes[0];
        this.mml = (0, enrich_mathml_js_1.walkTree)(child);
        if (this.mml.hasAttribute(enrich_attr_js_1.Attribute.TYPE)) {
            const mrow = (0, enrich_attr_js_1.addMrow)();
            DomUtil.replaceNode(this.mml, mrow);
            mrow.appendChild(this.mml);
            this.mml = mrow;
        }
        (0, enrich_attr_js_1.setAttributes)(this.mml, this.semantic);
        return this.mml;
    }
}
exports.CaseBinomial = CaseBinomial;
