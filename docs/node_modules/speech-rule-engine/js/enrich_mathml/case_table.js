"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CaseTable = void 0;
const DomUtil = require("../common/dom_util.js");
const semantic_meaning_js_1 = require("../semantic_tree/semantic_meaning.js");
const semantic_util_js_1 = require("../semantic_tree/semantic_util.js");
const abstract_enrich_case_js_1 = require("./abstract_enrich_case.js");
const EnrichMathml = require("./enrich_mathml.js");
const enrich_attr_js_1 = require("./enrich_attr.js");
class CaseTable extends abstract_enrich_case_js_1.AbstractEnrichCase {
    static test(semantic) {
        return (semantic.type === semantic_meaning_js_1.SemanticType.MATRIX ||
            semantic.type === semantic_meaning_js_1.SemanticType.VECTOR ||
            semantic.type === semantic_meaning_js_1.SemanticType.CASES);
    }
    constructor(semantic) {
        super(semantic);
        this.inner = [];
        this.mml = semantic.mathmlTree;
    }
    getMathml() {
        const lfence = EnrichMathml.cloneContentNode(this.semantic.contentNodes[0]);
        const rfence = this.semantic.contentNodes[1]
            ? EnrichMathml.cloneContentNode(this.semantic.contentNodes[1])
            : null;
        this.inner = this.semantic.childNodes.map(EnrichMathml.walkTree);
        if (!this.mml) {
            this.mml = EnrichMathml.introduceNewLayer([lfence].concat(this.inner, [rfence]), this.semantic);
        }
        else if (DomUtil.tagName(this.mml) === semantic_util_js_1.MMLTAGS.MFENCED) {
            const children = this.mml.childNodes;
            this.mml.insertBefore(lfence, children[0] || null);
            if (rfence) {
                this.mml.appendChild(rfence);
            }
            this.mml = EnrichMathml.rewriteMfenced(this.mml);
        }
        else {
            const newChildren = [lfence, this.mml];
            if (rfence) {
                newChildren.push(rfence);
            }
            this.mml = EnrichMathml.introduceNewLayer(newChildren, this.semantic);
        }
        (0, enrich_attr_js_1.setAttributes)(this.mml, this.semantic);
        return this.mml;
    }
}
exports.CaseTable = CaseTable;
