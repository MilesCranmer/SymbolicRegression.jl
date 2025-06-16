import { MMLTAGS } from '../semantic_tree/semantic_util.js';
import { AbstractEnrichCase } from './abstract_enrich_case.js';
import * as EnrichMathml from './enrich_mathml.js';
import { addMrow, setAttributes } from './enrich_attr.js';
import * as DomUtil from '../common/dom_util.js';
export class CaseEmpheq extends AbstractEnrichCase {
    static test(semantic) {
        return !!semantic.mathmlTree && semantic.hasAnnotation('Emph', 'top');
    }
    constructor(semantic) {
        super(semantic);
        this.mrows = [];
        this.mml = semantic.mathmlTree;
    }
    getMathml() {
        this.recurseToTable(this.semantic);
        if (this.mrows.length) {
            const newRow = addMrow();
            const parent = this.mml.parentNode;
            parent.insertBefore(newRow, this.mml);
            for (const mrow of this.mrows) {
                newRow.appendChild(mrow);
            }
            newRow.appendChild(this.mml);
        }
        return this.mml;
    }
    recurseToTable(node) {
        var _a, _b;
        if (!(node.hasAnnotation('Emph', 'top') || node.hasAnnotation('Emph', 'fence')) &&
            (node.hasAnnotation('Emph', 'left') ||
                node.hasAnnotation('Emph', 'right'))) {
            EnrichMathml.walkTree(node);
            return;
        }
        if (!node.mathmlTree ||
            (DomUtil.tagName(node.mathmlTree) === MMLTAGS.MTABLE &&
                ((_a = node.annotation['Emph']) === null || _a === void 0 ? void 0 : _a.length) &&
                node.annotation['Emph'][0] !== 'table')) {
            const newNode = addMrow();
            setAttributes(newNode, node);
            this.mrows.unshift(newNode);
        }
        else {
            if (DomUtil.tagName(node.mathmlTree) === MMLTAGS.MTABLE &&
                ((_b = node.annotation['Emph']) === null || _b === void 0 ? void 0 : _b.length) &&
                node.annotation['Emph'][0] === 'table') {
                this.finalizeTable(node);
                return;
            }
            setAttributes(node.mathmlTree, node);
        }
        node.childNodes.forEach(this.recurseToTable.bind(this));
        if (node.textContent || node.type === 'punctuated') {
            const newContent = node.contentNodes.map((x) => {
                const newNode = EnrichMathml.cloneContentNode(x);
                if (newNode.hasAttribute('data-semantic-added')) {
                    this.mrows.unshift(newNode);
                }
                else {
                    this.recurseToTable(x);
                }
                return newNode;
            });
            EnrichMathml.setOperatorAttribute(node, newContent);
            return;
        }
        node.contentNodes.forEach(this.recurseToTable.bind(this));
    }
    finalizeTable(node) {
        setAttributes(node.mathmlTree, node);
        node.contentNodes.forEach((x) => {
            EnrichMathml.walkTree(x);
        });
        node.childNodes.forEach((x) => {
            EnrichMathml.walkTree(x);
        });
    }
}
