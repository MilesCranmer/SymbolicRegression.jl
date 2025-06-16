"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.nodeCounter = nodeCounter;
exports.pauseSeparator = pauseSeparator;
exports.contentIterator = contentIterator;
const auditory_description_js_1 = require("../audio/auditory_description.js");
const XpathUtil = require("../common/xpath_util.js");
const engine_js_1 = require("../common/engine.js");
function nodeCounter(nodes, context) {
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
function pauseSeparator(_nodes, context) {
    const numeral = parseFloat(context);
    const value = isNaN(numeral) ? context : numeral;
    return function () {
        return [
            auditory_description_js_1.AuditoryDescription.create({
                text: '',
                personality: { pause: value }
            })
        ];
    };
}
function contentIterator(nodes, context) {
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
            ? [auditory_description_js_1.AuditoryDescription.create({ text: context }, { translate: true })]
            : [];
        if (!content) {
            return contextDescr;
        }
        const descrs = engine_js_1.Engine.evaluateNode(content);
        return contextDescr.concat(descrs);
    };
}
