"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.xpath = void 0;
exports.resolveNameSpace = resolveNameSpace;
exports.evalXPath = evalXPath;
exports.evaluateBoolean = evaluateBoolean;
exports.evaluateString = evaluateString;
exports.updateEvaluator = updateEvaluator;
const engine_js_1 = require("./engine.js");
const EngineConst = require("../common/engine_const.js");
const system_external_js_1 = require("./system_external.js");
function xpathSupported() {
    if (typeof XPathResult === 'undefined') {
        return false;
    }
    return true;
}
exports.xpath = {
    currentDocument: null,
    evaluate: xpathSupported()
        ? document.evaluate
        : system_external_js_1.SystemExternal.xpath.evaluate,
    result: xpathSupported() ? XPathResult : system_external_js_1.SystemExternal.xpath.XPathResult,
    createNSResolver: xpathSupported()
        ? document.createNSResolver
        : system_external_js_1.SystemExternal.xpath.createNSResolver
};
const nameSpaces = {
    xhtml: 'http://www.w3.org/1999/xhtml',
    mathml: 'http://www.w3.org/1998/Math/MathML',
    mml: 'http://www.w3.org/1998/Math/MathML',
    svg: 'http://www.w3.org/2000/svg'
};
function resolveNameSpace(prefix) {
    return nameSpaces[prefix] || null;
}
class Resolver {
    constructor() {
        this.lookupNamespaceURI = resolveNameSpace;
    }
}
function evaluateXpath(expression, rootNode, type) {
    return engine_js_1.Engine.getInstance().mode === EngineConst.Mode.HTTP &&
        !engine_js_1.Engine.getInstance().isIE &&
        !engine_js_1.Engine.getInstance().isEdge
        ? exports.xpath.currentDocument.evaluate(expression, rootNode, resolveNameSpace, type, null)
        : exports.xpath.evaluate(expression, rootNode, new Resolver(), type, null);
}
function evalXPath(expression, rootNode) {
    let iterator;
    try {
        iterator = evaluateXpath(expression, rootNode, exports.xpath.result.ORDERED_NODE_ITERATOR_TYPE);
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
function evaluateBoolean(expression, rootNode) {
    let result;
    try {
        result = evaluateXpath(expression, rootNode, exports.xpath.result.BOOLEAN_TYPE);
    }
    catch (_err) {
        return false;
    }
    return result.booleanValue;
}
function evaluateString(expression, rootNode) {
    let result;
    try {
        result = evaluateXpath(expression, rootNode, exports.xpath.result.STRING_TYPE);
    }
    catch (_err) {
        return '';
    }
    return result.stringValue;
}
function updateEvaluator(node) {
    if (engine_js_1.Engine.getInstance().mode !== EngineConst.Mode.HTTP)
        return;
    let parent = node;
    while (parent && !parent.evaluate) {
        parent = parent.parentNode;
    }
    if (parent && parent.evaluate) {
        exports.xpath.currentDocument = parent;
    }
    else if (node.ownerDocument) {
        exports.xpath.currentDocument = node.ownerDocument;
    }
}
