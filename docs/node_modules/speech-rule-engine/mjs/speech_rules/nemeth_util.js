import { AuditoryDescription } from '../audio/auditory_description.js';
import { Span } from '../audio/span.js';
import * as DomUtil from '../common/dom_util.js';
import * as XpathUtil from '../common/xpath_util.js';
import { Grammar, correctFont } from '../rule_engine/grammar.js';
import { Engine } from '../common/engine.js';
import { register, activate } from '../semantic_tree/semantic_annotations.js';
import { SemanticVisitor } from '../semantic_tree/semantic_annotator.js';
import { SemanticRole, SemanticType } from '../semantic_tree/semantic_meaning.js';
import { LOCALE } from '../l10n/locale.js';
import * as MathspeakUtil from './mathspeak_util.js';
import { contentIterator as suCI } from '../rule_engine/store_util.js';
export function openingFraction(node) {
    const depth = MathspeakUtil.fractionNestingDepth(node);
    return Span.singleton(new Array(depth).join(LOCALE.MESSAGES.MS.FRACTION_REPEAT) +
        LOCALE.MESSAGES.MS.FRACTION_START);
}
export function closingFraction(node) {
    const depth = MathspeakUtil.fractionNestingDepth(node);
    return Span.singleton(new Array(depth).join(LOCALE.MESSAGES.MS.FRACTION_REPEAT) +
        LOCALE.MESSAGES.MS.FRACTION_END);
}
export function overFraction(node) {
    const depth = MathspeakUtil.fractionNestingDepth(node);
    return Span.singleton(new Array(depth).join(LOCALE.MESSAGES.MS.FRACTION_REPEAT) +
        LOCALE.MESSAGES.MS.FRACTION_OVER);
}
export function overBevelledFraction(node) {
    const depth = MathspeakUtil.fractionNestingDepth(node);
    return Span.singleton(new Array(depth).join(LOCALE.MESSAGES.MS.FRACTION_REPEAT) +
        '⠸' +
        LOCALE.MESSAGES.MS.FRACTION_OVER);
}
export function hyperFractionBoundary(node) {
    return LOCALE.MESSAGES.regexp.HYPER ===
        MathspeakUtil.fractionNestingDepth(node).toString()
        ? [node]
        : [];
}
function nestedRadical(node, postfix) {
    const depth = radicalNestingDepth(node);
    return Span.singleton(depth === 1
        ? postfix
        : new Array(depth).join(LOCALE.MESSAGES.MS.NESTED) + postfix);
}
function radicalNestingDepth(node, opt_depth) {
    const depth = opt_depth || 0;
    if (!node.parentNode) {
        return depth;
    }
    return radicalNestingDepth(node.parentNode, node.tagName === 'root' || node.tagName === 'sqrt' ? depth + 1 : depth);
}
export function openingRadical(node) {
    return nestedRadical(node, LOCALE.MESSAGES.MS.STARTROOT);
}
export function closingRadical(node) {
    return nestedRadical(node, LOCALE.MESSAGES.MS.ENDROOT);
}
export function indexRadical(node) {
    return nestedRadical(node, LOCALE.MESSAGES.MS.ROOTINDEX);
}
function enlargeFence(text) {
    const start = '⠠';
    if (text.length === 1) {
        return start + text;
    }
    const neut = '⠳';
    const split = text.split('');
    if (split.every(function (x) {
        return x === neut;
    })) {
        return start + split.join(start);
    }
    return text.slice(0, -1) + start + text.slice(-1);
}
Grammar.getInstance().setCorrection('enlargeFence', enlargeFence);
const NUMBER_PROPAGATORS = [
    SemanticType.MULTIREL,
    SemanticType.RELSEQ,
    SemanticType.APPL,
    SemanticType.ROW,
    SemanticType.LINE
];
const NUMBER_INHIBITORS = [
    SemanticType.SUBSCRIPT,
    SemanticType.SUPERSCRIPT,
    SemanticType.OVERSCORE,
    SemanticType.UNDERSCORE
];
function checkParent(node, info) {
    const parent = node.parent;
    if (!parent) {
        return false;
    }
    const type = parent.type;
    if (NUMBER_PROPAGATORS.indexOf(type) !== -1 ||
        (type === SemanticType.PREFIXOP &&
            parent.role === SemanticRole.NEGATIVE &&
            !info.script &&
            !info.enclosed) ||
        (type === SemanticType.PREFIXOP &&
            parent.role === SemanticRole.GEOMETRY)) {
        return true;
    }
    if (type === SemanticType.PUNCTUATED) {
        if (!info.enclosed || parent.role === SemanticRole.TEXT) {
            return true;
        }
    }
    return false;
}
function propagateNumber(node, info) {
    if (!node.childNodes.length) {
        if (checkParent(node, info)) {
            info.number = true;
            info.script = false;
            info.enclosed = false;
        }
        return [
            info['number'] ? 'number' : '',
            { number: false, enclosed: info.enclosed, script: info.script }
        ];
    }
    if (NUMBER_INHIBITORS.indexOf(node.type) !== -1) {
        info.script = true;
    }
    if (node.type === SemanticType.FENCED) {
        info.number = false;
        info.enclosed = true;
        return ['', info];
    }
    if (node.type === SemanticType.PREFIXOP &&
        node.role !== SemanticRole.GEOMETRY &&
        node.role !== SemanticRole.NEGATIVE) {
        info.number = false;
        return ['', info];
    }
    if (checkParent(node, info)) {
        info.number = true;
        info.enclosed = false;
    }
    return ['', info];
}
register(new SemanticVisitor('nemeth', 'number', propagateNumber, { number: true }));
function annotateDepth(node) {
    if (!node.parent) {
        return [1];
    }
    const depth = parseInt(node.parent.annotation['depth'][0]);
    return [depth + 1];
}
register(new SemanticVisitor('depth', 'depth', annotateDepth));
activate('depth', 'depth');
export function relationIterator(nodes, context) {
    var _a;
    const childNodes = nodes.slice(0);
    let first = true;
    const parentNode = nodes[0].parentNode.parentNode;
    const match = (_a = parentNode.getAttribute('annotation')) === null || _a === void 0 ? void 0 : _a.match(/depth:(\d+)/);
    const depth = match ? match[1] : '';
    let contentNodes;
    if (nodes.length > 0) {
        contentNodes = XpathUtil.evalXPath('./content/*', parentNode);
    }
    else {
        contentNodes = [];
    }
    return function () {
        const content = contentNodes.shift();
        const leftChild = childNodes.shift();
        const rightChild = childNodes[0];
        const contextDescr = context
            ? [AuditoryDescription.create({ text: context }, { translate: true })]
            : [];
        if (!content) {
            return contextDescr;
        }
        const base = leftChild
            ? MathspeakUtil.nestedSubSuper(leftChild, '', {
                sup: LOCALE.MESSAGES.MS.SUPER,
                sub: LOCALE.MESSAGES.MS.SUB
            })
            : '';
        const left = (leftChild && DomUtil.tagName(leftChild) !== 'EMPTY') ||
            (first && parentNode && parentNode.previousSibling)
            ? [
                AuditoryDescription.create({ text: LOCALE.MESSAGES.regexp.SPACE + base }, {})
            ]
            : [];
        const right = (rightChild && DomUtil.tagName(rightChild) !== 'EMPTY') ||
            (!contentNodes.length && parentNode && parentNode.nextSibling)
            ? [
                AuditoryDescription.create({ text: LOCALE.MESSAGES.regexp.SPACE }, {})
            ]
            : [];
        const descrs = Engine.evaluateNode(content);
        descrs.unshift(new AuditoryDescription({ text: '', layout: `beginrel${depth}` }));
        descrs.push(new AuditoryDescription({ text: '', layout: `endrel${depth}` }));
        first = false;
        return contextDescr.concat(left, descrs, right);
    };
}
export function implicitIterator(nodes, context) {
    const childNodes = nodes.slice(0);
    let contentNodes;
    if (nodes.length > 0) {
        contentNodes = XpathUtil.evalXPath('../../content/*', nodes[0]);
    }
    else {
        contentNodes = [];
    }
    return function () {
        const leftChild = childNodes.shift();
        const rightChild = childNodes[0];
        const content = contentNodes.shift();
        const contextDescr = context
            ? [AuditoryDescription.create({ text: context }, { translate: true })]
            : [];
        if (!content) {
            return contextDescr;
        }
        const left = leftChild && DomUtil.tagName(leftChild) === 'NUMBER';
        const right = rightChild && DomUtil.tagName(rightChild) === 'NUMBER';
        return contextDescr.concat(left && right && content.getAttribute('role') === SemanticRole.SPACE
            ? [
                AuditoryDescription.create({ text: LOCALE.MESSAGES.regexp.SPACE }, {})
            ]
            : []);
    };
}
function ignoreEnglish(text) {
    return correctFont(text, LOCALE.ALPHABETS.languagePrefix.english);
}
Grammar.getInstance().setCorrection('ignoreEnglish', ignoreEnglish);
export function contentIterator(nodes, context) {
    var _a;
    const func = suCI(nodes, context);
    const parentNode = nodes[0].parentNode.parentNode;
    const match = (_a = parentNode.getAttribute('annotation')) === null || _a === void 0 ? void 0 : _a.match(/depth:(\d+)/);
    const depth = match ? match[1] : '';
    return function () {
        const descrs = func();
        descrs.unshift(new AuditoryDescription({ text: '', layout: `beginrel${depth}` }));
        descrs.push(new AuditoryDescription({ text: '', layout: `endrel${depth}` }));
        return descrs;
    };
}
function literal(text) {
    const evalStr = (e) => Engine.getInstance().evaluator(e, Engine.getInstance().dynamicCstr);
    return Array.from(text).map(evalStr).join('');
}
Grammar.getInstance().setCorrection('literal', literal);
