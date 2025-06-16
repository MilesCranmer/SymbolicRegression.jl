"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.isType = isType;
exports.isRole = isRole;
exports.isAccent = isAccent;
exports.isSimpleFunctionScope = isSimpleFunctionScope;
exports.isPrefixFunctionBoundary = isPrefixFunctionBoundary;
exports.isBigOpBoundary = isBigOpBoundary;
exports.isIntegralDxBoundary = isIntegralDxBoundary;
exports.isIntegralDxBoundarySingle = isIntegralDxBoundarySingle;
exports.isGeneralFunctionBoundary = isGeneralFunctionBoundary;
exports.isEmbellished = isEmbellished;
exports.isOperator = isOperator;
exports.isRelation = isRelation;
exports.isPunctuation = isPunctuation;
exports.isFence = isFence;
exports.isElligibleEmbellishedFence = isElligibleEmbellishedFence;
exports.isTableOrMultiline = isTableOrMultiline;
exports.tableIsMatrixOrVector = tableIsMatrixOrVector;
exports.isFencedElement = isFencedElement;
exports.tableIsCases = tableIsCases;
exports.tableIsMultiline = tableIsMultiline;
exports.lineIsLabelled = lineIsLabelled;
exports.isBinomial = isBinomial;
exports.isLimitBase = isLimitBase;
exports.isSimpleFunctionHead = isSimpleFunctionHead;
exports.singlePunctAtPosition = singlePunctAtPosition;
exports.isSimpleFunction = isSimpleFunction;
exports.isSetNode = isSetNode;
exports.isSingletonSetContent = isSingletonSetContent;
exports.isUnitCounter = isUnitCounter;
exports.isPureUnit = isPureUnit;
exports.isUnitProduct = isUnitProduct;
exports.isImplicit = isImplicit;
exports.isImplicitOp = isImplicitOp;
exports.isNeutralFence = isNeutralFence;
exports.compareNeutralFences = compareNeutralFences;
exports.elligibleLeftNeutral = elligibleLeftNeutral;
exports.elligibleRightNeutral = elligibleRightNeutral;
exports.isMembership = isMembership;
const semantic_attr_js_1 = require("./semantic_attr.js");
const semantic_meaning_js_1 = require("./semantic_meaning.js");
const semantic_util_js_1 = require("./semantic_util.js");
function isType(node, attr) {
    return node.type === attr;
}
function embellishedType(node, attr) {
    return node.embellished === attr;
}
function isRole(node, attr) {
    return node.role === attr;
}
function isAccent(node) {
    return (isType(node, semantic_meaning_js_1.SemanticType.FENCE) ||
        isType(node, semantic_meaning_js_1.SemanticType.PUNCTUATION) ||
        isType(node, semantic_meaning_js_1.SemanticType.OPERATOR) ||
        isType(node, semantic_meaning_js_1.SemanticType.RELATION));
}
function isSimpleFunctionScope(node) {
    const children = node.childNodes;
    if (children.length === 0) {
        return true;
    }
    if (children.length > 1) {
        return false;
    }
    const child = children[0];
    if (child.type === semantic_meaning_js_1.SemanticType.INFIXOP) {
        if (child.role !== semantic_meaning_js_1.SemanticRole.IMPLICIT) {
            return false;
        }
        if (child.childNodes.some((x) => isType(x, semantic_meaning_js_1.SemanticType.INFIXOP))) {
            return false;
        }
    }
    return true;
}
function isPrefixFunctionBoundary(node) {
    return ((isOperator(node) && !isRole(node, semantic_meaning_js_1.SemanticRole.DIVISION)) ||
        isType(node, semantic_meaning_js_1.SemanticType.APPL) ||
        isGeneralFunctionBoundary(node));
}
function isBigOpBoundary(node) {
    return isOperator(node) || isGeneralFunctionBoundary(node);
}
function isIntegralDxBoundary(firstNode, secondNode) {
    return (!!secondNode &&
        isType(secondNode, semantic_meaning_js_1.SemanticType.IDENTIFIER) &&
        semantic_attr_js_1.SemanticMap.Secondary.has(firstNode.textContent, semantic_meaning_js_1.SemanticSecondary.D));
}
function isIntegralDxBoundarySingle(node) {
    if (isType(node, semantic_meaning_js_1.SemanticType.IDENTIFIER)) {
        const firstChar = node.textContent[0];
        return (firstChar &&
            node.textContent[1] &&
            semantic_attr_js_1.SemanticMap.Secondary.has(firstChar, semantic_meaning_js_1.SemanticSecondary.D));
    }
    return false;
}
function isGeneralFunctionBoundary(node) {
    return isRelation(node) || isPunctuation(node);
}
function isEmbellished(node) {
    if (node.embellished) {
        return node.embellished;
    }
    if (isEmbellishedType(node.type)) {
        return node.type;
    }
    return null;
}
function isEmbellishedType(type) {
    return (type === semantic_meaning_js_1.SemanticType.OPERATOR ||
        type === semantic_meaning_js_1.SemanticType.RELATION ||
        type === semantic_meaning_js_1.SemanticType.FENCE ||
        type === semantic_meaning_js_1.SemanticType.PUNCTUATION);
}
function isOperator(node) {
    return (isType(node, semantic_meaning_js_1.SemanticType.OPERATOR) ||
        embellishedType(node, semantic_meaning_js_1.SemanticType.OPERATOR));
}
function isRelation(node) {
    return (isType(node, semantic_meaning_js_1.SemanticType.RELATION) ||
        embellishedType(node, semantic_meaning_js_1.SemanticType.RELATION));
}
function isPunctuation(node) {
    return (isType(node, semantic_meaning_js_1.SemanticType.PUNCTUATION) ||
        embellishedType(node, semantic_meaning_js_1.SemanticType.PUNCTUATION));
}
function isFence(node) {
    return (isType(node, semantic_meaning_js_1.SemanticType.FENCE) ||
        embellishedType(node, semantic_meaning_js_1.SemanticType.FENCE));
}
function isElligibleEmbellishedFence(node) {
    if (!node || !isFence(node)) {
        return false;
    }
    if (!node.embellished) {
        return true;
    }
    return recurseBaseNode(node);
}
function bothSide(node) {
    return (isType(node, semantic_meaning_js_1.SemanticType.TENSOR) &&
        (!isType(node.childNodes[1], semantic_meaning_js_1.SemanticType.EMPTY) ||
            !isType(node.childNodes[2], semantic_meaning_js_1.SemanticType.EMPTY)) &&
        (!isType(node.childNodes[3], semantic_meaning_js_1.SemanticType.EMPTY) ||
            !isType(node.childNodes[4], semantic_meaning_js_1.SemanticType.EMPTY)));
}
function recurseBaseNode(node) {
    if (!node.embellished) {
        return true;
    }
    if (bothSide(node)) {
        return false;
    }
    if (isRole(node, semantic_meaning_js_1.SemanticRole.CLOSE) && isType(node, semantic_meaning_js_1.SemanticType.TENSOR)) {
        return false;
    }
    if (isRole(node, semantic_meaning_js_1.SemanticRole.OPEN) &&
        (isType(node, semantic_meaning_js_1.SemanticType.SUBSCRIPT) ||
            isType(node, semantic_meaning_js_1.SemanticType.SUPERSCRIPT))) {
        return false;
    }
    return recurseBaseNode(node.childNodes[0]);
}
function isTableOrMultiline(node) {
    return (!!node &&
        (isType(node, semantic_meaning_js_1.SemanticType.TABLE) || isType(node, semantic_meaning_js_1.SemanticType.MULTILINE)));
}
function tableIsMatrixOrVector(node) {
    return (!!node && isFencedElement(node) && isTableOrMultiline(node.childNodes[0]));
}
function isFencedElement(node) {
    return (!!node &&
        isType(node, semantic_meaning_js_1.SemanticType.FENCED) &&
        (isRole(node, semantic_meaning_js_1.SemanticRole.LEFTRIGHT) || isNeutralFence(node)) &&
        node.childNodes.length === 1);
}
function tableIsCases(_table, prevNodes) {
    return (prevNodes.length > 0 &&
        isRole(prevNodes[prevNodes.length - 1], semantic_meaning_js_1.SemanticRole.OPENFENCE));
}
function tableIsMultiline(table) {
    return table.childNodes.every(function (row) {
        const length = row.childNodes.length;
        return length <= 1;
    });
}
function lineIsLabelled(line) {
    return (isType(line, semantic_meaning_js_1.SemanticType.LINE) &&
        line.contentNodes.length &&
        isRole(line.contentNodes[0], semantic_meaning_js_1.SemanticRole.LABEL));
}
function isBinomial(table) {
    return table.childNodes.length === 2;
}
function isLimitBase(node) {
    return (isType(node, semantic_meaning_js_1.SemanticType.LARGEOP) ||
        isType(node, semantic_meaning_js_1.SemanticType.LIMBOTH) ||
        isType(node, semantic_meaning_js_1.SemanticType.LIMLOWER) ||
        isType(node, semantic_meaning_js_1.SemanticType.LIMUPPER) ||
        (isType(node, semantic_meaning_js_1.SemanticType.FUNCTION) &&
            isRole(node, semantic_meaning_js_1.SemanticRole.LIMFUNC)) ||
        ((isType(node, semantic_meaning_js_1.SemanticType.OVERSCORE) ||
            isType(node, semantic_meaning_js_1.SemanticType.UNDERSCORE)) &&
            isLimitBase(node.childNodes[0])));
}
function isSimpleFunctionHead(node) {
    return (node.type === semantic_meaning_js_1.SemanticType.IDENTIFIER ||
        node.role === semantic_meaning_js_1.SemanticRole.LATINLETTER ||
        node.role === semantic_meaning_js_1.SemanticRole.GREEKLETTER ||
        node.role === semantic_meaning_js_1.SemanticRole.OTHERLETTER);
}
function singlePunctAtPosition(nodes, puncts, position) {
    return (puncts.length === 1 &&
        (nodes[position].type === semantic_meaning_js_1.SemanticType.PUNCTUATION ||
            nodes[position].embellished === semantic_meaning_js_1.SemanticType.PUNCTUATION) &&
        nodes[position] === puncts[0]);
}
function isSimpleFunction(node) {
    return (isType(node, semantic_meaning_js_1.SemanticType.IDENTIFIER) &&
        isRole(node, semantic_meaning_js_1.SemanticRole.SIMPLEFUNC));
}
function isLeftBrace(node) {
    const leftBrace = ['{', '﹛', '｛'];
    return !!node && leftBrace.indexOf(node.textContent) !== -1;
}
function isRightBrace(node) {
    const rightBrace = ['}', '﹜', '｝'];
    return !!node && rightBrace.indexOf(node.textContent) !== -1;
}
function isSetNode(node) {
    return (isLeftBrace(node.contentNodes[0]) && isRightBrace(node.contentNodes[1]));
}
const illegalSingleton = [
    semantic_meaning_js_1.SemanticType.PUNCTUATION,
    semantic_meaning_js_1.SemanticType.PUNCTUATED,
    semantic_meaning_js_1.SemanticType.RELSEQ,
    semantic_meaning_js_1.SemanticType.MULTIREL,
    semantic_meaning_js_1.SemanticType.TABLE,
    semantic_meaning_js_1.SemanticType.MULTILINE,
    semantic_meaning_js_1.SemanticType.CASES,
    semantic_meaning_js_1.SemanticType.INFERENCE
];
const scriptedElement = [
    semantic_meaning_js_1.SemanticType.LIMUPPER,
    semantic_meaning_js_1.SemanticType.LIMLOWER,
    semantic_meaning_js_1.SemanticType.LIMBOTH,
    semantic_meaning_js_1.SemanticType.SUBSCRIPT,
    semantic_meaning_js_1.SemanticType.SUPERSCRIPT,
    semantic_meaning_js_1.SemanticType.UNDERSCORE,
    semantic_meaning_js_1.SemanticType.OVERSCORE,
    semantic_meaning_js_1.SemanticType.TENSOR
];
function isSingletonSetContent(node) {
    const type = node.type;
    if (illegalSingleton.indexOf(type) !== -1 ||
        (type === semantic_meaning_js_1.SemanticType.INFIXOP && node.role !== semantic_meaning_js_1.SemanticRole.IMPLICIT)) {
        return false;
    }
    if (type === semantic_meaning_js_1.SemanticType.FENCED) {
        return node.role === semantic_meaning_js_1.SemanticRole.LEFTRIGHT
            ? isSingletonSetContent(node.childNodes[0])
            : true;
    }
    if (scriptedElement.indexOf(type) !== -1) {
        return isSingletonSetContent(node.childNodes[0]);
    }
    return true;
}
function isNumber(node) {
    return (node.type === semantic_meaning_js_1.SemanticType.NUMBER &&
        (node.role === semantic_meaning_js_1.SemanticRole.INTEGER || node.role === semantic_meaning_js_1.SemanticRole.FLOAT));
}
function isUnitCounter(node) {
    return (isNumber(node) ||
        node.role === semantic_meaning_js_1.SemanticRole.VULGAR ||
        node.role === semantic_meaning_js_1.SemanticRole.MIXED);
}
function isPureUnit(node) {
    const children = node.childNodes;
    return (node.role === semantic_meaning_js_1.SemanticRole.UNIT &&
        (!children.length || children[0].role === semantic_meaning_js_1.SemanticRole.UNIT));
}
function isUnitProduct(node) {
    const children = node.childNodes;
    return (node.type === semantic_meaning_js_1.SemanticType.INFIXOP &&
        (node.role === semantic_meaning_js_1.SemanticRole.MULTIPLICATION ||
            node.role === semantic_meaning_js_1.SemanticRole.IMPLICIT) &&
        children.length &&
        (isPureUnit(children[0]) || isUnitCounter(children[0])) &&
        node.childNodes.slice(1).every(isPureUnit));
}
function isImplicit(node) {
    return (node.type === semantic_meaning_js_1.SemanticType.INFIXOP &&
        (node.role === semantic_meaning_js_1.SemanticRole.IMPLICIT ||
            (node.role === semantic_meaning_js_1.SemanticRole.UNIT &&
                !!node.contentNodes.length &&
                node.contentNodes[0].textContent === semantic_attr_js_1.NamedSymbol.invisibleTimes)));
}
function isImplicitOp(node) {
    return (node.type === semantic_meaning_js_1.SemanticType.INFIXOP && node.role === semantic_meaning_js_1.SemanticRole.IMPLICIT);
}
function isNeutralFence(fence) {
    return (fence.role === semantic_meaning_js_1.SemanticRole.NEUTRAL || fence.role === semantic_meaning_js_1.SemanticRole.METRIC);
}
function compareNeutralFences(fence1, fence2) {
    return (isNeutralFence(fence1) &&
        isNeutralFence(fence2) &&
        (0, semantic_util_js_1.getEmbellishedInner)(fence1).textContent ===
            (0, semantic_util_js_1.getEmbellishedInner)(fence2).textContent);
}
function elligibleLeftNeutral(fence) {
    if (!isNeutralFence(fence)) {
        return false;
    }
    if (!fence.embellished) {
        return true;
    }
    if (fence.type === semantic_meaning_js_1.SemanticType.SUPERSCRIPT ||
        fence.type === semantic_meaning_js_1.SemanticType.SUBSCRIPT) {
        return false;
    }
    if (fence.type === semantic_meaning_js_1.SemanticType.TENSOR &&
        (fence.childNodes[3].type !== semantic_meaning_js_1.SemanticType.EMPTY ||
            fence.childNodes[4].type !== semantic_meaning_js_1.SemanticType.EMPTY)) {
        return false;
    }
    return true;
}
function elligibleRightNeutral(fence) {
    if (!isNeutralFence(fence)) {
        return false;
    }
    if (!fence.embellished) {
        return true;
    }
    if (fence.type === semantic_meaning_js_1.SemanticType.TENSOR &&
        (fence.childNodes[1].type !== semantic_meaning_js_1.SemanticType.EMPTY ||
            fence.childNodes[2].type !== semantic_meaning_js_1.SemanticType.EMPTY)) {
        return false;
    }
    return true;
}
function isMembership(element) {
    return [
        semantic_meaning_js_1.SemanticRole.ELEMENT,
        semantic_meaning_js_1.SemanticRole.NONELEMENT,
        semantic_meaning_js_1.SemanticRole.REELEMENT,
        semantic_meaning_js_1.SemanticRole.RENONELEMENT
    ].includes(element.role);
}
