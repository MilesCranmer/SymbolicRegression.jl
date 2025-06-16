import * as DomUtil from '../common/dom_util.js';
import { SemanticRole, SemanticType } from '../semantic_tree/semantic_meaning.js';
import { MMLTAGS } from '../semantic_tree/semantic_util.js';
import { AbstractEnrichCase } from './abstract_enrich_case.js';
import * as EnrichMathml from './enrich_mathml.js';
import { setAttributes, Attribute } from './enrich_attr.js';
export class CaseMultiindex extends AbstractEnrichCase {
    static multiscriptIndex(index) {
        if (index.type === SemanticType.PUNCTUATED &&
            index.contentNodes[0].role === SemanticRole.DUMMY) {
            return EnrichMathml.collapsePunctuated(index);
        }
        EnrichMathml.walkTree(index);
        return index.id;
    }
    static createNone_(semantic) {
        const newNode = DomUtil.createElement('none');
        if (semantic) {
            setAttributes(newNode, semantic);
        }
        newNode.setAttribute(Attribute.ADDED, 'true');
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
                if (child && index === parseInt(child.getAttribute(Attribute.ID))) {
                    child.setAttribute(Attribute.PARENT, this.semantic.id.toString());
                    childCounter++;
                }
                else if (!child ||
                    index !==
                        parseInt(EnrichMathml.getInnerNode(child).getAttribute(Attribute.ID))) {
                    const query = this.semantic.querySelectorAll((x) => x.id === index);
                    this.mml.insertBefore(CaseMultiindex.createNone_(query[0]), child || null);
                }
                else {
                    EnrichMathml.getInnerNode(child).setAttribute(Attribute.PARENT, this.semantic.id.toString());
                    childCounter++;
                }
            }
        };
        completeIndices(rightIndices);
        if (children[childCounter] &&
            DomUtil.tagName(children[childCounter]) !== MMLTAGS.MPRESCRIPTS) {
            this.mml.insertBefore(children[childCounter], DomUtil.createElement('mprescripts'));
        }
        else {
            childCounter++;
        }
        completeIndices(leftIndices);
    }
}
