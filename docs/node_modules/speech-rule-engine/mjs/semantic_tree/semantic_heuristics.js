import { Debugger } from '../common/debugger.js';
import { Engine } from '../common/engine.js';
import { SemanticMap, NamedSymbol } from './semantic_attr.js';
import { SemanticHeuristics } from './semantic_heuristic_factory.js';
import { SemanticTreeHeuristic, SemanticMmlHeuristic, SemanticMultiHeuristic } from './semantic_heuristic.js';
import { SemanticRole, SemanticType } from './semantic_meaning.js';
import * as SemanticPred from './semantic_pred.js';
import { SemanticProcessor } from './semantic_processor.js';
import * as SemanticUtil from './semantic_util.js';
import { SemanticSkeleton } from './semantic_skeleton.js';
import { MMLTAGS } from '../semantic_tree/semantic_util.js';
import * as DomUtil from '../common/dom_util.js';
SemanticHeuristics.add(new SemanticTreeHeuristic('combine_juxtaposition', combineJuxtaposition));
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
SemanticHeuristics.add(new SemanticTreeHeuristic('propagateSimpleFunction', (node) => {
    if ((node.type === SemanticType.INFIXOP ||
        node.type === SemanticType.FRACTION) &&
        node.childNodes.every(SemanticPred.isSimpleFunction)) {
        node.role = SemanticRole.COMPFUNC;
    }
    return node;
}, (_node) => Engine.getInstance().domain === 'clearspeak'));
SemanticHeuristics.add(new SemanticTreeHeuristic('simpleNamedFunction', (node) => {
    const specialFunctions = ['f', 'g', 'h', 'F', 'G', 'H'];
    if (node.role !== SemanticRole.UNIT &&
        specialFunctions.indexOf(node.textContent) !== -1) {
        node.role = SemanticRole.SIMPLEFUNC;
    }
    return node;
}, (_node) => Engine.getInstance().domain === 'clearspeak'));
SemanticHeuristics.add(new SemanticTreeHeuristic('propagateComposedFunction', (node) => {
    if (node.type === SemanticType.FENCED &&
        node.childNodes[0].role === SemanticRole.COMPFUNC) {
        node.role = SemanticRole.COMPFUNC;
    }
    return node;
}, (_node) => Engine.getInstance().domain === 'clearspeak'));
SemanticHeuristics.add(new SemanticTreeHeuristic('multioperator', (node) => {
    if (node.role !== SemanticRole.UNKNOWN || node.textContent.length <= 1) {
        return;
    }
    SemanticProcessor.compSemantics(node, 'role', SemanticRole);
    SemanticProcessor.compSemantics(node, 'type', SemanticType);
}));
SemanticHeuristics.add(new SemanticMultiHeuristic('convert_juxtaposition', (nodes) => {
    let partition = SemanticUtil.partitionNodes(nodes, function (x) {
        return (x.textContent === NamedSymbol.invisibleTimes &&
            x.type === SemanticType.OPERATOR);
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
        return (x.textContent === NamedSymbol.invisibleTimes &&
            (x.type === SemanticType.OPERATOR || x.type === SemanticType.INFIXOP));
    });
    if (!partition.rel.length) {
        return nodes;
    }
    return recurseJuxtaposition(partition.comp.shift(), partition.rel, partition.comp);
}));
SemanticHeuristics.add(new SemanticTreeHeuristic('simple2prefix', (node) => {
    if (node.textContent.length > 1 &&
        !node.textContent[0].match(/[A-Z]/)) {
        node.role = SemanticRole.PREFIXFUNC;
    }
    return node;
}, (node) => Engine.getInstance().modality === 'braille' &&
    node.type === SemanticType.IDENTIFIER));
