"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CaseMultiindex = void 0;
const DomUtil = require("../common/dom_util.js");
const semantic_meaning_js_1 = require("../semantic_tree/semantic_meaning.js");
const semantic_util_js_1 = require("../semantic_tree/semantic_util.js");
const abstract_enrich_case_js_1 = require("./abstract_enrich_case.js");
const EnrichMathml = require("./enrich_mathml.js");
const enrich_attr_js_1 = require("./enrich_attr.js");
class CaseMultiindex extends abstract_enrich_case_js_1.AbstractEnrichCase {
    static multiscriptIndex(index) {
        if (index.type === semantic_meaning_js_1.SemanticType.PUNCTUATED &&
            index.contentNodes[0].role === semantic_meaning_js_1.SemanticRole.DUMMY) {
            return EnrichMathml.collapsePunctuated(index);
        }
        EnrichMathml.walkTree(index);
        return index.id;
    }
    static createNone_(semantic) {
        const newNode = DomUtil.createElement('none');
        if (semantic) {
            (0, enrich_attr_js_1.setAttributes)(newNode, semantic);
        }
        newNode.setAttribute(enrich_attr_js_1.Attribute.ADDED, 'true');
        return newNode;
    }
    constructor(semantic) {
        super(semantic);
        this.mml = semantic.mathmlTree;
    }
    completeMultiscript(rightIndices, leftIndices) {
        const children = DomUtil.toArray(this.mml.childNodes).slice(1);
        let childCounter = 0;
        const completeIndices = (indices) => {
            for (const index of indices) {
                const child = children[childCounter];
                if (child && index === parseInt(child.getAttribute(enrich_attr_js_1.Attribute.ID))) {
                    child.setAttribute(enrich_attr_js_1.Attribute.PARENT, this.semantic.id.toString());
                    childCounter++;
                }
                else if (!child ||
                    index !==
                        parseInt(EnrichMathml.getInnerNode(child).getAttribute(enrich_attr_js_1.Attribute.ID))) {
                    const query = this.semantic.querySelectorAll((x) => x.id === index);
                    this.mml.insertBefore(CaseMultiindex.createNone_(query[0]), child || null);
                }
                else {
                    EnrichMathml.getInnerNode(child).setAttribute(enrich_attr_js_1.Attribute.PARENT, this.semantic.id.toString());
                    childCounter++;
                }
            }
        };
        completeIndices(rightIndices);
        if (children[childCounter] &&
            DomUtil.tagName(children[childCounter]) !== semantic_util_js_1.MMLTAGS.MPRESCRIPTS) {
            this.mml.insertBefore(children[childCounter], DomUtil.createElement('mprescripts'));
        }
        else {
            childCounter++;
        }
        completeIndices(leftIndices);
    }
}
exports.CaseMultiindex = CaseMultiindex;
