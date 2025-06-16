"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const debugger_js_1 = require("../common/debugger.js");
const engine_js_1 = require("../common/engine.js");
const semantic_attr_js_1 = require("./semantic_attr.js");
const semantic_heuristic_factory_js_1 = require("./semantic_heuristic_factory.js");
const semantic_heuristic_js_1 = require("./semantic_heuristic.js");
const semantic_meaning_js_1 = require("./semantic_meaning.js");
const SemanticPred = require("./semantic_pred.js");
const semantic_processor_js_1 = require("./semantic_processor.js");
const SemanticUtil = require("./semantic_util.js");
const semantic_skeleton_js_1 = require("./semantic_skeleton.js");
const semantic_util_js_1 = require("../semantic_tree/semantic_util.js");
const DomUtil = require("../common/dom_util.js");
semantic_heuristic_factory_js_1.SemanticHeuristics.add(new semantic_heuristic_js_1.SemanticTreeHeuristic('combine_juxtaposition', combineJuxtaposition));
function combineJuxtaposition(root) {
    for (let i = root.childNodes.length - 1, child; (child = root.childNodes[i]); i--) {
        if (!SemanticPred.isImplicitOp(child) || child.nobreaking) {
            continue;
        }
        root.childNodes.splice(i, 1, ...child.childNodes);
        root.contentNodes.splice(i, 0, ...child.contentNodes);
        child.childNodes.concat(child.contentNodes).forEach(function (x) {
            x.parent = root;
        });
        root.addMathmlNodes(child.mathml);
    }
    return root;
}
semantic_heuristic_factory_js_1.SemanticHeuristics.add(new semantic_heuristic_js_1.SemanticTreeHeuristic('propagateSimpleFunction', (node) => {
    if ((node.type === semantic_meaning_js_1.SemanticType.INFIXOP ||
        node.type === semantic_meaning_js_1.SemanticType.FRACTION) &&
        node.childNodes.every(SemanticPred.isSimpleFunction)) {
        node.role = semantic_meaning_js_1.SemanticRole.COMPFUNC;
    }
    return node;
}, (_node) => engine_js_1.Engine.getInstance().domain === 'clearspeak'));
semantic_heuristic_factory_js_1.SemanticHeuristics.add(new semantic_heuristic_js_1.SemanticTreeHeuristic('simpleNamedFunction', (node) => {
    const specialFunctions = ['f', 'g', 'h', 'F', 'G', 'H'];
    if (node.role !== semantic_meaning_js_1.SemanticRole.UNIT &&
        specialFunctions.indexOf(node.textContent) !== -1) {
        node.role = semantic_meaning_js_1.SemanticRole.SIMPLEFUNC;
    }
    return node;
}, (_node) => engine_js_1.Engine.getInstance().domain === 'clearspeak'));
semantic_heuristic_factory_js_1.SemanticHeuristics.add(new semantic_heuristic_js_1.SemanticTreeHeuristic('propagateComposedFunction', (node) => {
    if (node.type === semantic_meaning_js_1.SemanticType.FENCED &&
        node.childNodes[0].role === semantic_meaning_js_1.SemanticRole.COMPFUNC) {
        node.role = semantic_meaning_js_1.SemanticRole.COMPFUNC;
    }
    return node;
}, (_node) => engine_js_1.Engine.getInstance().domain === 'clearspeak'));
semantic_heuristic_factory_js_1.SemanticHeuristics.add(new semantic_heuristic_js_1.SemanticTreeHeuristic('multioperator', (node) => {
    if (node.role !== semantic_meaning_js_1.SemanticRole.UNKNOWN || node.textContent.length <= 1) {
        return;
    }
    semantic_processor_js_1.SemanticProcessor.compSemantics(node, 'role', semantic_meaning_js_1.SemanticRole);
    semantic_processor_js_1.SemanticProcessor.compSemantics(node, 'type', semantic_meaning_js_1.SemanticType);
}));
semantic_heuristic_factory_js_1.SemanticHeuristics.add(new semantic_heuristic_js_1.SemanticMultiHeuristic('convert_juxtaposition', (nodes) => {
    let partition = SemanticUtil.partitionNodes(nodes, function (x) {
        return (x.textContent === semantic_attr_js_1.NamedSymbol.invisibleTimes &&
            x.type === semantic_meaning_js_1.SemanticType.OPERATOR);
    });
    partition = partition.rel.length
        ? juxtapositionPrePost(partition)
        : partition;
    nodes = partition.comp[0];
    for (let i = 1, c, r; (c = partition.comp[i]), (r = partition.rel[i - 1]); i++) {
        nodes.push(r);
        nodes = nodes.concat(c);
    }
    partition = SemanticUtil.partitionNodes(nodes, function (x) {
        return (x.textContent === semantic_attr_js_1.NamedSymbol.invisibleTimes &&
            (x.type === semantic_meaning_js_1.SemanticType.OPERATOR || x.type === semantic_meaning_js_1.SemanticType.INFIXOP));
    });
    if (!partition.rel.length) {
        return nodes;
    }
    return recurseJuxtaposition(partition.comp.shift(), partition.rel, partition.comp);
}));
semantic_heuristic_factory_js_1.SemanticHeuristics.add(new semantic_heuristic_js_1.SemanticTreeHeuristic('simple2prefix', (node) => {
    if (node.textContent.length > 1 &&
        !node.textContent[0].match(/[A-Z]/)) {
        node.role = semantic_meaning_js_1.SemanticRole.PREFIXFUNC;
    }
    return node;
}, (node) => engine_js_1.Engine.getInstance().modality === 'braille' &&
    node.type === semantic_meaning_js_1.SemanticType.IDENTIFIER));
