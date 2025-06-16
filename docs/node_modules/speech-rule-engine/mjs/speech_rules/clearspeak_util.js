import { Span } from '../audio/span.js';
import * as DomUtil from '../common/dom_util.js';
import { Engine } from '../common/engine.js';
import * as XpathUtil from '../common/xpath_util.js';
import { LOCALE } from '../l10n/locale.js';
import { vulgarFractionSmall } from '../l10n/transformers.js';
import { Grammar } from '../rule_engine/grammar.js';
import * as StoreUtil from '../rule_engine/store_util.js';
import { register } from '../semantic_tree/semantic_annotations.js';
import { SemanticAnnotator } from '../semantic_tree/semantic_annotator.js';
import { isMatchingFence } from '../semantic_tree/semantic_attr.js';
import { SemanticRole, SemanticType } from '../semantic_tree/semantic_meaning.js';
export function nodeCounter(nodes, context) {
    const split = context.split('-');
    const func = StoreUtil.nodeCounter(nodes, split[0] || '');
    const sep = split[1] || '';
    const init = split[2] || '';
    let first = true;
    return function () {
        const result = func();
        if (first) {
            first = false;
            return init + result + sep;
        }
        else {
            return result + sep;
        }
    };
}
function isSimpleExpression(node) {
    return (isSimpleNumber_(node) ||
        isSimpleLetters_(node) ||
        isSimpleDegree_(node) ||
        isSimpleNegative_(node) ||
        isSimpleFunction_(node));
}
function isSimpleFunction_(node) {
    return (node.type === SemanticType.APPL &&
        (node.childNodes[0].role === SemanticRole.PREFIXFUNC ||
            node.childNodes[0].role === SemanticRole.SIMPLEFUNC) &&
        (isSimple_(node.childNodes[1]) ||
            (node.childNodes[1].type === SemanticType.FENCED &&
                isSimple_(node.childNodes[1].childNodes[0]))));
}
function isSimpleNegative_(node) {
    return (node.type === SemanticType.PREFIXOP &&
        node.role === SemanticRole.NEGATIVE &&
        isSimple_(node.childNodes[0]) &&
        node.childNodes[0].type !== SemanticType.PREFIXOP &&
        node.childNodes[0].type !== SemanticType.APPL &&
        node.childNodes[0].type !== SemanticType.PUNCTUATED);
}
function isSimpleDegree_(node) {
    return (node.type === SemanticType.PUNCTUATED &&
        node.role === SemanticRole.ENDPUNCT &&
        node.childNodes.length === 2 &&
        node.childNodes[1].role === SemanticRole.DEGREE &&
        (isLetter_(node.childNodes[0]) ||
            isNumber_(node.childNodes[0]) ||
            (node.childNodes[0].type === SemanticType.PREFIXOP &&
                node.childNodes[0].role === SemanticRole.NEGATIVE &&
                (isLetter_(node.childNodes[0].childNodes[0]) ||
                    isNumber_(node.childNodes[0].childNodes[0])))));
}
function isSimpleLetters_(node) {
    return (isLetter_(node) ||
        (node.type === SemanticType.INFIXOP &&
            node.role === SemanticRole.IMPLICIT &&
            ((node.childNodes.length === 2 &&
                (isLetter_(node.childNodes[0]) ||
                    isSimpleNumber_(node.childNodes[0])) &&
                isLetter_(node.childNodes[1])) ||
                (node.childNodes.length === 3 &&
                    isSimpleNumber_(node.childNodes[0]) &&
                    isLetter_(node.childNodes[1]) &&
                    isLetter_(node.childNodes[2])))));
}
function isSimple_(node) {
    return node.hasAnnotation('clearspeak', 'simple');
}
function isLetter_(node) {
    return (node.type === SemanticType.IDENTIFIER &&
        (node.role === SemanticRole.LATINLETTER ||
            node.role === SemanticRole.GREEKLETTER ||
            node.role === SemanticRole.OTHERLETTER ||
            node.role === SemanticRole.SIMPLEFUNC));
}
function isNumber_(node) {
    return (node.type === SemanticType.NUMBER &&
        (node.role === SemanticRole.INTEGER || node.role === SemanticRole.FLOAT));
}
function isSimpleNumber_(node) {
    return isNumber_(node) || isSimpleFraction_(node);
}
function isSimpleFraction_(node) {
    if (hasPreference('Fraction_Over') || hasPreference('Fraction_FracOver')) {
        return false;
    }
    if (node.type !== SemanticType.FRACTION ||
        node.role !== SemanticRole.VULGAR) {
        return false;
    }
    if (hasPreference('Fraction_Ordinal')) {
        return true;
    }
    const enumerator = parseInt(node.childNodes[0].textContent, 10);
    const denominator = parseInt(node.childNodes[1].textContent, 10);
    return (enumerator > 0 && enumerator < 20 && denominator > 0 && denominator < 11);
}
function hasPreference(pref) {
    return Engine.getInstance().style === pref;
}
register(new SemanticAnnotator('clearspeak', 'simple', function (node) {
    return isSimpleExpression(node) ? 'simple' : '';
}));
function simpleNode(node) {
    if (!node.hasAttribute('annotation')) {
        return false;
    }
    const annotation = node.getAttribute('annotation');
    return !!/clearspeak:simple$|clearspeak:simple;/.exec(annotation);
}
function simpleCell_(node) {
    if (simpleNode(node)) {
        return true;
    }
    if (node.tagName !== SemanticType.SUBSCRIPT) {
        return false;
    }
    const children = node.childNodes[0].childNodes;
    const index = children[1];
    return (children[0].tagName === SemanticType.IDENTIFIER &&
        (isInteger_(index) ||
            (index.tagName === SemanticType.INFIXOP &&
                index.hasAttribute('role') &&
                index.getAttribute('role') === SemanticRole.IMPLICIT &&
                allIndices_(index))));
}
function isInteger_(node) {
    return (node.tagName === SemanticType.NUMBER &&
        node.hasAttribute('role') &&
        node.getAttribute('role') === SemanticRole.INTEGER);
}
function allIndices_(node) {
    const nodes = XpathUtil.evalXPath('children/*', node);
    return nodes.every((x) => isInteger_(x) || x.tagName === SemanticType.IDENTIFIER);
}
export function allCellsSimple(node) {
    const xpath = node.tagName === SemanticType.MATRIX
        ? 'children/row/children/cell/children/*'
        : 'children/line/children/*';
    const nodes = XpathUtil.evalXPath(xpath, node);
    const result = nodes.every(simpleCell_);
    return result ? [node] : [];
}
export function isSmallVulgarFraction(node) {
    return vulgarFractionSmall(node, 20, 11) ? [node] : [];
}
function isUnitExpression(node) {
    return ((node.type === SemanticType.TEXT && node.role !== SemanticRole.LABEL) ||
        (node.type === SemanticType.PUNCTUATED &&
            node.role === SemanticRole.TEXT &&
            isNumber_(node.childNodes[0]) &&
            allTextLastContent_(node.childNodes.slice(1))) ||
        (node.type === SemanticType.IDENTIFIER &&
            node.role === SemanticRole.UNIT) ||
        (node.type === SemanticType.INFIXOP &&
            (node.role === SemanticRole.IMPLICIT || node.role === SemanticRole.UNIT)));
}
function allTextLastContent_(nodes) {
    for (let i = 0; i < nodes.length - 1; i++) {
        if (!(nodes[i].type === SemanticType.TEXT && nodes[i].textContent === '')) {
            return false;
        }
    }
    return nodes[nodes.length - 1].type === SemanticType.TEXT;
}
register(new SemanticAnnotator('clearspeak', 'unit', function (node) {
    return isUnitExpression(node) ? 'unit' : '';
}));
export function ordinalExponent(node) {
    const num = parseInt(node.textContent, 10);
    return [
        Span.stringEmpty(isNaN(num)
            ? node.textContent
            : num > 10
                ? LOCALE.NUMBERS.numericOrdinal(num)
                : LOCALE.NUMBERS.wordOrdinal(num))
    ];
}
let NESTING_DEPTH = null;
export function nestingDepth(node) {
    let count = 0;
    const fence = node.textContent;
    const index = node.getAttribute('role') === 'open' ? 0 : 1;
    let parent = node.parentNode;
    while (parent) {
        if (parent.tagName === SemanticType.FENCED &&
            parent.childNodes[0].childNodes[index].textContent === fence) {
            count++;
        }
        parent = parent.parentNode;
    }
    NESTING_DEPTH = count > 1 ? LOCALE.NUMBERS.wordOrdinal(count) : '';
    return [Span.stringEmpty(NESTING_DEPTH)];
}
export function matchingFences(node) {
    const sibling = node.previousSibling;
    let left, right;
    if (sibling) {
        left = sibling;
        right = node;
    }
    else {
        left = node;
        right = node.nextSibling;
    }
    if (!right) {
        return [];
    }
    return isMatchingFence(left.textContent, right.textContent) ? [node] : [];
}
function insertNesting(text, correction) {
    if (!correction || !text) {
        return text;
    }
    const start = text.match(/^(open|close) /);
    if (!start) {
        return correction + ' ' + text;
    }
    return start[0] + correction + ' ' + text.substring(start[0].length);
}
Grammar.getInstance().setCorrection('insertNesting', insertNesting);
export function fencedArguments(node) {
    const content = DomUtil.toArray(node.parentNode.childNodes);
    const children = XpathUtil.evalXPath('../../children/*', node);
    const index = content.indexOf(node);
    return fencedFactor_(children[index]) || fencedFactor_(children[index + 1])
        ? [node]
        : [];
}
export function simpleArguments(node) {
    const content = DomUtil.toArray(node.parentNode.childNodes);
    const children = XpathUtil.evalXPath('../../children/*', node);
    const index = content.indexOf(node);
    return simpleFactor_(children[index]) &&
        children[index + 1] &&
        (simpleFactor_(children[index + 1]) ||
            children[index + 1].tagName === SemanticType.ROOT ||
            children[index + 1].tagName === SemanticType.SQRT ||
            (children[index + 1].tagName === SemanticType.SUPERSCRIPT &&
                children[index + 1].childNodes[0].childNodes[0] &&
                (children[index + 1].childNodes[0].childNodes[0]
                    .tagName === SemanticType.NUMBER ||
                    children[index + 1].childNodes[0].childNodes[0]
                        .tagName === SemanticType.IDENTIFIER) &&
                (children[index + 1].childNodes[0].childNodes[1].textContent === '2' ||
                    children[index + 1].childNodes[0].childNodes[1].textContent === '3')))
        ? [node]
        : [];
}
function simpleFactor_(node) {
    return (!!node &&
        (node.tagName === SemanticType.NUMBER ||
            node.tagName === SemanticType.IDENTIFIER ||
            node.tagName === SemanticType.FUNCTION ||
            node.tagName === SemanticType.APPL ||
            node.tagName === SemanticType.FRACTION));
}
function fencedFactor_(node) {
    return (node &&
        (node.tagName === SemanticType.FENCED ||
            (node.hasAttribute('role') &&
                node.getAttribute('role') === SemanticRole.LEFTRIGHT) ||
            layoutFactor_(node)));
}
function layoutFactor_(node) {
    return (!!node &&
        (node.tagName === SemanticType.MATRIX ||
            node.tagName === SemanticType.VECTOR));
}
export function wordOrdinal(node) {
    return [
        Span.stringEmpty(LOCALE.NUMBERS.wordOrdinal(parseInt(node.textContent, 10)))
    ];
}
