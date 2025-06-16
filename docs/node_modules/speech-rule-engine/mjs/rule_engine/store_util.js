import { AuditoryDescription } from '../audio/auditory_description.js';
import * as XpathUtil from '../common/xpath_util.js';
import { Engine } from '../common/engine.js';
export function nodeCounter(nodes, context) {
    const localLength = nodes.length;
    let localCounter = 0;
    let localContext = context;
    if (!context) {
        localContext = '';
    }
    return function () {
        if (localCounter < localLength) {
            localCounter += 1;
        }
        return localContext + ' ' + localCounter;
    };
}
export function pauseSeparator(_nodes, context) {
    const numeral = parseFloat(context);
    const value = isNaN(numeral) ? context : numeral;
    return function () {
        return [
            AuditoryDescription.create({
                text: '',
                personality: { pause: value }
            })
        ];
    };
}
export function contentIterator(nodes, context) {
    let contentNodes;
    if (nodes.length > 0) {
        contentNodes = XpathUtil.evalXPath('../../content/*', nodes[0]);
    }
    else {
        contentNodes = [];
    }
    return function () {
        const content = contentNodes.shift();
        const contextDescr = context
            ? [AuditoryDescription.create({ text: context }, { translate: true })]
            : [];
        if (!content) {
            return contextDescr;
        }
        const descrs = Engine.evaluateNode(content);
        return contextDescr.concat(descrs);
    };
}
