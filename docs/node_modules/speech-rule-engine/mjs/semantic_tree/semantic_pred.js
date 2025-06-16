import { NamedSymbol, SemanticMap } from './semantic_attr.js';
import { SemanticRole, SemanticType, SemanticSecondary } from './semantic_meaning.js';
import { getEmbellishedInner } from './semantic_util.js';
export function isType(node, attr) {
    return node.type === attr;
}
function embellishedType(node, attr) {
    return node.embellished === attr;
}
export function isRole(node, attr) {
    return node.role === attr;
}
export function isAccent(node) {
    return (isType(node, SemanticType.FENCE) ||
        isType(node, SemanticType.PUNCTUATION) ||
        isType(node, SemanticType.OPERATOR) ||
        isType(node, SemanticType.RELATION));
}
export function isSimpleFunctionScope(node) {
    const children = node.childNodes;
    if (children.length === 0) {
        return true;
    }
    if (children.length > 1) {
        return false;
    }
    const child = children[0];
    if (child.type === SemanticType.INFIXOP) {
        if (child.role !== SemanticRole.IMPLICIT) {
            return false;
        }
        if (child.childNodes.some((x) => isType(x, SemanticType.INFIXOP))) {
            return false;
        }
    }
    return true;
}
export function isPrefixFunctionBoundary(node) {
    return ((isOperator(node) && !isRole(node, SemanticRole.DIVISION)) ||
        isType(node, SemanticType.APPL) ||
        isGeneralFunctionBoundary(node));
}
export function isBigOpBoundary(node) {
    return isOperator(node) || isGeneralFunctionBoundary(node);
}
export function isIntegralDxBoundary(firstNode, secondNode) {
    return (!!secondNode &&
        isType(secondNode, SemanticType.IDENTIFIER) &&
        SemanticMap.Secondary.has(firstNode.textContent, SemanticSecondary.D));
}
export function isIntegralDxBoundarySingle(node) {
    if (isType(node, SemanticType.IDENTIFIER)) {
        const firstChar = node.textContent[0];
        return (firstChar &&
            node.textContent[1] &&
            SemanticMap.Secondary.has(firstChar, SemanticSecondary.D));
    }
    return false;
}
export function isGeneralFunctionBoundary(node) {
    return isRelation(node) || isPunctuation(node);
}
export function isEmbellished(node) {
    if (node.embellished) {
        return node.embellished;
    }
    if (isEmbellishedType(node.type)) {
        return node.type;
    }
    return null;
}
function isEmbellishedType(type) {
    return (type === SemanticType.OPERATOR ||
        type === SemanticType.RELATION ||
        type === SemanticType.FENCE ||
        type === SemanticType.PUNCTUATION);
}
export function isOperator(node) {
    return (isType(node, SemanticType.OPERATOR) ||
        embellishedType(node, SemanticType.OPERATOR));
}
export function isRelation(node) {
    return (isType(node, SemanticType.RELATION) ||
        embellishedType(node, SemanticType.RELATION));
}
export function isPunctuation(node) {
    return (isType(node, SemanticType.PUNCTUATION) ||
        embellishedType(node, SemanticType.PUNCTUATION));
}
export function isFence(node) {
    return (isType(node, SemanticType.FENCE) ||
        embellishedType(node, SemanticType.FENCE));
}
export function isElligibleEmbellishedFence(node) {
    if (!node || !isFence(node)) {
        return false;
    }
    if (!node.embellished) {
        return true;
    }
    return recurseBaseNode(node);
}
function bothSide(node) {
    return (isType(node, SemanticType.TENSOR) &&
        (!isType(node.childNodes[1], SemanticType.EMPTY) ||
            !isType(node.childNodes[2], SemanticType.EMPTY)) &&
        (!isType(node.childNodes[3], SemanticType.EMPTY) ||
            !isType(node.childNodes[4], SemanticType.EMPTY)));
}
function recurseBaseNode(node) {
    if (!node.embellished) {
        return true;
    }
    if (bothSide(node)) {
        return false;
    }
    if (isRole(node, SemanticRole.CLOSE) && isType(node, SemanticType.TENSOR)) {
        return false;
    }
    if (isRole(node, SemanticRole.OPEN) &&
        (isType(node, SemanticType.SUBSCRIPT) ||
            isType(node, SemanticType.SUPERSCRIPT))) {
        return false;
    }
    return recurseBaseNode(node.childNodes[0]);
}
export function isTableOrMultiline(node) {
    return (!!node &&
        (isType(node, SemanticType.TABLE) || isType(node, SemanticType.MULTILINE)));
}
export function tableIsMatrixOrVector(node) {
    return (!!node && isFencedElement(node) && isTableOrMultiline(node.childNodes[0]));
}
export function isFencedElement(node) {
    return (!!node &&
        isType(node, SemanticType.FENCED) &&
        (isRole(node, SemanticRole.LEFTRIGHT) || isNeutralFence(node)) &&
        node.childNodes.length === 1);
}
export function tableIsCases(_table, prevNodes) {
    return (prevNodes.length > 0 &&
        isRole(prevNodes[prevNodes.length - 1], SemanticRole.OPENFENCE));
}
export function tableIsMultiline(table) {
    return table.childNodes.every(function (row) {
        const length = row.childNodes.length;
        return length <= 1;
    });
}
export function lineIsLabelled(line) {
    return (isType(line, SemanticType.LINE) &&
        line.contentNodes.length &&
        isRole(line.contentNodes[0], SemanticRole.LABEL));
}
export function isBinomial(table) {
    return table.childNodes.length === 2;
}
export function isLimitBase(node) {
    return (isType(node, SemanticType.LARGEOP) ||
        isType(node, SemanticType.LIMBOTH) ||
        isType(node, SemanticType.LIMLOWER) ||
        isType(node, SemanticType.LIMUPPER) ||
        (isType(node, SemanticType.FUNCTION) &&
            isRole(node, SemanticRole.LIMFUNC)) ||
        ((isType(node, SemanticType.OVERSCORE) ||
            isType(node, SemanticType.UNDERSCORE)) &&
            isLimitBase(node.childNodes[0])));
}
export function isSimpleFunctionHead(node) {
    return (node.type === SemanticType.IDENTIFIER ||
        node.role === SemanticRole.LATINLETTER ||
        node.role === SemanticRole.GREEKLETTER ||
        node.role === SemanticRole.OTHERLETTER);
}
export function singlePunctAtPosition(nodes, puncts, position) {
    return (puncts.length === 1 &&
        (nodes[position].type === SemanticType.PUNCTUATION ||
            nodes[position].embellished === SemanticType.PUNCTUATION) &&
        nodes[position] === puncts[0]);
}
export function isSimpleFunction(node) {
    return (isType(node, SemanticType.IDENTIFIER) &&
        isRole(node, SemanticRole.SIMPLEFUNC));
}
function isLeftBrace(node) {
    const leftBrace = ['{', '﹛', '｛'];
    return !!node && leftBrace.indexOf(node.textContent) !== -1;
}
function isRightBrace(node) {
    const rightBrace = ['}', '﹜', '｝'];
    return !!node && rightBrace.indexOf(node.textContent) !== -1;
}
export function isSetNode(node) {
    return (isLeftBrace(node.contentNodes[0]) && isRightBrace(node.contentNodes[1]));
}
const illegalSingleton = [
    SemanticType.PUNCTUATION,
    SemanticType.PUNCTUATED,
    SemanticType.RELSEQ,
    SemanticType.MULTIREL,
    SemanticType.TABLE,
    SemanticType.MULTILINE,
    SemanticType.CASES,
    SemanticType.INFERENCE
];
const scriptedElement = [
    SemanticType.LIMUPPER,
    SemanticType.LIMLOWER,
    SemanticType.LIMBOTH,
    SemanticType.SUBSCRIPT,
    SemanticType.SUPERSCRIPT,
    SemanticType.UNDERSCORE,
    SemanticType.OVERSCORE,
    SemanticType.TENSOR
];
export function isSingletonSetContent(node) {
    const type = node.type;
    if (illegalSingleton.indexOf(type) !== -1 ||
        (type === SemanticType.INFIXOP && node.role !== SemanticRole.IMPLICIT)) {
        return false;
    }
    if (type === SemanticType.FENCED) {
        return node.role === SemanticRole.LEFTRIGHT
            ? isSingletonSetContent(node.childNodes[0])
            : true;
    }
    if (scriptedElement.indexOf(type) !== -1) {
        return isSingletonSetContent(node.childNodes[0]);
    }
    return true;
}
function isNumber(node) {
    return (node.type === SemanticType.NUMBER &&
        (node.role === SemanticRole.INTEGER || node.role === SemanticRole.FLOAT));
}
export function isUnitCounter(node) {
    return (isNumber(node) ||
        node.role === SemanticRole.VULGAR ||
        node.role === SemanticRole.MIXED);
}
export function isPureUnit(node) {
    const children = node.childNodes;
    return (node.role === SemanticRole.UNIT &&
        (!children.length || children[0].role === SemanticRole.UNIT));
}
export function isUnitProduct(node) {
    const children = node.childNodes;
    return (node.type === SemanticType.INFIXOP &&
        (node.role === SemanticRole.MULTIPLICATION ||
            node.role === SemanticRole.IMPLICIT) &&
        children.length &&
        (isPureUnit(children[0]) || isUnitCounter(children[0])) &&
        node.childNodes.slice(1).every(isPureUnit));
}
export function isImplicit(node) {
    return (node.type === SemanticType.INFIXOP &&
        (node.role === SemanticRole.IMPLICIT ||
            (node.role === SemanticRole.UNIT &&
                !!node.contentNodes.length &&
                node.contentNodes[0].textContent === NamedSymbol.invisibleTimes)));
}
export function isImplicitOp(node) {
    return (node.type === SemanticType.INFIXOP && node.role === SemanticRole.IMPLICIT);
}
export function isNeutralFence(fence) {
    return (fence.role === SemanticRole.NEUTRAL || fence.role === SemanticRole.METRIC);
}
export function compareNeutralFences(fence1, fence2) {
    return (isNeutralFence(fence1) &&
        isNeutralFence(fence2) &&
        getEmbellishedInner(fence1).textContent ===
            getEmbellishedInner(fence2).textContent);
}
export function elligibleLeftNeutral(fence) {
    if (!isNeutralFence(fence)) {
        return false;
    }
    if (!fence.embellished) {
        return true;
    }
    if (fence.type === SemanticType.SUPERSCRIPT ||
        fence.type === SemanticType.SUBSCRIPT) {
        return false;
    }
    if (fence.type === SemanticType.TENSOR &&
        (fence.childNodes[3].type !== SemanticType.EMPTY ||
            fence.childNodes[4].type !== SemanticType.EMPTY)) {
        return false;
    }
    return true;
}
export function elligibleRightNeutral(fence) {
    if (!isNeutralFence(fence)) {
        return false;
    }
    if (!fence.embellished) {
        return true;
    }
    if (fence.type === SemanticType.TENSOR &&
        (fence.childNodes[1].type !== SemanticType.EMPTY ||
            fence.childNodes[2].type !== SemanticType.EMPTY)) {
        return false;
    }
    return true;
}
export function isMembership(element) {
    return [
        SemanticRole.ELEMENT,
        SemanticRole.NONELEMENT,
        SemanticRole.REELEMENT,
        SemanticRole.RENONELEMENT
    ].includes(element.role);
}
