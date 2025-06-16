"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.spaceoutText = spaceoutText;
exports.spaceoutNumber = spaceoutNumber;
exports.spaceoutIdentifier = spaceoutIdentifier;
exports.resetNestingDepth = resetNestingDepth;
exports.fractionNestingDepth = fractionNestingDepth;
exports.openingFractionVerbose = openingFractionVerbose;
exports.closingFractionVerbose = closingFractionVerbose;
exports.overFractionVerbose = overFractionVerbose;
exports.openingFractionBrief = openingFractionBrief;
exports.closingFractionBrief = closingFractionBrief;
exports.openingFractionSbrief = openingFractionSbrief;
exports.closingFractionSbrief = closingFractionSbrief;
exports.overFractionSbrief = overFractionSbrief;
exports.isSmallVulgarFraction = isSmallVulgarFraction;
exports.nestedSubSuper = nestedSubSuper;
exports.subscriptVerbose = subscriptVerbose;
exports.subscriptBrief = subscriptBrief;
exports.superscriptVerbose = superscriptVerbose;
exports.superscriptBrief = superscriptBrief;
exports.baselineVerbose = baselineVerbose;
exports.baselineBrief = baselineBrief;
exports.radicalNestingDepth = radicalNestingDepth;
exports.openingRadicalVerbose = openingRadicalVerbose;
exports.closingRadicalVerbose = closingRadicalVerbose;
exports.indexRadicalVerbose = indexRadicalVerbose;
exports.openingRadicalBrief = openingRadicalBrief;
exports.closingRadicalBrief = closingRadicalBrief;
exports.indexRadicalBrief = indexRadicalBrief;
exports.openingRadicalSbrief = openingRadicalSbrief;
exports.indexRadicalSbrief = indexRadicalSbrief;
exports.nestedUnderscript = nestedUnderscript;
exports.endscripts = endscripts;
exports.nestedOverscript = nestedOverscript;
exports.determinantIsSimple = determinantIsSimple;
exports.generateBaselineConstraint = generateBaselineConstraint;
exports.removeParens = removeParens;
exports.generateTensorRules = generateTensorRules;
exports.smallRoot = smallRoot;
const span_js_1 = require("../audio/span.js");
const BaseUtil = require("../common/base_util.js");
const DomUtil = require("../common/dom_util.js");
const XpathUtil = require("../common/xpath_util.js");
const locale_js_1 = require("../l10n/locale.js");
const semantic_meaning_js_1 = require("../semantic_tree/semantic_meaning.js");
const semantic_processor_js_1 = require("../semantic_tree/semantic_processor.js");
let nestingDepth = {};
function spaceoutText(node) {
    return Array.from(node.textContent).map(span_js_1.Span.stringEmpty);
}
function spaceoutNodes(node, correction) {
    const content = Array.from(node.textContent);
    const result = [];
    const processor = semantic_processor_js_1.SemanticProcessor.getInstance();
    const doc = node.ownerDocument;
    for (let i = 0, chr; (chr = content[i]); i++) {
        const leaf = processor
            .getNodeFactory()
            .makeLeafNode(chr, semantic_meaning_js_1.SemanticFont.UNKNOWN);
        const sn = processor.identifierNode(leaf, semantic_meaning_js_1.SemanticFont.UNKNOWN, '');
        correction(sn);
        result.push(sn.xml(doc));
    }
    return result;
}
function spaceoutNumber(node) {
    return spaceoutNodes(node, function (sn) {
        if (!sn.textContent.match(/\W/)) {
            sn.type = semantic_meaning_js_1.SemanticType.NUMBER;
        }
    });
}
function spaceoutIdentifier(node) {
    return spaceoutNodes(node, function (sn) {
        sn.font = semantic_meaning_js_1.SemanticFont.UNKNOWN;
        sn.type = semantic_meaning_js_1.SemanticType.IDENTIFIER;
    });
}
const nestingBarriers = [
    semantic_meaning_js_1.SemanticType.CASES,
    semantic_meaning_js_1.SemanticType.CELL,
    semantic_meaning_js_1.SemanticType.INTEGRAL,
    semantic_meaning_js_1.SemanticType.LINE,
    semantic_meaning_js_1.SemanticType.MATRIX,
    semantic_meaning_js_1.SemanticType.MULTILINE,
    semantic_meaning_js_1.SemanticType.OVERSCORE,
    semantic_meaning_js_1.SemanticType.ROOT,
    semantic_meaning_js_1.SemanticType.ROW,
    semantic_meaning_js_1.SemanticType.SQRT,
    semantic_meaning_js_1.SemanticType.SUBSCRIPT,
    semantic_meaning_js_1.SemanticType.SUPERSCRIPT,
    semantic_meaning_js_1.SemanticType.TABLE,
    semantic_meaning_js_1.SemanticType.UNDERSCORE,
    semantic_meaning_js_1.SemanticType.VECTOR
];
function resetNestingDepth(node) {
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
function fractionNestingDepth(node) {
    return getNestingDepth('fraction', node, ['fraction'], nestingBarriers, {}, locale_js_1.LOCALE.FUNCTIONS.fracNestDepth);
}
function nestedFraction(node, expr, opt_end) {
    const depth = fractionNestingDepth(node);
    const annotation = Array(depth).fill(expr);
    if (opt_end) {
        annotation.push(opt_end);
    }
    return annotation.join(locale_js_1.LOCALE.MESSAGES.regexp.JOINER_FRAC);
}
function openingFractionVerbose(node) {
    return span_js_1.Span.singleton(nestedFraction(node, locale_js_1.LOCALE.MESSAGES.MS.START, locale_js_1.LOCALE.MESSAGES.MS.FRAC_V));
}
function closingFractionVerbose(node) {
    return span_js_1.Span.singleton(nestedFraction(node, locale_js_1.LOCALE.MESSAGES.MS.END, locale_js_1.LOCALE.MESSAGES.MS.FRAC_V), { kind: 'LAST' });
}
function overFractionVerbose(node) {
    return span_js_1.Span.singleton(nestedFraction(node, locale_js_1.LOCALE.MESSAGES.MS.FRAC_OVER), {});
}
function openingFractionBrief(node) {
    return span_js_1.Span.singleton(nestedFraction(node, locale_js_1.LOCALE.MESSAGES.MS.START, locale_js_1.LOCALE.MESSAGES.MS.FRAC_B));
}
function closingFractionBrief(node) {
    return span_js_1.Span.singleton(nestedFraction(node, locale_js_1.LOCALE.MESSAGES.MS.END, locale_js_1.LOCALE.MESSAGES.MS.FRAC_B), { kind: 'LAST' });
}
function openingFractionSbrief(node) {
    const depth = fractionNestingDepth(node);
    return span_js_1.Span.singleton(depth === 1
        ? locale_js_1.LOCALE.MESSAGES.MS.FRAC_S
        : locale_js_1.LOCALE.FUNCTIONS.combineNestedFraction(locale_js_1.LOCALE.MESSAGES.MS.NEST_FRAC, locale_js_1.LOCALE.FUNCTIONS.radicalNestDepth(depth - 1), locale_js_1.LOCALE.MESSAGES.MS.FRAC_S));
}
function closingFractionSbrief(node) {
    const depth = fractionNestingDepth(node);
    return span_js_1.Span.singleton(depth === 1
        ? locale_js_1.LOCALE.MESSAGES.MS.ENDFRAC
        : locale_js_1.LOCALE.FUNCTIONS.combineNestedFraction(locale_js_1.LOCALE.MESSAGES.MS.NEST_FRAC, locale_js_1.LOCALE.FUNCTIONS.radicalNestDepth(depth - 1), locale_js_1.LOCALE.MESSAGES.MS.ENDFRAC), { kind: 'LAST' });
}
function overFractionSbrief(node) {
    const depth = fractionNestingDepth(node);
    return span_js_1.Span.singleton(depth === 1
        ? locale_js_1.LOCALE.MESSAGES.MS.FRAC_OVER
        : locale_js_1.LOCALE.FUNCTIONS.combineNestedFraction(locale_js_1.LOCALE.MESSAGES.MS.NEST_FRAC, locale_js_1.LOCALE.FUNCTIONS.radicalNestDepth(depth - 1), locale_js_1.LOCALE.MESSAGES.MS.FRAC_OVER));
}
function isSmallVulgarFraction(node) {
    return locale_js_1.LOCALE.FUNCTIONS.fracNestDepth(node) ? [node] : [];
}
function nestedSubSuper(node, init, replace) {
    while (node.parentNode) {
        const children = node.parentNode;
        const parent = children.parentNode;
        if (!parent) {
            break;
        }
        const nodeRole = node.getAttribute && node.getAttribute('role');
        if ((parent.tagName === semantic_meaning_js_1.SemanticType.SUBSCRIPT &&
            node === children.childNodes[1]) ||
            (parent.tagName === semantic_meaning_js_1.SemanticType.TENSOR &&
                nodeRole &&
                (nodeRole === semantic_meaning_js_1.SemanticRole.LEFTSUB ||
                    nodeRole === semantic_meaning_js_1.SemanticRole.RIGHTSUB))) {
            init = replace.sub + locale_js_1.LOCALE.MESSAGES.regexp.JOINER_SUBSUPER + init;
        }
        if ((parent.tagName === semantic_meaning_js_1.SemanticType.SUPERSCRIPT &&
            node === children.childNodes[1]) ||
            (parent.tagName === semantic_meaning_js_1.SemanticType.TENSOR &&
                nodeRole &&
                (nodeRole === semantic_meaning_js_1.SemanticRole.LEFTSUPER ||
                    nodeRole === semantic_meaning_js_1.SemanticRole.RIGHTSUPER))) {
            init = replace.sup + locale_js_1.LOCALE.MESSAGES.regexp.JOINER_SUBSUPER + init;
        }
        node = parent;
    }
    return init.trim();
}
function subscriptVerbose(node) {
    return span_js_1.Span.singleton(nestedSubSuper(node, locale_js_1.LOCALE.MESSAGES.MS.SUBSCRIPT, {
        sup: locale_js_1.LOCALE.MESSAGES.MS.SUPER,
        sub: locale_js_1.LOCALE.MESSAGES.MS.SUB
    }));
}
function subscriptBrief(node) {
    return span_js_1.Span.singleton(nestedSubSuper(node, locale_js_1.LOCALE.MESSAGES.MS.SUB, {
        sup: locale_js_1.LOCALE.MESSAGES.MS.SUP,
        sub: locale_js_1.LOCALE.MESSAGES.MS.SUB
    }));
}
function superscriptVerbose(node) {
    return span_js_1.Span.singleton(nestedSubSuper(node, locale_js_1.LOCALE.MESSAGES.MS.SUPERSCRIPT, {
        sup: locale_js_1.LOCALE.MESSAGES.MS.SUPER,
        sub: locale_js_1.LOCALE.MESSAGES.MS.SUB
    }));
}
function superscriptBrief(node) {
    return span_js_1.Span.singleton(nestedSubSuper(node, locale_js_1.LOCALE.MESSAGES.MS.SUP, {
        sup: locale_js_1.LOCALE.MESSAGES.MS.SUP,
        sub: locale_js_1.LOCALE.MESSAGES.MS.SUB
    }));
}
function baselineVerbose(node) {
    const baseline = nestedSubSuper(node, '', {
        sup: locale_js_1.LOCALE.MESSAGES.MS.SUPER,
        sub: locale_js_1.LOCALE.MESSAGES.MS.SUB
    });
    return span_js_1.Span.singleton(!baseline
        ? locale_js_1.LOCALE.MESSAGES.MS.BASELINE
        : baseline
            .replace(new RegExp(locale_js_1.LOCALE.MESSAGES.MS.SUB + '$'), locale_js_1.LOCALE.MESSAGES.MS.SUBSCRIPT)
            .replace(new RegExp(locale_js_1.LOCALE.MESSAGES.MS.SUPER + '$'), locale_js_1.LOCALE.MESSAGES.MS.SUPERSCRIPT));
}
function baselineBrief(node) {
    const baseline = nestedSubSuper(node, '', {
        sup: locale_js_1.LOCALE.MESSAGES.MS.SUP,
        sub: locale_js_1.LOCALE.MESSAGES.MS.SUB
    });
    return span_js_1.Span.singleton(baseline || locale_js_1.LOCALE.MESSAGES.MS.BASE);
}
function radicalNestingDepth(node) {
    return getNestingDepth('radical', node, ['sqrt', 'root'], nestingBarriers, {});
}
function nestedRadical(node, prefix, postfix) {
    const depth = radicalNestingDepth(node);
    const index = getRootIndex(node);
    postfix = index ? locale_js_1.LOCALE.FUNCTIONS.combineRootIndex(postfix, index) : postfix;
    return depth === 1
        ? postfix
        : locale_js_1.LOCALE.FUNCTIONS.combineNestedRadical(prefix, locale_js_1.LOCALE.FUNCTIONS.radicalNestDepth(depth - 1), postfix);
}
function getRootIndex(node) {
    const content = node.tagName === 'sqrt'
        ? '2'
        :
            XpathUtil.evalXPath('children/*[1]', node)[0].textContent.trim();
    return locale_js_1.LOCALE.MESSAGES.MSroots[content] || '';
}
function openingRadicalVerbose(node) {
    return span_js_1.Span.singleton(nestedRadical(node, locale_js_1.LOCALE.MESSAGES.MS.NESTED, locale_js_1.LOCALE.MESSAGES.MS.STARTROOT));
}
function closingRadicalVerbose(node) {
    return span_js_1.Span.singleton(nestedRadical(node, locale_js_1.LOCALE.MESSAGES.MS.NESTED, locale_js_1.LOCALE.MESSAGES.MS.ENDROOT));
}
function indexRadicalVerbose(node) {
    return span_js_1.Span.singleton(nestedRadical(node, locale_js_1.LOCALE.MESSAGES.MS.NESTED, locale_js_1.LOCALE.MESSAGES.MS.ROOTINDEX));
}
function openingRadicalBrief(node) {
    return span_js_1.Span.singleton(nestedRadical(node, locale_js_1.LOCALE.MESSAGES.MS.NEST_ROOT, locale_js_1.LOCALE.MESSAGES.MS.STARTROOT));
}
function closingRadicalBrief(node) {
    return span_js_1.Span.singleton(nestedRadical(node, locale_js_1.LOCALE.MESSAGES.MS.NEST_ROOT, locale_js_1.LOCALE.MESSAGES.MS.ENDROOT));
}
function indexRadicalBrief(node) {
    return span_js_1.Span.singleton(nestedRadical(node, locale_js_1.LOCALE.MESSAGES.MS.NEST_ROOT, locale_js_1.LOCALE.MESSAGES.MS.ROOTINDEX));
}
function openingRadicalSbrief(node) {
    return span_js_1.Span.singleton(nestedRadical(node, locale_js_1.LOCALE.MESSAGES.MS.NEST_ROOT, locale_js_1.LOCALE.MESSAGES.MS.ROOT));
}
function indexRadicalSbrief(node) {
    return span_js_1.Span.singleton(nestedRadical(node, locale_js_1.LOCALE.MESSAGES.MS.NEST_ROOT, locale_js_1.LOCALE.MESSAGES.MS.INDEX));
}
function underscoreNestingDepth(node) {
    return getNestingDepth('underscore', node, ['underscore'], nestingBarriers, {}, function (node) {
        return (node.tagName &&
            node.tagName === semantic_meaning_js_1.SemanticType.UNDERSCORE &&
            node.childNodes[0].childNodes[1].getAttribute('role') ===
                semantic_meaning_js_1.SemanticRole.UNDERACCENT);
    });
}
function nestedUnderscript(node) {
    const depth = underscoreNestingDepth(node);
    return span_js_1.Span.singleton(Array(depth).join(locale_js_1.LOCALE.MESSAGES.MS.UNDER) + locale_js_1.LOCALE.MESSAGES.MS.UNDERSCRIPT);
}
function overscoreNestingDepth(node) {
    return getNestingDepth('overscore', node, ['overscore'], nestingBarriers, {}, function (node) {
        return (node.tagName &&
            node.tagName === semantic_meaning_js_1.SemanticType.OVERSCORE &&
            node.childNodes[0].childNodes[1].getAttribute('role') ===
                semantic_meaning_js_1.SemanticRole.OVERACCENT);
    });
}
function endscripts(_node) {
    return span_js_1.Span.singleton(locale_js_1.LOCALE.MESSAGES.MS.ENDSCRIPTS);
}
function nestedOverscript(node) {
    const depth = overscoreNestingDepth(node);
    return span_js_1.Span.singleton(Array(depth).join(locale_js_1.LOCALE.MESSAGES.MS.OVER) + locale_js_1.LOCALE.MESSAGES.MS.OVERSCRIPT);
}
function determinantIsSimple(node) {
    if (node.tagName !== semantic_meaning_js_1.SemanticType.MATRIX ||
        node.getAttribute('role') !== semantic_meaning_js_1.SemanticRole.DETERMINANT) {
        return [];
    }
    const cells = XpathUtil.evalXPath('children/row/children/cell/children/*', node);
    for (let i = 0, cell; (cell = cells[i]); i++) {
        if (cell.tagName === semantic_meaning_js_1.SemanticType.NUMBER) {
            continue;
        }
        if (cell.tagName === semantic_meaning_js_1.SemanticType.IDENTIFIER) {
            const role = cell.getAttribute('role');
            if (role === semantic_meaning_js_1.SemanticRole.LATINLETTER ||
                role === semantic_meaning_js_1.SemanticRole.GREEKLETTER ||
                role === semantic_meaning_js_1.SemanticRole.OTHERLETTER) {
                continue;
            }
        }
        return [];
    }
    return [node];
}
function generateBaselineConstraint() {
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
function removeParens(node) {
    if (!node.childNodes.length ||
        !node.childNodes[0].childNodes.length ||
        !node.childNodes[0].childNodes[0].childNodes.length) {
        return span_js_1.Span.singleton('');
    }
    const content = node.childNodes[0].childNodes[0].childNodes[0].textContent;
    return span_js_1.Span.singleton(content.match(/^\(.+\)$/) ? content.slice(1, -1) : content);
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
function generateTensorRules(store, brief = true) {
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
function smallRoot(node) {
    let max = Object.keys(locale_js_1.LOCALE.MESSAGES.MSroots).length;
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