SemanticHeuristics.add(new SemanticTreeHeuristic('detect_cycle', (node) => {
    node.type = SemanticType.MATRIX;
    node.role = SemanticRole.CYCLE;
    const row = node.childNodes[0];
    row.type = SemanticType.ROW;
    row.role = SemanticRole.CYCLE;
    row.textContent = '';
    row.contentNodes = [];
    return node;
}, (node) => node.type === SemanticType.FENCED &&
    node.childNodes[0].type === SemanticType.INFIXOP &&
    node.childNodes[0].role === SemanticRole.IMPLICIT &&
    node.childNodes[0].childNodes.every(function (x) {
        return x.type === SemanticType.NUMBER;
    }) &&
    node.childNodes[0].contentNodes.every(function (x) {
        return x.role === SemanticRole.SPACE;
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
    const processor = SemanticProcessor.getInstance();
    if (prevExists && nextExists) {
        if (next[0].type === SemanticType.INFIXOP &&
            next[0].role === SemanticRole.IMPLICIT) {
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
    if (op.type === SemanticType.INFIXOP &&
        (op.role === SemanticRole.IMPLICIT || op.role === SemanticRole.UNIT)) {
        Debugger.getInstance().output('Juxta Heuristic Case 2');
        const right = (left ? [left, op] : [op]).concat(first);
        return recurseJuxtaposition(acc.concat(right), ops, elements);
    }
    if (!left) {
        Debugger.getInstance().output('Juxta Heuristic Case 3');
        return recurseJuxtaposition([op].concat(first), ops, elements);
    }
    const right = first.shift();
    if (!right) {
        Debugger.getInstance().output('Juxta Heuristic Case 9');
        const newOp = SemanticHeuristics.factory.makeBranchNode(SemanticType.INFIXOP, [left, ops.shift()], [op], op.textContent);
        newOp.role = SemanticRole.IMPLICIT;
        SemanticHeuristics.run('combine_juxtaposition', newOp);
        ops.unshift(newOp);
        return recurseJuxtaposition(acc, ops, elements);
    }
    if (SemanticPred.isOperator(left) || SemanticPred.isOperator(right)) {
        Debugger.getInstance().output('Juxta Heuristic Case 4');
        return recurseJuxtaposition(acc.concat([left, op, right]).concat(first), ops, elements);
    }
    let result = null;
    if (SemanticPred.isImplicitOp(left) && SemanticPred.isImplicitOp(right)) {
        Debugger.getInstance().output('Juxta Heuristic Case 5');
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
        Debugger.getInstance().output('Juxta Heuristic Case 6');
        left.contentNodes.push(op);
        left.childNodes.push(right);
        right.parent = left;
        op.parent = left;
        left.addMathmlNodes(op.mathml);
        left.addMathmlNodes(right.mathml);
        result = left;
    }
    else if (SemanticPred.isImplicitOp(right)) {
        Debugger.getInstance().output('Juxta Heuristic Case 7');
        right.contentNodes.unshift(op);
        right.childNodes.unshift(left);
        left.parent = right;
        op.parent = right;
        right.addMathmlNodes(op.mathml);
        right.addMathmlNodes(left.mathml);
        result = right;
    }
    else {
        Debugger.getInstance().output('Juxta Heuristic Case 8');
        result = SemanticHeuristics.factory.makeBranchNode(SemanticType.INFIXOP, [left, right], [op], op.textContent);
        result.role = SemanticRole.IMPLICIT;
    }
    acc.push(result);
    return recurseJuxtaposition(acc.concat(first), ops, elements);
}
SemanticHeuristics.add(new SemanticMultiHeuristic('intvar_from_implicit', implicitUnpack, (nodes) => nodes[0] && SemanticPred.isImplicit(nodes[0])));
function implicitUnpack(nodes) {
    const children = nodes[0].childNodes;
    nodes.splice(0, 1, ...children);
}
SemanticHeuristics.add(new SemanticTreeHeuristic('intvar_from_fraction', integralFractionArg, (node) => {
    if (node.type !== SemanticType.INTEGRAL)
        return false;
    const [, integrand, intvar] = node.childNodes;
    return (intvar.type === SemanticType.EMPTY &&
        integrand.type === SemanticType.FRACTION);
}));
function integralFractionArg(node) {
    const integrand = node.childNodes[1];
    const enumerator = integrand.childNodes[0];
    if (SemanticPred.isIntegralDxBoundarySingle(enumerator)) {
        enumerator.role = SemanticRole.INTEGRAL;
        return;
    }
    if (!SemanticPred.isImplicit(enumerator))
        return;
    const length = enumerator.childNodes.length;
    const first = enumerator.childNodes[length - 2];
    const second = enumerator.childNodes[length - 1];
    if (SemanticPred.isIntegralDxBoundarySingle(second)) {
        second.role = SemanticRole.INTEGRAL;
        return;
    }
    if (SemanticPred.isIntegralDxBoundary(first, second)) {
        const prefix = SemanticProcessor.getInstance()['prefixNode_'](second, [
            first
        ]);
        prefix.role = SemanticRole.INTEGRAL;
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
SemanticHeuristics.add(new SemanticTreeHeuristic('rewrite_subcases', rewriteSubcasesTable, (table) => {
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
        DomUtil.tagName(node.childNodes[0]) === MMLTAGS.MPADDED &&
        DomUtil.tagName(node.childNodes[0].childNodes[0]) ===
            MMLTAGS.MPADDED &&
        DomUtil.tagName(node.childNodes[0].childNodes[node.childNodes[0].childNodes.length - 1]) === MMLTAGS.MPHANTOM);
}
const rewritable = [
    SemanticType.PUNCTUATED,
    SemanticType.RELSEQ,
    SemanticType.MULTIREL,
    SemanticType.INFIXOP,
    SemanticType.PREFIXOP,
    SemanticType.POSTFIXOP
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
    SemanticProcessor.tableToMultiline(table);
    const newNode = SemanticProcessor.getInstance().row(row);
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
    if (cell.type === SemanticType.PUNCTUATED &&
        (left
            ? cell.role === SemanticRole.ENDPUNCT
            : cell.role === SemanticRole.STARTPUNCT)) {
        const children = cell.childNodes;
        if (rewriteFence(children[left ? children.length - 1 : 0])) {
            cell = children[left ? 0 : children.length - 1];
            fence = children[left ? children.length - 1 : 0];
        }
    }
    if (rewritable.indexOf(cell.type) !== -1) {
        const children = cell.childNodes;
        rewriteFence(children[left ? children.length - 1 : 0]);
        const newNodes = SemanticSkeleton.combineContentChildren(cell.type, cell.role, cell.contentNodes, cell.childNodes);
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
    [SemanticRole.METRIC]: SemanticRole.METRIC,
    [SemanticRole.VBAR]: SemanticRole.NEUTRAL,
    [SemanticRole.OPENFENCE]: SemanticRole.OPEN,
    [SemanticRole.CLOSEFENCE]: SemanticRole.CLOSE
};
function rewriteFence(fence) {
    if (fence.type !== SemanticType.PUNCTUATION) {
        return false;
    }
    const role = PUNCT_TO_FENCE_[fence.role];
    if (!role) {
        return false;
    }
    fence.role = role;
    fence.type = SemanticType.FENCE;
    fence.addAnnotation('Emph', 'fence');
    return true;
}
SemanticHeuristics.add(new SemanticMultiHeuristic('ellipses', (nodes) => {
    const newNodes = [];
    let current = nodes.shift();
    while (current) {
        [current, nodes] = combineNodes(current, nodes, SemanticRole.FULLSTOP, SemanticRole.ELLIPSIS);
        [current, nodes] = combineNodes(current, nodes, SemanticRole.DASH);
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
    const node = SemanticHeuristics.factory.makeBranchNode(SemanticType.PUNCTUATION, nodes, []);
    node.role = role;
    return node;
}
SemanticHeuristics.add(new SemanticMultiHeuristic('op_with_limits', (nodes) => {
    const center = nodes[0];
    center.type = SemanticType.LARGEOP;
    center.role = SemanticRole.SUM;
    return nodes;
}, (nodes) => {
    return (nodes[0].type === SemanticType.OPERATOR &&
        nodes
            .slice(1)
            .some((node) => node.type === SemanticType.RELSEQ ||
            node.type === SemanticType.MULTIREL ||
            (node.type === SemanticType.INFIXOP &&
                node.role === SemanticRole.ELEMENT) ||
            (node.type === SemanticType.PUNCTUATED &&
                node.role === SemanticRole.SEQUENCE)));
}));
SemanticHeuristics.add(new SemanticMultiHeuristic('bracketed_interval', (nodes) => {
    const leftFence = nodes[0];
    const rightFence = nodes[1];
    const content = nodes.slice(2);
    const childNode = SemanticProcessor.getInstance().row(content);
    const fenced = SemanticHeuristics.factory.makeBranchNode(SemanticType.FENCED, [childNode], [leftFence, rightFence]);
    fenced.role = SemanticRole.LEFTRIGHT;
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
SemanticHeuristics.add(new SemanticMmlHeuristic('function_from_identifiers', (node) => {
    const expr = DomUtil.toArray(node.childNodes)
        .map((x) => x.textContent.trim())
        .join('');
    const meaning = SemanticMap.Meaning.get(expr);
    if (meaning.type === SemanticType.UNKNOWN) {
        return node;
    }
    const snode = SemanticHeuristics.factory.makeLeafNode(expr, SemanticProcessor.getInstance().font(node.getAttribute('mathvariant')));
    snode.mathmlTree = node;
    return snode;
}, (node) => {
    const children = DomUtil.toArray(node.childNodes);
    if (children.length < 2) {
        return false;
    }
    return children.every((child) => DomUtil.tagName(child) === MMLTAGS.MI &&
        SemanticMap.Meaning.get(child.textContent.trim()).role ===
            SemanticRole.LATINLETTER);
}));