semantic_heuristic_factory_js_1.SemanticHeuristics.add(new semantic_heuristic_js_1.SemanticTreeHeuristic('detect_cycle', (node) => {
    node.type = semantic_meaning_js_1.SemanticType.MATRIX;
    node.role = semantic_meaning_js_1.SemanticRole.CYCLE;
    const row = node.childNodes[0];
    row.type = semantic_meaning_js_1.SemanticType.ROW;
    row.role = semantic_meaning_js_1.SemanticRole.CYCLE;
    row.textContent = '';
    row.contentNodes = [];
    return node;
}, (node) => node.type === semantic_meaning_js_1.SemanticType.FENCED &&
    node.childNodes[0].type === semantic_meaning_js_1.SemanticType.INFIXOP &&
    node.childNodes[0].role === semantic_meaning_js_1.SemanticRole.IMPLICIT &&
    node.childNodes[0].childNodes.every(function (x) {
        return x.type === semantic_meaning_js_1.SemanticType.NUMBER;
    }) &&
    node.childNodes[0].contentNodes.every(function (x) {
        return x.role === semantic_meaning_js_1.SemanticRole.SPACE;
    })));
function juxtapositionPrePost(partition) {
    const rels = [];
    const comps = [];
    let next = partition.comp.shift();
    let rel = null;
    let collect = [];
    while (partition.comp.length) {
        collect = [];
        if (next.length) {
            if (rel) {
                rels.push(rel);
            }
            comps.push(next);
            rel = partition.rel.shift();
            next = partition.comp.shift();
            continue;
        }
        if (rel) {
            collect.push(rel);
        }
        while (!next.length && partition.comp.length) {
            next = partition.comp.shift();
            collect.push(partition.rel.shift());
        }
        rel = convertPrePost(collect, next, comps);
    }
    if (!collect.length && !next.length) {
        collect.push(rel);
        convertPrePost(collect, next, comps);
    }
    else {
        rels.push(rel);
        comps.push(next);
    }
    return { rel: rels, comp: comps };
}
function convertPrePost(collect, next, comps) {
    let rel = null;
    if (!collect.length) {
        return rel;
    }
    const prev = comps[comps.length - 1];
    const prevExists = prev && prev.length;
    const nextExists = next && next.length;
    const processor = semantic_processor_js_1.SemanticProcessor.getInstance();
    if (prevExists && nextExists) {
        if (next[0].type === semantic_meaning_js_1.SemanticType.INFIXOP &&
            next[0].role === semantic_meaning_js_1.SemanticRole.IMPLICIT) {
            rel = collect.pop();
            prev.push(processor['postfixNode_'](prev.pop(), collect));
            return rel;
        }
        rel = collect.shift();
        const result = processor['prefixNode_'](next.shift(), collect);
        next.unshift(result);
        return rel;
    }
    if (prevExists) {
        prev.push(processor['postfixNode_'](prev.pop(), collect));
        return rel;
    }
    if (nextExists) {
        next.unshift(processor['prefixNode_'](next.shift(), collect));
    }
    return rel;
}
function recurseJuxtaposition(acc, ops, elements) {
    if (!ops.length) {
        return acc;
    }
    const left = acc.pop();
    const op = ops.shift();
    const first = elements.shift();
    if (op.type === semantic_meaning_js_1.SemanticType.INFIXOP &&
        (op.role === semantic_meaning_js_1.SemanticRole.IMPLICIT || op.role === semantic_meaning_js_1.SemanticRole.UNIT)) {
        debugger_js_1.Debugger.getInstance().output('Juxta Heuristic Case 2');
        const right = (left ? [left, op] : [op]).concat(first);
        return recurseJuxtaposition(acc.concat(right), ops, elements);
    }
    if (!left) {
        debugger_js_1.Debugger.getInstance().output('Juxta Heuristic Case 3');
        return recurseJuxtaposition([op].concat(first), ops, elements);
    }
    const right = first.shift();
    if (!right) {
        debugger_js_1.Debugger.getInstance().output('Juxta Heuristic Case 9');
        const newOp = semantic_heuristic_factory_js_1.SemanticHeuristics.factory.makeBranchNode(semantic_meaning_js_1.SemanticType.INFIXOP, [left, ops.shift()], [op], op.textContent);
        newOp.role = semantic_meaning_js_1.SemanticRole.IMPLICIT;
        semantic_heuristic_factory_js_1.SemanticHeuristics.run('combine_juxtaposition', newOp);
        ops.unshift(newOp);
        return recurseJuxtaposition(acc, ops, elements);
    }
    if (SemanticPred.isOperator(left) || SemanticPred.isOperator(right)) {
        debugger_js_1.Debugger.getInstance().output('Juxta Heuristic Case 4');
        return recurseJuxtaposition(acc.concat([left, op, right]).concat(first), ops, elements);
    }
    let result = null;
    if (SemanticPred.isImplicitOp(left) && SemanticPred.isImplicitOp(right)) {
        debugger_js_1.Debugger.getInstance().output('Juxta Heuristic Case 5');
        left.contentNodes.push(op);
        left.contentNodes = left.contentNodes.concat(right.contentNodes);
        left.childNodes.push(right);
        left.childNodes = left.childNodes.concat(right.childNodes);
        right.childNodes.forEach((x) => (x.parent = left));
        op.parent = left;
        left.addMathmlNodes(op.mathml);
        left.addMathmlNodes(right.mathml);
        result = left;
    }
    else if (SemanticPred.isImplicitOp(left)) {
        debugger_js_1.Debugger.getInstance().output('Juxta Heuristic Case 6');
        left.contentNodes.push(op);
        left.childNodes.push(right);
        right.parent = left;
        op.parent = left;
        left.addMathmlNodes(op.mathml);
        left.addMathmlNodes(right.mathml);
        result = left;
    }
    else if (SemanticPred.isImplicitOp(right)) {
        debugger_js_1.Debugger.getInstance().output('Juxta Heuristic Case 7');
        right.contentNodes.unshift(op);
        right.childNodes.unshift(left);
        left.parent = right;
        op.parent = right;
        right.addMathmlNodes(op.mathml);
        right.addMathmlNodes(left.mathml);
        result = right;
    }
    else {
        debugger_js_1.Debugger.getInstance().output('Juxta Heuristic Case 8');
        result = semantic_heuristic_factory_js_1.SemanticHeuristics.factory.makeBranchNode(semantic_meaning_js_1.SemanticType.INFIXOP, [left, right], [op], op.textContent);
        result.role = semantic_meaning_js_1.SemanticRole.IMPLICIT;
    }
    acc.push(result);
    return recurseJuxtaposition(acc.concat(first), ops, elements);
}
semantic_heuristic_factory_js_1.SemanticHeuristics.add(new semantic_heuristic_js_1.SemanticMultiHeuristic('intvar_from_implicit', implicitUnpack, (nodes) => nodes[0] && SemanticPred.isImplicit(nodes[0])));
function implicitUnpack(nodes) {
    const children = nodes[0].childNodes;
    nodes.splice(0, 1, ...children);
}
semantic_heuristic_factory_js_1.SemanticHeuristics.add(new semantic_heuristic_js_1.SemanticTreeHeuristic('intvar_from_fraction', integralFractionArg, (node) => {
    if (node.type !== semantic_meaning_js_1.SemanticType.INTEGRAL)
        return false;
    const [, integrand, intvar] = node.childNodes;
    return (intvar.type === semantic_meaning_js_1.SemanticType.EMPTY &&
        integrand.type === semantic_meaning_js_1.SemanticType.FRACTION);
}));
function integralFractionArg(node) {
    const integrand = node.childNodes[1];
    const enumerator = integrand.childNodes[0];
    if (SemanticPred.isIntegralDxBoundarySingle(enumerator)) {
        enumerator.role = semantic_meaning_js_1.SemanticRole.INTEGRAL;
        return;
    }
    if (!SemanticPred.isImplicit(enumerator))
        return;
    const length = enumerator.childNodes.length;
    const first = enumerator.childNodes[length - 2];
    const second = enumerator.childNodes[length - 1];
    if (SemanticPred.isIntegralDxBoundarySingle(second)) {
        second.role = semantic_meaning_js_1.SemanticRole.INTEGRAL;
        return;
    }
    if (SemanticPred.isIntegralDxBoundary(first, second)) {
        const prefix = semantic_processor_js_1.SemanticProcessor.getInstance()['prefixNode_'](second, [
            first
        ]);
        prefix.role = semantic_meaning_js_1.SemanticRole.INTEGRAL;
        if (length === 2) {
            integrand.childNodes[0] = prefix;
        }
        else {
            enumerator.childNodes.pop();
            enumerator.contentNodes.pop();
            enumerator.childNodes[length - 2] = prefix;
            prefix.parent = enumerator;
        }
    }
}
semantic_heuristic_factory_js_1.SemanticHeuristics.add(new semantic_heuristic_js_1.SemanticTreeHeuristic('rewrite_subcases', rewriteSubcasesTable, (table) => {
    let left = true;
    let right = true;
    const topLeft = table.childNodes[0].childNodes[0];
    if (!eligibleNode(topLeft.mathmlTree)) {
        left = false;
    }
    else {
        for (let i = 1, row; (row = table.childNodes[i]); i++) {
            if (row.childNodes[0].childNodes.length) {
                left = false;
                break;
            }
        }
    }
    if (left) {
        table.addAnnotation('Emph', 'left');
    }
    const topRight = table.childNodes[0].childNodes[table.childNodes[0].childNodes.length - 1];
    if (!eligibleNode(topRight.mathmlTree)) {
        right = false;
    }
    else {
        const firstRow = table.childNodes[0].childNodes.length;
        for (let i = 1, row; (row = table.childNodes[i]); i++) {
            if (row.childNodes.length >= firstRow) {
                right = false;
                break;
            }
        }
    }
    if (right) {
        table.addAnnotation('Emph', 'right');
    }
    return left || right;
}));
function eligibleNode(node) {
    return (node.childNodes[0] &&
        node.childNodes[0].childNodes[0] &&
        DomUtil.tagName(node.childNodes[0]) === semantic_util_js_1.MMLTAGS.MPADDED &&
        DomUtil.tagName(node.childNodes[0].childNodes[0]) ===
            semantic_util_js_1.MMLTAGS.MPADDED &&
        DomUtil.tagName(node.childNodes[0].childNodes[node.childNodes[0].childNodes.length - 1]) === semantic_util_js_1.MMLTAGS.MPHANTOM);
}
const rewritable = [
    semantic_meaning_js_1.SemanticType.PUNCTUATED,
    semantic_meaning_js_1.SemanticType.RELSEQ,
    semantic_meaning_js_1.SemanticType.MULTIREL,
    semantic_meaning_js_1.SemanticType.INFIXOP,
    semantic_meaning_js_1.SemanticType.PREFIXOP,
    semantic_meaning_js_1.SemanticType.POSTFIXOP
];
function rewriteSubcasesTable(table) {
    table.addAnnotation('Emph', 'top');
    let row = [];
    if (table.hasAnnotation('Emph', 'left')) {
        const topLeft = table.childNodes[0].childNodes[0].childNodes[0];
        const cells = rewriteCell(topLeft, true);
        cells.forEach((x) => x.addAnnotation('Emph', 'left'));
        row = row.concat(cells);
        for (let i = 0, line; (line = table.childNodes[i]); i++) {
            line.childNodes.shift();
        }
    }
    row.push(table);
    if (table.hasAnnotation('Emph', 'right')) {
        const topRight = table.childNodes[0].childNodes[table.childNodes[0].childNodes.length - 1]
            .childNodes[0];
        const cells = rewriteCell(topRight);
        cells.forEach((x) => x.addAnnotation('Emph', 'left'));
        row = row.concat(cells);
        table.childNodes[0].childNodes.pop();
    }
    semantic_processor_js_1.SemanticProcessor.tableToMultiline(table);
    const newNode = semantic_processor_js_1.SemanticProcessor.getInstance().row(row);
    const annotation = table.annotation['Emph'];
    table.annotation['Emph'] = ['table'];
    annotation.forEach((x) => newNode.addAnnotation('Emph', x));
    return newNode;
}
function rewriteCell(cell, left) {
    if (!cell.childNodes.length) {
        rewriteFence(cell);
        return [cell];
    }
    let fence = null;
    if (cell.type === semantic_meaning_js_1.SemanticType.PUNCTUATED &&
        (left
            ? cell.role === semantic_meaning_js_1.SemanticRole.ENDPUNCT
            : cell.role === semantic_meaning_js_1.SemanticRole.STARTPUNCT)) {
        const children = cell.childNodes;
        if (rewriteFence(children[left ? children.length - 1 : 0])) {
            cell = children[left ? 0 : children.length - 1];
            fence = children[left ? children.length - 1 : 0];
        }
    }
    if (rewritable.indexOf(cell.type) !== -1) {
        const children = cell.childNodes;
        rewriteFence(children[left ? children.length - 1 : 0]);
        const newNodes = semantic_skeleton_js_1.SemanticSkeleton.combineContentChildren(cell.type, cell.role, cell.contentNodes, cell.childNodes);
        if (fence) {
            if (left) {
                newNodes.push(fence);
            }
            else {
                newNodes.unshift(fence);
            }
        }
        return newNodes;
    }
    return fence ? (left ? [cell, fence] : [fence, cell]) : [cell];
}
const PUNCT_TO_FENCE_ = {
    [semantic_meaning_js_1.SemanticRole.METRIC]: semantic_meaning_js_1.SemanticRole.METRIC,
    [semantic_meaning_js_1.SemanticRole.VBAR]: semantic_meaning_js_1.SemanticRole.NEUTRAL,
    [semantic_meaning_js_1.SemanticRole.OPENFENCE]: semantic_meaning_js_1.SemanticRole.OPEN,
    [semantic_meaning_js_1.SemanticRole.CLOSEFENCE]: semantic_meaning_js_1.SemanticRole.CLOSE
};
function rewriteFence(fence) {
    if (fence.type !== semantic_meaning_js_1.SemanticType.PUNCTUATION) {
        return false;
    }
    const role = PUNCT_TO_FENCE_[fence.role];
    if (!role) {
        return false;
    }
    fence.role = role;
    fence.type = semantic_meaning_js_1.SemanticType.FENCE;
    fence.addAnnotation('Emph', 'fence');
    return true;
}
semantic_heuristic_factory_js_1.SemanticHeuristics.add(new semantic_heuristic_js_1.SemanticMultiHeuristic('ellipses', (nodes) => {
    const newNodes = [];
    let current = nodes.shift();
    while (current) {
        [current, nodes] = combineNodes(current, nodes, semantic_meaning_js_1.SemanticRole.FULLSTOP, semantic_meaning_js_1.SemanticRole.ELLIPSIS);
        [current, nodes] = combineNodes(current, nodes, semantic_meaning_js_1.SemanticRole.DASH);
        newNodes.push(current);
        current = nodes.shift();
    }
    return newNodes;
}, (nodes) => nodes.length > 1));
function combineNodes(current, nodes, src, target = src) {
    const collect = [];
    while (current && current.role === src) {
        collect.push(current);
        current = nodes.shift();
    }
    if (!collect.length) {
        return [current, nodes];
    }
    if (current) {
        nodes.unshift(current);
    }
    return [
        collect.length === 1 ? collect[0] : combinedNodes(collect, target),
        nodes
    ];
}
function combinedNodes(nodes, role) {
    const node = semantic_heuristic_factory_js_1.SemanticHeuristics.factory.makeBranchNode(semantic_meaning_js_1.SemanticType.PUNCTUATION, nodes, []);
    node.role = role;
    return node;
}
semantic_heuristic_factory_js_1.SemanticHeuristics.add(new semantic_heuristic_js_1.SemanticMultiHeuristic('op_with_limits', (nodes) => {
    const center = nodes[0];
    center.type = semantic_meaning_js_1.SemanticType.LARGEOP;
    center.role = semantic_meaning_js_1.SemanticRole.SUM;
    return nodes;
}, (nodes) => {
    return (nodes[0].type === semantic_meaning_js_1.SemanticType.OPERATOR &&
        nodes
            .slice(1)
            .some((node) => node.type === semantic_meaning_js_1.SemanticType.RELSEQ ||
            node.type === semantic_meaning_js_1.SemanticType.MULTIREL ||
            (node.type === semantic_meaning_js_1.SemanticType.INFIXOP &&
                node.role === semantic_meaning_js_1.SemanticRole.ELEMENT) ||
            (node.type === semantic_meaning_js_1.SemanticType.PUNCTUATED &&
                node.role === semantic_meaning_js_1.SemanticRole.SEQUENCE)));
}));
semantic_heuristic_factory_js_1.SemanticHeuristics.add(new semantic_heuristic_js_1.SemanticMultiHeuristic('bracketed_interval', (nodes) => {
    const leftFence = nodes[0];
    const rightFence = nodes[1];
    const content = nodes.slice(2);
    const childNode = semantic_processor_js_1.SemanticProcessor.getInstance().row(content);
    const fenced = semantic_heuristic_factory_js_1.SemanticHeuristics.factory.makeBranchNode(semantic_meaning_js_1.SemanticType.FENCED, [childNode], [leftFence, rightFence]);
    fenced.role = semantic_meaning_js_1.SemanticRole.LEFTRIGHT;
    return fenced;
}, (nodes) => {
    const leftFence = nodes[0];
    const rightFence = nodes[1];
    const content = nodes.slice(2);
    if (!(leftFence &&
        (leftFence.textContent === ']' || leftFence.textContent === '[') &&
        rightFence &&
        (rightFence.textContent === ']' || rightFence.textContent === '['))) {
        return false;
    }
    const partition = SemanticUtil.partitionNodes(content, SemanticPred.isPunctuation);
    return !!(partition.rel.length === 1 &&
        partition.comp[0].length &&
        partition.comp[1].length);
}));
semantic_heuristic_factory_js_1.SemanticHeuristics.add(new semantic_heuristic_js_1.SemanticMmlHeuristic('function_from_identifiers', (node) => {
    const expr = DomUtil.toArray(node.childNodes)
        .map((x) => x.textContent.trim())
        .join('');
    const meaning = semantic_attr_js_1.SemanticMap.Meaning.get(expr);
    if (meaning.type === semantic_meaning_js_1.SemanticType.UNKNOWN) {
        return node;
    }
    const snode = semantic_heuristic_factory_js_1.SemanticHeuristics.factory.makeLeafNode(expr, semantic_processor_js_1.SemanticProcessor.getInstance().font(node.getAttribute('mathvariant')));
    snode.mathmlTree = node;
    return snode;
}, (node) => {
    const children = DomUtil.toArray(node.childNodes);
    if (children.length < 2) {
        return false;
    }
    return children.every((child) => DomUtil.tagName(child) === semantic_util_js_1.MMLTAGS.MI &&
        semantic_attr_js_1.SemanticMap.Meaning.get(child.textContent.trim()).role ===
            semantic_meaning_js_1.SemanticRole.LATINLETTER);
}));
