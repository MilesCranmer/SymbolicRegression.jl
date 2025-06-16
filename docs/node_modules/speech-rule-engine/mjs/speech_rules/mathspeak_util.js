import { Span } from '../audio/span.js';
import * as BaseUtil from '../common/base_util.js';
import * as DomUtil from '../common/dom_util.js';
import * as XpathUtil from '../common/xpath_util.js';
import { LOCALE } from '../l10n/locale.js';
import { SemanticFont, SemanticRole, SemanticType } from '../semantic_tree/semantic_meaning.js';
import { SemanticProcessor } from '../semantic_tree/semantic_processor.js';
let nestingDepth = {};
export function spaceoutText(node) {
    return Array.from(node.textContent).map(Span.stringEmpty);
}
function spaceoutNodes(node, correction) {
    const content = Array.from(node.textContent);
    const result = [];
    const processor = SemanticProcessor.getInstance();
    const doc = node.ownerDocument;
    for (let i = 0, chr; (chr = content[i]); i++) {
        const leaf = processor
            .getNodeFactory()
            .makeLeafNode(chr, SemanticFont.UNKNOWN);
        const sn = processor.identifierNode(leaf, SemanticFont.UNKNOWN, '');
        correction(sn);
        result.push(sn.xml(doc));
    }
    return result;
}
export function spaceoutNumber(node) {
    return spaceoutNodes(node, function (sn) {
        if (!sn.textContent.match(/\W/)) {
            sn.type = SemanticType.NUMBER;
        }
    });
}
export function spaceoutIdentifier(node) {
    return spaceoutNodes(node, function (sn) {
        sn.font = SemanticFont.UNKNOWN;
        sn.type = SemanticType.IDENTIFIER;
    });
}
const nestingBarriers = [
    SemanticType.CASES,
    SemanticType.CELL,
    SemanticType.INTEGRAL,
    SemanticType.LINE,
    SemanticType.MATRIX,
    SemanticType.MULTILINE,
    SemanticType.OVERSCORE,
    SemanticType.ROOT,
    SemanticType.ROW,
    SemanticType.SQRT,
    SemanticType.SUBSCRIPT,
    SemanticType.SUPERSCRIPT,
    SemanticType.TABLE,
    SemanticType.UNDERSCORE,
    SemanticType.VECTOR
];
export function resetNestingDepth(node) {
    nestingDepth = {};
    return [node];
}
function getNestingDepth(type, node, tags, opt_barrierTags, opt_barrierAttrs, opt_func) {
    opt_barrierTags = opt_barrierTags || nestingBarriers;
    opt_barrierAttrs = opt_barrierAttrs || {};
    opt_func =
        opt_func ||
            function (_node) {
                return false;
            };
    const xmlText = DomUtil.serializeXml(node);
    if (!nestingDepth[type]) {
        nestingDepth[type] = {};
    }
    if (nestingDepth[type][xmlText]) {
        return nestingDepth[type][xmlText];
    }
    if (opt_func(node) || tags.indexOf(node.tagName) < 0) {
        return 0;
    }
    const depth = computeNestingDepth_(node, tags, BaseUtil.setdifference(opt_barrierTags, tags), opt_barrierAttrs, opt_func, 0);
    nestingDepth[type][xmlText] = depth;
    return depth;
}
function containsAttr(node, attrs) {
    if (!node.attributes) {
        return false;
    }
    const attributes = DomUtil.toArray(node.attributes);
    for (let i = 0, attr; (attr = attributes[i]); i++) {
        if (attrs[attr.nodeName] === attr.nodeValue) {
            return true;
        }
    }
    return false;
}
function computeNestingDepth_(node, tags, barriers, attrs, func, depth) {
    if (func(node) ||
        barriers.indexOf(node.tagName) > -1 ||
        containsAttr(node, attrs)) {
        return depth;
    }
    if (tags.indexOf(node.tagName) > -1) {
        depth++;
    }
    if (!node.childNodes || node.childNodes.length === 0) {
        return depth;
    }
    const children = DomUtil.toArray(node.childNodes);
    return Math.max.apply(null, children.map(function (subNode) {
        return computeNestingDepth_(subNode, tags, barriers, attrs, func, depth);
    }));
}
export function fractionNestingDepth(node) {
    return getNestingDepth('fraction', node, ['fraction'], nestingBarriers, {}, LOCALE.FUNCTIONS.fracNestDepth);
}
function nestedFraction(node, expr, opt_end) {
    const depth = fractionNestingDepth(node);
    const annotation = Array(depth).fill(expr);
    if (opt_end) {
        annotation.push(opt_end);
    }
    return annotation.join(LOCALE.MESSAGES.regexp.JOINER_FRAC);
}
export function openingFractionVerbose(node) {
    return Span.singleton(nestedFraction(node, LOCALE.MESSAGES.MS.START, LOCALE.MESSAGES.MS.FRAC_V));
}
export function closingFractionVerbose(node) {
    return Span.singleton(nestedFraction(node, LOCALE.MESSAGES.MS.END, LOCALE.MESSAGES.MS.FRAC_V), { kind: 'LAST' });
}
export function overFractionVerbose(node) {
    return Span.singleton(nestedFraction(node, LOCALE.MESSAGES.MS.FRAC_OVER), {});
}
export function openingFractionBrief(node) {
    return Span.singleton(nestedFraction(node, LOCALE.MESSAGES.MS.START, LOCALE.MESSAGES.MS.FRAC_B));
}
export function closingFractionBrief(node) {
    return Span.singleton(nestedFraction(node, LOCALE.MESSAGES.MS.END, LOCALE.MESSAGES.MS.FRAC_B), { kind: 'LAST' });
}
export function openingFractionSbrief(node) {
    const depth = fractionNestingDepth(node);
    return Span.singleton(depth === 1
        ? LOCALE.MESSAGES.MS.FRAC_S
        : LOCALE.FUNCTIONS.combineNestedFraction(LOCALE.MESSAGES.MS.NEST_FRAC, LOCALE.FUNCTIONS.radicalNestDepth(depth - 1), LOCALE.MESSAGES.MS.FRAC_S));
}
export function closingFractionSbrief(node) {
    const depth = fractionNestingDepth(node);
    return Span.singleton(depth === 1
        ? LOCALE.MESSAGES.MS.ENDFRAC
        : LOCALE.FUNCTIONS.combineNestedFraction(LOCALE.MESSAGES.MS.NEST_FRAC, LOCALE.FUNCTIONS.radicalNestDepth(depth - 1), LOCALE.MESSAGES.MS.ENDFRAC), { kind: 'LAST' });
}
export function overFractionSbrief(node) {
    const depth = fractionNestingDepth(node);
    return Span.singleton(depth === 1
        ? LOCALE.MESSAGES.MS.FRAC_OVER
        : LOCALE.FUNCTIONS.combineNestedFraction(LOCALE.MESSAGES.MS.NEST_FRAC, LOCALE.FUNCTIONS.radicalNestDepth(depth - 1), LOCALE.MESSAGES.MS.FRAC_OVER));
}
export function isSmallVulgarFraction(node) {
    return LOCALE.FUNCTIONS.fracNestDepth(node) ? [node] : [];
}
export function nestedSubSuper(node, init, replace) {
    while (node.parentNode) {
        const children = node.parentNode;
        const parent = children.parentNode;
        if (!parent) {
            break;
        }
        const nodeRole = node.getAttribute && node.getAttribute('role');
        if ((parent.tagName === SemanticType.SUBSCRIPT &&
            node === children.childNodes[1]) ||
            (parent.tagName === SemanticType.TENSOR &&
                nodeRole &&
                (nodeRole === SemanticRole.LEFTSUB ||
                    nodeRole === SemanticRole.RIGHTSUB))) {
            init = replace.sub + LOCALE.MESSAGES.regexp.JOINER_SUBSUPER + init;
        }
        if ((parent.tagName === SemanticType.SUPERSCRIPT &&
            node === children.childNodes[1]) ||
            (parent.tagName === SemanticType.TENSOR &&
                nodeRole &&
                (nodeRole === SemanticRole.LEFTSUPER ||
                    nodeRole === SemanticRole.RIGHTSUPER))) {
            init = replace.sup + LOCALE.MESSAGES.regexp.JOINER_SUBSUPER + init;
        }
        node = parent;
    }
    return init.trim();
}
export function subscriptVerbose(node) {
    return Span.singleton(nestedSubSuper(node, LOCALE.MESSAGES.MS.SUBSCRIPT, {
        sup: LOCALE.MESSAGES.MS.SUPER,
        sub: LOCALE.MESSAGES.MS.SUB
    }));
}
export function subscriptBrief(node) {
    return Span.singleton(nestedSubSuper(node, LOCALE.MESSAGES.MS.SUB, {
        sup: LOCALE.MESSAGES.MS.SUP,
        sub: LOCALE.MESSAGES.MS.SUB
    }));
}
export function superscriptVerbose(node) {
    return Span.singleton(nestedSubSuper(node, LOCALE.MESSAGES.MS.SUPERSCRIPT, {
        sup: LOCALE.MESSAGES.MS.SUPER,
        sub: LOCALE.MESSAGES.MS.SUB
    }));
}
export function superscriptBrief(node) {
    return Span.singleton(nestedSubSuper(node, LOCALE.MESSAGES.MS.SUP, {
        sup: LOCALE.MESSAGES.MS.SUP,
        sub: LOCALE.MESSAGES.MS.SUB
    }));
}
export function baselineVerbose(node) {
    const baseline = nestedSubSuper(node, '', {
        sup: LOCALE.MESSAGES.MS.SUPER,
        sub: LOCALE.MESSAGES.MS.SUB
    });
    return Span.singleton(!baseline
        ? LOCALE.MESSAGES.MS.BASELINE
        : baseline
            .replace(new RegExp(LOCALE.MESSAGES.MS.SUB + '$'), LOCALE.MESSAGES.MS.SUBSCRIPT)
            .replace(new RegExp(LOCALE.MESSAGES.MS.SUPER + '$'), LOCALE.MESSAGES.MS.SUPERSCRIPT));
}
export function baselineBrief(node) {
    const baseline = nestedSubSuper(node, '', {
        sup: LOCALE.MESSAGES.MS.SUP,
        sub: LOCALE.MESSAGES.MS.SUB
    });
    return Span.singleton(baseline || LOCALE.MESSAGES.MS.BASE);
}
export function radicalNestingDepth(node) {
    return getNestingDepth('radical', node, ['sqrt', 'root'], nestingBarriers, {});
}
function nestedRadical(node, prefix, postfix) {
    const depth = radicalNestingDepth(node);
    const index = getRootIndex(node);
    postfix = index ? LOCALE.FUNCTIONS.combineRootIndex(postfix, index) : postfix;
    return depth === 1
        ? postfix
        : LOCALE.FUNCTIONS.combineNestedRadical(prefix, LOCALE.FUNCTIONS.radicalNestDepth(depth - 1), postfix);
}
function getRootIndex(node) {
    const content = node.tagName === 'sqrt'
        ? '2'
        :
            XpathUtil.evalXPath('children/*[1]', node)[0].textContent.trim();
    return LOCALE.MESSAGES.MSroots[content] || '';
}
export function openingRadicalVerbose(node) {
    return Span.singleton(nestedRadical(node, LOCALE.MESSAGES.MS.NESTED, LOCALE.MESSAGES.MS.STARTROOT));
}
export function closingRadicalVerbose(node) {
    return Span.singleton(nestedRadical(node, LOCALE.MESSAGES.MS.NESTED, LOCALE.MESSAGES.MS.ENDROOT));
}
export function indexRadicalVerbose(node) {
    return Span.singleton(nestedRadical(node, LOCALE.MESSAGES.MS.NESTED, LOCALE.MESSAGES.MS.ROOTINDEX));
}
export function openingRadicalBrief(node) {
    return Span.singleton(nestedRadical(node, LOCALE.MESSAGES.MS.NEST_ROOT, LOCALE.MESSAGES.MS.STARTROOT));
}
export function closingRadicalBrief(node) {
    return Span.singleton(nestedRadical(node, LOCALE.MESSAGES.MS.NEST_ROOT, LOCALE.MESSAGES.MS.ENDROOT));
}
export function indexRadicalBrief(node) {
    return Span.singleton(nestedRadical(node, LOCALE.MESSAGES.MS.NEST_ROOT, LOCALE.MESSAGES.MS.ROOTINDEX));
}
export function openingRadicalSbrief(node) {
    return Span.singleton(nestedRadical(node, LOCALE.MESSAGES.MS.NEST_ROOT, LOCALE.MESSAGES.MS.ROOT));
}
export function indexRadicalSbrief(node) {
    return Span.singleton(nestedRadical(node, LOCALE.MESSAGES.MS.NEST_ROOT, LOCALE.MESSAGES.MS.INDEX));
}
function underscoreNestingDepth(node) {
    return getNestingDepth('underscore', node, ['underscore'], nestingBarriers, {}, function (node) {
        return (node.tagName &&
            node.tagName === SemanticType.UNDERSCORE &&
            node.childNodes[0].childNodes[1].getAttribute('role') ===
                SemanticRole.UNDERACCENT);
    });
}
export function nestedUnderscript(node) {
    const depth = underscoreNestingDepth(node);
    return Span.singleton(Array(depth).join(LOCALE.MESSAGES.MS.UNDER) + LOCALE.MESSAGES.MS.UNDERSCRIPT);
}
function overscoreNestingDepth(node) {
    return getNestingDepth('overscore', node, ['overscore'], nestingBarriers, {}, function (node) {
        return (node.tagName &&
            node.tagName === SemanticType.OVERSCORE &&
            node.childNodes[0].childNodes[1].getAttribute('role') ===
                SemanticRole.OVERACCENT);
    });
}
export function endscripts(_node) {
    return Span.singleton(LOCALE.MESSAGES.MS.ENDSCRIPTS);
}
export function nestedOverscript(node) {
    const depth = overscoreNestingDepth(node);
    return Span.singleton(Array(depth).join(LOCALE.MESSAGES.MS.OVER) + LOCALE.MESSAGES.MS.OVERSCRIPT);
}
export function determinantIsSimple(node) {
    if (node.tagName !== SemanticType.MATRIX ||
        node.getAttribute('role') !== SemanticRole.DETERMINANT) {
        return [];
    }
    const cells = XpathUtil.evalXPath('children/row/children/cell/children/*', node);
    for (let i = 0, cell; (cell = cells[i]); i++) {
        if (cell.tagName === SemanticType.NUMBER) {
            continue;
        }
        if (cell.tagName === SemanticType.IDENTIFIER) {
            const role = cell.getAttribute('role');
            if (role === SemanticRole.LATINLETTER ||
                role === SemanticRole.GREEKLETTER ||
                role === SemanticRole.OTHERLETTER) {
                continue;
            }
        }
        return [];
    }
    return [node];
}
export function generateBaselineConstraint() {
    const ignoreElems = ['subscript', 'superscript', 'tensor'];
    const mainElems = ['relseq', 'multrel'];
    const breakElems = ['fraction', 'punctuation', 'fenced', 'sqrt', 'root'];
    const ancestrify = (elemList) => elemList.map((elem) => 'ancestor::' + elem);
    const notify = (elem) => 'not(' + elem + ')';
    const prefix = 'ancestor::*/following-sibling::*';
    const middle = notify(ancestrify(ignoreElems).join(' or '));
    const mainList = ancestrify(mainElems);
    const breakList = ancestrify(breakElems);
    let breakCstrs = [];
    for (let i = 0, brk; (brk = breakList[i]); i++) {
        breakCstrs = breakCstrs.concat(mainList.map(function (elem) {
            return brk + '/' + elem;
        }));
    }
    const postfix = notify(breakCstrs.join(' | '));
    return [[prefix, middle, postfix].join(' and ')];
}
export function removeParens(node) {
    if (!node.childNodes.length ||
        !node.childNodes[0].childNodes.length ||
        !node.childNodes[0].childNodes[0].childNodes.length) {
        return Span.singleton('');
    }
    const content = node.childNodes[0].childNodes[0].childNodes[0].textContent;
    return Span.singleton(content.match(/^\(.+\)$/) ? content.slice(1, -1) : content);
}
const componentString = new Map([
    [3, 'CSFleftsuperscript'],
    [4, 'CSFleftsubscript'],
    [2, 'CSFbaseline'],
    [1, 'CSFrightsubscript'],
    [0, 'CSFrightsuperscript']
]);
const childNumber = new Map([
    [4, 2],
    [3, 3],
    [2, 1],
    [1, 4],
    [0, 5]
]);
function generateTensorRuleStrings_(constellation) {
    const constraints = [];
    let verbString = '';
    let briefString = '';
    let constel = parseInt(constellation, 2);
    for (let i = 0; i < 5; i++) {
        const childString = 'children/*[' + childNumber.get(i) + ']';
        if (constel & 1) {
            const compString = componentString.get(i % 5);
            verbString =
                '[t] ' + compString + 'Verbose; [n] ' + childString + ';' + verbString;
            briefString =
                '[t] ' + compString + 'Brief; [n] ' + childString + ';' + briefString;
        }
        else {
            constraints.unshift('name(' + childString + ')="empty"');
        }
        constel >>= 1;
    }
    return [constraints, verbString, briefString];
}
export function generateTensorRules(store, brief = true) {
    const constellations = [
        '11111',
        '11110',
        '11101',
        '11100',
        '10111',
        '10110',
        '10101',
        '10100',
        '01111',
        '01110',
        '01101',
        '01100'
    ];
    for (const constel of constellations) {
        let name = 'tensor' + constel;
        let [components, verbStr, briefStr] = generateTensorRuleStrings_(constel);
        store.defineRule(name, 'default', verbStr, 'self::tensor', ...components);
        if (brief) {
            store.defineRule(name, 'brief', briefStr, 'self::tensor', ...components);
            store.defineRule(name, 'sbrief', briefStr, 'self::tensor', ...components);
        }
        if (!(parseInt(constel, 2) & 3)) {
            continue;
        }
        const baselineStr = componentString.get(2);
        verbStr += '; [t]' + baselineStr + 'Verbose';
        briefStr += '; [t]' + baselineStr + 'Brief';
        name = name + '-baseline';
        const cstr = '((.//*[not(*)])[last()]/@id)!=(((.//ancestor::fraction|' +
            'ancestor::root|ancestor::sqrt|ancestor::cell|ancestor::line|' +
            'ancestor::stree)[1]//*[not(*)])[last()]/@id)';
        store.defineRule(name, 'default', verbStr, 'self::tensor', cstr, ...components);
        if (brief) {
            store.defineRule(name, 'brief', briefStr, 'self::tensor', cstr, ...components);
            store.defineRule(name, 'sbrief', briefStr, 'self::tensor', cstr, ...components);
        }
    }
}
export function smallRoot(node) {
    let max = Object.keys(LOCALE.MESSAGES.MSroots).length;
    if (!max) {
        return [];
    }
    else {
        max++;
    }
    if (!node.childNodes ||
        node.childNodes.length === 0 ||
        !node.childNodes[0].childNodes) {
        return [];
    }
    const index = node.childNodes[0].childNodes[0].textContent;
    if (!/^\d+$/.test(index)) {
        return [];
    }
    const num = parseInt(index, 10);
    return num > 1 && num <= max ? [node] : [];
}
