import { Engine } from './engine.js';
import * as EngineConst from '../common/engine_const.js';
import { SystemExternal } from './system_external.js';
function xpathSupported() {
    if (typeof XPathResult === 'undefined') {
        return false;
    }
    return true;
}
export const xpath = {
    currentDocument: null,
    evaluate: xpathSupported()
        ? document.evaluate
        : SystemExternal.xpath.evaluate,
    result: xpathSupported() ? XPathResult : SystemExternal.xpath.XPathResult,
    createNSResolver: xpathSupported()
        ? document.createNSResolver
        : SystemExternal.xpath.createNSResolver
};
const nameSpaces = {
    xhtml: 'http://www.w3.org/1999/xhtml',
    mathml: 'http://www.w3.org/1998/Math/MathML',
    mml: 'http://www.w3.org/1998/Math/MathML',
    svg: 'http://www.w3.org/2000/svg'
};
export function resolveNameSpace(prefix) {
    return nameSpaces[prefix] || null;
}
class Resolver {
    constructor() {
        this.lookupNamespaceURI = resolveNameSpace;
    }
}
function evaluateXpath(expression, rootNode, type) {
    return Engine.getInstance().mode === EngineConst.Mode.HTTP &&
        !Engine.getInstance().isIE &&
        !Engine.getInstance().isEdge
        ? xpath.currentDocument.evaluate(expression, rootNode, resolveNameSpace, type, null)
        : xpath.evaluate(expression, rootNode, new Resolver(), type, null);
}
export function evalXPath(expression, rootNode) {
    let iterator;
    try {
        iterator = evaluateXpath(expression, rootNode, xpath.result.ORDERED_NODE_ITERATOR_TYPE);
    }
    catch (_err) {
        return [];
    }
    const results = [];
    for (let xpathNode = iterator.iterateNext(); xpathNode; xpathNode = iterator.iterateNext()) {
        results.push(xpathNode);
    }
    return results;
}
export function evaluateBoolean(expression, rootNode) {
    let result;
    try {
        result = evaluateXpath(expression, rootNode, xpath.result.BOOLEAN_TYPE);
    }
    catch (_err) {
        return false;
    }
    return result.booleanValue;
}
export function evaluateString(expression, rootNode) {
    let result;
    try {
        result = evaluateXpath(expression, rootNode, xpath.result.STRING_TYPE);
    }
    catch (_err) {
        return '';
    }
    return result.stringValue;
}
export function updateEvaluator(node) {
    if (Engine.getInstance().mode !== EngineConst.Mode.HTTP)
        return;
    let parent = node;
    while (parent && !parent.evaluate) {
        parent = parent.parentNode;
    }
    if (parent && parent.evaluate) {
        xpath.currentDocument = parent;
    }
    else if (node.ownerDocument) {
        xpath.currentDocument = node.ownerDocument;
    }
}
