import * as DomUtil from '../common/dom_util.js';
import { NamedSymbol, SemanticMap } from './semantic_attr.js';
import { SemanticFont, SemanticRole, SemanticType, SemanticSecondary } from './semantic_meaning.js';
import { SemanticHeuristics } from './semantic_heuristic_factory.js';
import { SemanticNodeFactory } from './semantic_node_factory.js';
import * as SemanticPred from './semantic_pred.js';
import * as SemanticUtil from './semantic_util.js';
import { MMLTAGS } from '../semantic_tree/semantic_util.js';
export class SemanticProcessor {
    static getInstance() {
        SemanticProcessor.instance =
            SemanticProcessor.instance || new SemanticProcessor();
        return SemanticProcessor.instance;
    }
    static tableToMultiline(table) {
        if (!SemanticPred.tableIsMultiline(table)) {
            return SemanticHeuristics.run('rewrite_subcases', table, SemanticProcessor.classifyTable);
        }
        table.type = SemanticType.MULTILINE;
        for (let i = 0, row; (row = table.childNodes[i]); i++) {
            SemanticProcessor.rowToLine_(row, SemanticRole.MULTILINE);
        }
        if (table.childNodes.length === 1 &&
            !SemanticPred.lineIsLabelled(table.childNodes[0]) &&
            SemanticPred.isFencedElement(table.childNodes[0].childNodes[0])) {
            SemanticProcessor.tableToMatrixOrVector_(SemanticProcessor.rewriteFencedLine_(table));
        }
        SemanticProcessor.binomialForm_(table);
        SemanticProcessor.classifyMultiline(table);
        return table;
    }
    static number(node) {
        if (node.type === SemanticType.UNKNOWN ||
            node.type === SemanticType.IDENTIFIER) {
            node.type = SemanticType.NUMBER;
        }
        SemanticProcessor.meaningFromContent(node, SemanticProcessor.numberRole_);
        SemanticProcessor.exprFont_(node);
    }
    static classifyMultiline(multiline) {
        let index = 0;
        const length = multiline.childNodes.length;
        let line;
        while (index < length &&
            (!(line = multiline.childNodes[index]) || !line.childNodes.length)) {
            index++;
        }
        if (index >= length) {
            return;
        }
        const firstRole = line.childNodes[0].role;
        if (firstRole !== SemanticRole.UNKNOWN &&
            multiline.childNodes.every(function (x) {
                const cell = x.childNodes[0];
                return (!cell ||
                    (cell.role === firstRole &&
                        (SemanticPred.isType(cell, SemanticType.RELATION) ||
                            SemanticPred.isType(cell, SemanticType.RELSEQ))));
            })) {
            multiline.role = firstRole;
        }
    }
    static classifyTable(table) {
        const columns = SemanticProcessor.computeColumns_(table);
        SemanticProcessor.classifyByColumns_(table, columns, SemanticRole.EQUALITY) ||
            SemanticProcessor.classifyByColumns_(table, columns, SemanticRole.INEQUALITY, [SemanticRole.EQUALITY]) ||
            SemanticProcessor.classifyByColumns_(table, columns, SemanticRole.ARROW) ||
            SemanticProcessor.detectCaleyTable(table);
        return table;
    }
    static detectCaleyTable(table) {
        if (!table.mathmlTree) {
            return false;
        }
        const tree = table.mathmlTree;
        const cl = tree.getAttribute('columnlines');
        const rl = tree.getAttribute('rowlines');
        if (!cl || !rl) {
            return false;
        }
        if (SemanticProcessor.cayleySpacing(cl) &&
            SemanticProcessor.cayleySpacing(rl)) {
            table.role = SemanticRole.CAYLEY;
            return true;
        }
        return false;
    }
    static cayleySpacing(lines) {
        const list = lines.split(' ');
        return ((list[0] === 'solid' || list[0] === 'dashed') &&
            list.slice(1).every((x) => x === 'none'));
    }
    static proof(node, semantics, parse) {
        const attrs = SemanticProcessor.separateSemantics(semantics);
        return SemanticProcessor.getInstance().proof(node, attrs, parse);
    }
    static findSemantics(node, attr, opt_value) {
        const value = opt_value == null ? null : opt_value;
        const semantics = SemanticProcessor.getSemantics(node);
        if (!semantics) {
            return false;
        }
        if (!semantics[attr]) {
            return false;
        }
        return value == null ? true : semantics[attr] === value;
    }
    static getSemantics(node) {
        const semantics = node.getAttribute('semantics');
        if (!semantics) {
            return null;
        }
        return SemanticProcessor.separateSemantics(semantics);
    }
    static removePrefix(name) {
        const [, ...rest] = name.split('_');
        return rest.join('_');
    }
    static separateSemantics(attr) {
        const result = {};
        attr.split(';').forEach(function (x) {
            const [name, value] = x.split(':');
            result[SemanticProcessor.removePrefix(name)] = value;
        });
        return result;
    }
    static matchSpaces_(nodes, ops) {
        for (let i = 0, op; (op = ops[i]); i++) {
            const node = nodes[i];
            const mt1 = node.mathmlTree;
            const mt2 = nodes[i + 1].mathmlTree;
            if (!mt1 || !mt2) {
                continue;
            }
            const sibling = mt1.nextSibling;
            if (!sibling || sibling === mt2) {
                continue;
            }
            const spacer = SemanticProcessor.getSpacer_(sibling);
            if (spacer) {
                op.mathml.push(spacer);
                op.mathmlTree = spacer;
                op.role = SemanticRole.SPACE;
            }
        }
    }
    static getSpacer_(node) {
        if (DomUtil.tagName(node) === MMLTAGS.MSPACE) {
            return node;
        }
        while (SemanticUtil.hasEmptyTag(node) && node.childNodes.length === 1) {
            node = node.childNodes[0];
            if (DomUtil.tagName(node) === MMLTAGS.MSPACE) {
                return node;
            }
        }
        return null;
    }
    static fenceToPunct_(fence) {
        const newRole = SemanticProcessor.FENCE_TO_PUNCT_[fence.role];
        if (!newRole) {
            return;
        }
        while (fence.embellished) {
            fence.embellished = SemanticType.PUNCTUATION;
            if (!(SemanticPred.isRole(fence, SemanticRole.SUBSUP) ||
                SemanticPred.isRole(fence, SemanticRole.UNDEROVER))) {
                fence.role = newRole;
            }
            fence = fence.childNodes[0];
        }
        fence.type = SemanticType.PUNCTUATION;
        fence.role = newRole;
    }
    static classifyFunction_(funcNode, restNodes) {
        if (funcNode.type === SemanticType.APPL ||
            funcNode.type === SemanticType.BIGOP ||
            funcNode.type === SemanticType.INTEGRAL) {
            return '';
        }
        if (restNodes[0] &&
            restNodes[0].textContent === NamedSymbol.functionApplication) {
            SemanticProcessor.getInstance().funcAppls[funcNode.id] =
                restNodes.shift();
            let role = SemanticRole.SIMPLEFUNC;
            SemanticHeuristics.run('simple2prefix', funcNode);
            if (funcNode.role === SemanticRole.PREFIXFUNC ||
                funcNode.role === SemanticRole.LIMFUNC) {
                role = funcNode.role;
            }
            SemanticProcessor.propagateFunctionRole_(funcNode, role);
            return 'prefix';
        }
        const kind = SemanticProcessor.CLASSIFY_FUNCTION_[funcNode.role];
        return kind
            ? kind
            : SemanticPred.isSimpleFunctionHead(funcNode)
                ? 'simple'
                : '';
    }
    static propagateFunctionRole_(funcNode, tag) {
        if (funcNode) {
            if (funcNode.type === SemanticType.INFIXOP) {
                return;
            }
            if (!(SemanticPred.isRole(funcNode, SemanticRole.SUBSUP) ||
                SemanticPred.isRole(funcNode, SemanticRole.UNDEROVER))) {
                funcNode.role = tag;
            }
            SemanticProcessor.propagateFunctionRole_(funcNode.childNodes[0], tag);
        }
    }
    static getFunctionOp_(tree, pred) {
        if (pred(tree)) {
            return tree;
        }
        for (let i = 0, child; (child = tree.childNodes[i]); i++) {
            const op = SemanticProcessor.getFunctionOp_(child, pred);
            if (op) {
                return op;
            }
        }
        return null;
    }
    static tableToMatrixOrVector_(node) {
        const matrix = node.childNodes[0];
        SemanticPred.isType(matrix, SemanticType.MULTILINE)
            ? SemanticProcessor.tableToVector_(node)
            : SemanticProcessor.tableToMatrix_(node);
        node.contentNodes.forEach(matrix.appendContentNode.bind(matrix));
        for (let i = 0, row; (row = matrix.childNodes[i]); i++) {
            SemanticProcessor.assignRoleToRow_(row, SemanticProcessor.getComponentRoles_(matrix));
        }
        matrix.parent = null;
        return matrix;
    }
    static tableToVector_(node) {
        const vector = node.childNodes[0];
        vector.type = SemanticType.VECTOR;
        if (vector.childNodes.length === 1) {
            SemanticProcessor.tableToSquare_(node);
            return;
        }
        SemanticProcessor.binomialForm_(vector);
    }
    static binomialForm_(node) {
        if (!SemanticPred.isRole(node, SemanticRole.UNKNOWN)) {
            return;
        }
        if (SemanticPred.isBinomial(node)) {
            node.role = SemanticRole.BINOMIAL;
            node.childNodes[0].role = SemanticRole.BINOMIAL;
            node.childNodes[1].role = SemanticRole.BINOMIAL;
        }
    }
    static tableToMatrix_(node) {
        const matrix = node.childNodes[0];
        matrix.type = SemanticType.MATRIX;
        if (matrix.childNodes &&
            matrix.childNodes.length > 0 &&
            matrix.childNodes[0].childNodes &&
            matrix.childNodes.length === matrix.childNodes[0].childNodes.length) {
            SemanticProcessor.tableToSquare_(node);
            return;
        }
        if (matrix.childNodes && matrix.childNodes.length === 1) {
            matrix.role = SemanticRole.ROWVECTOR;
        }
    }
    static tableToSquare_(node) {
        const matrix = node.childNodes[0];
        if (!SemanticPred.isRole(matrix, SemanticRole.UNKNOWN)) {
            return;
        }
        if (SemanticPred.isNeutralFence(node)) {
            matrix.role = SemanticRole.DETERMINANT;
            return;
        }
        matrix.role = SemanticRole.SQUAREMATRIX;
    }
    static getComponentRoles_(node) {
        const role = node.role;
        if (role && role !== SemanticRole.UNKNOWN) {
            return role;
        }
        return node.type.toLowerCase() || SemanticRole.UNKNOWN;
    }
    static tableToCases_(table, openFence) {
        for (let i = 0, row; (row = table.childNodes[i]); i++) {
            SemanticProcessor.assignRoleToRow_(row, SemanticRole.CASES);
        }
        table.type = SemanticType.CASES;
        table.appendContentNode(openFence);
        if (SemanticPred.tableIsMultiline(table)) {
            SemanticProcessor.binomialForm_(table);
        }
        return table;
    }
    static rewriteFencedLine_(table) {
        const line = table.childNodes[0];
        const fenced = table.childNodes[0].childNodes[0];
        const element = table.childNodes[0].childNodes[0].childNodes[0];
        fenced.parent = table.parent;
        table.parent = fenced;
        element.parent = line;
        fenced.childNodes = [table];
        line.childNodes = [element];
        return fenced;
    }
    static rowToLine_(row, opt_role) {
        const role = opt_role || SemanticRole.UNKNOWN;
        if (SemanticPred.isType(row, SemanticType.ROW)) {
            row.type = SemanticType.LINE;
            row.role = role;
            if (row.childNodes.length === 1 &&
                SemanticPred.isType(row.childNodes[0], SemanticType.CELL)) {
                row.childNodes = row.childNodes[0].childNodes;
                row.childNodes.forEach(function (x) {
                    x.parent = row;
                });
            }
        }
    }
    static assignRoleToRow_(row, role) {
        if (SemanticPred.isType(row, SemanticType.LINE)) {
            row.role = role;
            return;
        }
        if (SemanticPred.isType(row, SemanticType.ROW)) {
            row.role = role;
            row.childNodes.forEach(function (cell) {
                if (SemanticPred.isType(cell, SemanticType.CELL)) {
                    cell.role = role;
                }
            });
        }
    }
    static nextSeparatorFunction_(separators) {
        let sepList;
        if (separators) {
            if (separators.match(/^\s+$/)) {
                return null;
            }
            else {
                sepList = separators
                    .replace(/\s/g, '')
                    .split('')
                    .filter(function (x) {
                    return x;
                });
            }
        }
        else {
            sepList = [','];
        }
        return function () {
            if (sepList.length > 1) {
                return sepList.shift();
            }
            return sepList[0];
        };
    }
    static meaningFromContent(node, func) {
        const content = [...node.textContent].filter((x) => x.match(/[^\s]/));
        const meaning = content.map((x) => SemanticMap.Meaning.get(x));
        func(node, content, meaning);
    }
    static numberRole_(node, content, meaning) {
        if (node.role !== SemanticRole.UNKNOWN) {
            return;
        }
        if (meaning.every(function (x) {
            return ((x.type === SemanticType.NUMBER && x.role === SemanticRole.INTEGER) ||
                (x.type === SemanticType.PUNCTUATION && x.role === SemanticRole.COMMA));
        })) {
            node.role = SemanticRole.INTEGER;
            if (content[0] === '0') {
                node.addAnnotation('general', 'basenumber');
            }
            return;
        }
        if (meaning.every(function (x) {
            return ((x.type === SemanticType.NUMBER && x.role === SemanticRole.INTEGER) ||
                x.type === SemanticType.PUNCTUATION);
        })) {
            node.role = SemanticRole.FLOAT;
            return;
        }
        node.role = SemanticRole.OTHERNUMBER;
    }
    static exprFont_(node) {
        if (node.font !== SemanticFont.UNKNOWN) {
            return;
        }
        SemanticProcessor.compSemantics(node, 'font', SemanticFont);
    }
    static compSemantics(node, field, sem) {
        const content = [...node.textContent];
        const meaning = content.map((x) => SemanticMap.Meaning.get(x));
        const single = meaning.reduce(function (prev, curr) {
            if (!prev ||
                !curr[field] ||
                curr[field] === sem.UNKNOWN ||
                curr[field] === prev) {
                return prev;
            }
            if (prev === sem.UNKNOWN) {
                return curr[field];
            }
            return null;
        }, sem.UNKNOWN);
        if (single) {
            node[field] = single;
        }
    }
    static purgeFences_(partition) {
        const rel = partition.rel;
        const comp = partition.comp;
        const newRel = [];
        const newComp = [];
        while (rel.length > 0) {
            const currentRel = rel.shift();
            let currentComp = comp.shift();
            if (SemanticPred.isElligibleEmbellishedFence(currentRel)) {
                newRel.push(currentRel);
                newComp.push(currentComp);
                continue;
            }
            SemanticProcessor.fenceToPunct_(currentRel);
            currentComp.push(currentRel);
            currentComp = currentComp.concat(comp.shift());
            comp.unshift(currentComp);
        }
        newComp.push(comp.shift());
        return { rel: newRel, comp: newComp };
    }
    static rewriteFencedNode_(fenced) {
        const ofence = fenced.contentNodes[0];
        const cfence = fenced.contentNodes[1];
        let rewritten = SemanticProcessor.rewriteFence_(fenced, ofence);
        fenced.contentNodes[0] = rewritten.fence;
        rewritten = SemanticProcessor.rewriteFence_(rewritten.node, cfence);
        fenced.contentNodes[1] = rewritten.fence;
        fenced.contentNodes[0].parent = fenced;
        fenced.contentNodes[1].parent = fenced;
        rewritten.node.parent = null;
        return rewritten.node;
    }
    static rewriteFence_(node, fence) {
        if (!fence.embellished) {
            return { node: node, fence: fence };
        }
        const newFence = fence.childNodes[0];
        const rewritten = SemanticProcessor.rewriteFence_(node, newFence);
        if (SemanticPred.isType(fence, SemanticType.SUPERSCRIPT) ||
            SemanticPred.isType(fence, SemanticType.SUBSCRIPT) ||
            SemanticPred.isType(fence, SemanticType.TENSOR)) {
            if (!SemanticPred.isRole(fence, SemanticRole.SUBSUP)) {
                fence.role = node.role;
            }
            if (newFence !== rewritten.node) {
                fence.replaceChild(newFence, rewritten.node);
                newFence.parent = node;
            }
            SemanticProcessor.propagateFencePointer_(fence, newFence);
            return { node: fence, fence: rewritten.fence };
        }
        fence.replaceChild(newFence, rewritten.fence);
        if (fence.mathmlTree && fence.mathml.indexOf(fence.mathmlTree) === -1) {
            fence.mathml.push(fence.mathmlTree);
        }
        return { node: rewritten.node, fence: fence };
    }
    static propagateFencePointer_(oldNode, newNode) {
        oldNode.fencePointer = newNode.fencePointer || newNode.id.toString();
        oldNode.embellished = null;
    }
    static classifyByColumns_(table, columns, relation, alternatives = []) {
        const relations = [relation].concat(alternatives);
        const test1 = (x) => SemanticProcessor.isPureRelation_(x, relations);
        const test2 = (x) => SemanticProcessor.isEndRelation_(x, relations) ||
            SemanticProcessor.isPureRelation_(x, relations);
        const test3 = (x) => SemanticProcessor.isEndRelation_(x, relations, true) ||
            SemanticProcessor.isPureRelation_(x, relations);
        if ((columns.length === 3 &&
            SemanticProcessor.testColumns_(columns, 1, test1)) ||
            (columns.length === 2 &&
                (SemanticProcessor.testColumns_(columns, 1, test2) ||
                    SemanticProcessor.testColumns_(columns, 0, test3)))) {
            table.role = relation;
            return true;
        }
        return false;
    }
    static isEndRelation_(node, relations, opt_right) {
        const position = opt_right ? node.childNodes.length - 1 : 0;
        return (SemanticPred.isType(node, SemanticType.RELSEQ) &&
            relations.some((relation) => SemanticPred.isRole(node, relation)) &&
            SemanticPred.isType(node.childNodes[position], SemanticType.EMPTY));
    }
    static isPureRelation_(node, relations) {
        return (SemanticPred.isType(node, SemanticType.RELATION) &&
            relations.some((relation) => SemanticPred.isRole(node, relation)));
    }
    static computeColumns_(table) {
        const columns = [];
        for (let i = 0, row; (row = table.childNodes[i]); i++) {
            for (let j = 0, cell; (cell = row.childNodes[j]); j++) {
                const column = columns[j];
                column ? columns[j].push(cell) : (columns[j] = [cell]);
            }
        }
        return columns;
    }
    static testColumns_(columns, index, pred) {
        const column = columns[index];
        return column
            ? column.some(function (cell) {
                return (cell.childNodes.length && pred(cell.childNodes[0]));
            }) &&
                column.every(function (cell) {
                    return (!cell.childNodes.length ||
                        pred(cell.childNodes[0]));
                })
            : false;
    }
    setNodeFactory(factory) {
        SemanticProcessor.getInstance().factory_ = factory;
        SemanticHeuristics.updateFactory(SemanticProcessor.getInstance().factory_);
    }
    getNodeFactory() {
        return SemanticProcessor.getInstance().factory_;
    }
    identifierNode(leaf, font, unit) {
        if (unit === 'MathML-Unit') {
            leaf.type = SemanticType.IDENTIFIER;
            leaf.role = SemanticRole.UNIT;
        }
        else if (!font &&
            leaf.textContent.length === 1 &&
            (leaf.role === SemanticRole.INTEGER ||
                leaf.role === SemanticRole.LATINLETTER ||
                leaf.role === SemanticRole.GREEKLETTER) &&
            leaf.font === SemanticFont.NORMAL) {
            leaf.font = SemanticFont.ITALIC;
            return SemanticHeuristics.run('simpleNamedFunction', leaf);
        }
        if (leaf.type === SemanticType.UNKNOWN) {
            leaf.type = SemanticType.IDENTIFIER;
        }
        SemanticProcessor.exprFont_(leaf);
        return SemanticHeuristics.run('simpleNamedFunction', leaf);
    }
    implicitNode(nodes) {
        nodes = SemanticProcessor.getInstance().getMixedNumbers_(nodes);
        nodes = SemanticProcessor.getInstance().combineUnits_(nodes);
        if (nodes.length === 1) {
            return nodes[0];
        }
        const node = SemanticProcessor.getInstance().implicitNode_(nodes);
        return SemanticHeuristics.run('combine_juxtaposition', node);
    }
    text(leaf, type) {
        SemanticProcessor.exprFont_(leaf);
        leaf.type = SemanticType.TEXT;
        if (type === MMLTAGS.ANNOTATIONXML) {
            leaf.role = SemanticRole.ANNOTATION;
            return leaf;
        }
        if (type === MMLTAGS.MS) {
            leaf.role = SemanticRole.STRING;
            return leaf;
        }
        if (type === MMLTAGS.MSPACE || leaf.textContent.match(/^\s*$/)) {
            leaf.role = SemanticRole.SPACE;
            return leaf;
        }
        if (/\s/.exec(leaf.textContent)) {
            leaf.role = SemanticRole.TEXT;
            return leaf;
        }
        leaf.role = SemanticRole.UNKNOWN;
        return leaf;
    }
    row(nodes) {
        nodes = nodes.filter(function (x) {
            return !SemanticPred.isType(x, SemanticType.EMPTY);
        });
        if (nodes.length === 0) {
            return SemanticProcessor.getInstance().factory_.makeEmptyNode();
        }
        nodes = SemanticProcessor.getInstance().getFencesInRow_(nodes);
        nodes = SemanticProcessor.getInstance().tablesInRow(nodes);
        nodes = SemanticProcessor.getInstance().getPunctuationInRow_(nodes);
        nodes = SemanticProcessor.getInstance().getTextInRow_(nodes);
        nodes = SemanticProcessor.getInstance().getFunctionsInRow_(nodes);
        return SemanticProcessor.getInstance().relationsInRow_(nodes);
    }
    limitNode(mmlTag, children) {
        if (!children.length) {
            return SemanticProcessor.getInstance().factory_.makeEmptyNode();
        }
        let center = children[0];
        let type = SemanticType.UNKNOWN;
        if (!children[1]) {
            return center;
        }
        let result;
        SemanticHeuristics.run('op_with_limits', children);
        if (SemanticPred.isLimitBase(center)) {
            result = SemanticProcessor.MML_TO_LIMIT_[mmlTag];
            const length = result.length;
            type = result.type;
            children = children.slice(0, result.length + 1);
            if ((length === 1 && SemanticPred.isAccent(children[1])) ||
                (length === 2 &&
                    SemanticPred.isAccent(children[1]) &&
                    SemanticPred.isAccent(children[2]))) {
                result = SemanticProcessor.MML_TO_BOUNDS_[mmlTag];
                return SemanticProcessor.getInstance().accentNode_(center, children, result.type, result.length, result.accent);
            }
            if (length === 2) {
                if (SemanticPred.isAccent(children[1])) {
                    center = SemanticProcessor.getInstance().accentNode_(center, [center, children[1]], {
                        MSUBSUP: SemanticType.SUBSCRIPT,
                        MUNDEROVER: SemanticType.UNDERSCORE
                    }[mmlTag], 1, true);
                    return !children[2]
                        ? center
                        : SemanticProcessor.getInstance().makeLimitNode_(center, [center, children[2]], null, SemanticType.LIMUPPER);
                }
                if (children[2] && SemanticPred.isAccent(children[2])) {
                    center = SemanticProcessor.getInstance().accentNode_(center, [center, children[2]], {
                        MSUBSUP: SemanticType.SUPERSCRIPT,
                        MUNDEROVER: SemanticType.OVERSCORE
                    }[mmlTag], 1, true);
                    return SemanticProcessor.getInstance().makeLimitNode_(center, [center, children[1]], null, SemanticType.LIMLOWER);
                }
                if (!children[length]) {
                    type = SemanticType.LIMLOWER;
                }
            }
            return SemanticProcessor.getInstance().makeLimitNode_(center, children, null, type);
        }
        result = SemanticProcessor.MML_TO_BOUNDS_[mmlTag];
        return SemanticProcessor.getInstance().accentNode_(center, children, result.type, result.length, result.accent);
    }
    tablesInRow(nodes) {
        let partition = SemanticUtil.partitionNodes(nodes, SemanticPred.tableIsMatrixOrVector);
        let result = [];
        for (let i = 0, matrix; (matrix = partition.rel[i]); i++) {
            result = result.concat(partition.comp.shift());
            result.push(SemanticProcessor.tableToMatrixOrVector_(matrix));
        }
        result = result.concat(partition.comp.shift());
        partition = SemanticUtil.partitionNodes(result, SemanticPred.isTableOrMultiline);
        result = [];
        for (let i = 0, table; (table = partition.rel[i]); i++) {
            const prevNodes = partition.comp.shift();
            if (SemanticPred.tableIsCases(table, prevNodes)) {
                SemanticProcessor.tableToCases_(table, prevNodes.pop());
            }
            result = result.concat(prevNodes);
            result.push(table);
        }
        return result.concat(partition.comp.shift());
    }
    mfenced(open, close, sepValue, children) {
        if (sepValue && children.length > 0) {
            const separators = SemanticProcessor.nextSeparatorFunction_(sepValue);
            const newChildren = [children.shift()];
            children.forEach((child) => {
                newChildren.push(SemanticProcessor.getInstance().factory_.makeContentNode(separators()));
                newChildren.push(child);
            });
            children = newChildren;
        }
        if (open && close) {
            return SemanticProcessor.getInstance().horizontalFencedNode_(SemanticProcessor.getInstance().factory_.makeContentNode(open), SemanticProcessor.getInstance().factory_.makeContentNode(close), children);
        }
        if (open) {
            children.unshift(SemanticProcessor.getInstance().factory_.makeContentNode(open));
        }
        if (close) {
            children.push(SemanticProcessor.getInstance().factory_.makeContentNode(close));
        }
        return SemanticProcessor.getInstance().row(children);
    }
    fractionLikeNode(denom, enume, linethickness, bevelled) {
        let node;
        if (!bevelled && SemanticUtil.isZeroLength(linethickness)) {
            const child0 = SemanticProcessor.getInstance().factory_.makeBranchNode(SemanticType.LINE, [denom], []);
            const child1 = SemanticProcessor.getInstance().factory_.makeBranchNode(SemanticType.LINE, [enume], []);
            node = SemanticProcessor.getInstance().factory_.makeBranchNode(SemanticType.MULTILINE, [child0, child1], []);
            SemanticProcessor.binomialForm_(node);
            SemanticProcessor.classifyMultiline(node);
            return node;
        }
        else {
            node = SemanticProcessor.getInstance().fractionNode_(denom, enume);
            if (bevelled) {
                node.addAnnotation('general', 'bevelled');
            }
            return node;
        }
    }
    tensor(base, lsub, lsup, rsub, rsup) {
        const newNode = SemanticProcessor.getInstance().factory_.makeBranchNode(SemanticType.TENSOR, [
            base,
            SemanticProcessor.getInstance().scriptNode_(lsub, SemanticRole.LEFTSUB),
            SemanticProcessor.getInstance().scriptNode_(lsup, SemanticRole.LEFTSUPER),
            SemanticProcessor.getInstance().scriptNode_(rsub, SemanticRole.RIGHTSUB),
            SemanticProcessor.getInstance().scriptNode_(rsup, SemanticRole.RIGHTSUPER)
        ], []);
        newNode.role = base.role;
        newNode.embellished = SemanticPred.isEmbellished(base);
        return newNode;
    }
    pseudoTensor(base, sub, sup) {
        const isEmpty = (x) => !SemanticPred.isType(x, SemanticType.EMPTY);
        const nonEmptySub = sub.filter(isEmpty).length;
        const nonEmptySup = sup.filter(isEmpty).length;
        if (!nonEmptySub && !nonEmptySup) {
            return base;
        }
        const mmlTag = nonEmptySub
            ? nonEmptySup
                ? MMLTAGS.MSUBSUP
                : MMLTAGS.MSUB
            : MMLTAGS.MSUP;
        const mmlchild = [base];
        if (nonEmptySub) {
            mmlchild.push(SemanticProcessor.getInstance().scriptNode_(sub, SemanticRole.RIGHTSUB, true));
        }
        if (nonEmptySup) {
            mmlchild.push(SemanticProcessor.getInstance().scriptNode_(sup, SemanticRole.RIGHTSUPER, true));
        }
        return SemanticProcessor.getInstance().limitNode(mmlTag, mmlchild);
    }
    font(font) {
        const mathjaxFont = SemanticProcessor.MATHJAX_FONTS[font];
        return mathjaxFont ? mathjaxFont : font;
    }
    proof(node, semantics, parse) {
        if (!semantics['inference'] && !semantics['axiom']) {
            console.log('Noise');
        }
        if (semantics['axiom']) {
            const cleaned = SemanticProcessor.getInstance().cleanInference(node.childNodes);
            const axiom = cleaned.length
                ? SemanticProcessor.getInstance().factory_.makeBranchNode(SemanticType.INFERENCE, parse(cleaned), [])
                : SemanticProcessor.getInstance().factory_.makeEmptyNode();
            axiom.role = SemanticRole.AXIOM;
            axiom.mathmlTree = node;
            return axiom;
        }
        const inference = SemanticProcessor.getInstance().inference(node, semantics, parse);
        if (semantics['proof']) {
            inference.role = SemanticRole.PROOF;
            inference.childNodes[0].role = SemanticRole.FINAL;
        }
        return inference;
    }
    inference(node, semantics, parse) {
        if (semantics['inferenceRule']) {
            const formulas = SemanticProcessor.getInstance().getFormulas(node, [], parse);
            const inference = SemanticProcessor.getInstance().factory_.makeBranchNode(SemanticType.INFERENCE, [formulas.conclusion, formulas.premises], []);
            return inference;
        }
        const label = semantics['labelledRule'];
        const children = DomUtil.toArray(node.childNodes);
        const content = [];
        if (label === 'left' || label === 'both') {
            content.push(SemanticProcessor.getInstance().getLabel(node, children, parse, SemanticRole.LEFT));
        }
        if (label === 'right' || label === 'both') {
            content.push(SemanticProcessor.getInstance().getLabel(node, children, parse, SemanticRole.RIGHT));
        }
        const formulas = SemanticProcessor.getInstance().getFormulas(node, children, parse);
        const inference = SemanticProcessor.getInstance().factory_.makeBranchNode(SemanticType.INFERENCE, [formulas.conclusion, formulas.premises], content);
        inference.mathmlTree = node;
        return inference;
    }
    getLabel(_node, children, parse, side) {
        const label = SemanticProcessor.getInstance().findNestedRow(children, 'prooflabel', side);
        const sem = SemanticProcessor.getInstance().factory_.makeBranchNode(SemanticType.RULELABEL, parse(DomUtil.toArray(label.childNodes)), []);
        sem.role = side;
        sem.mathmlTree = label;
        return sem;
    }
    getFormulas(node, children, parse) {
        const inf = children.length
            ? SemanticProcessor.getInstance().findNestedRow(children, 'inferenceRule')
            : node;
        const up = SemanticProcessor.getSemantics(inf)['inferenceRule'] === 'up';
        const premRow = up ? inf.childNodes[1] : inf.childNodes[0];
        const concRow = up ? inf.childNodes[0] : inf.childNodes[1];
        const premTable = premRow.childNodes[0].childNodes[0];
        const topRow = DomUtil.toArray(premTable.childNodes[0].childNodes);
        const premNodes = [];
        let i = 1;
        for (const cell of topRow) {
            if (i % 2) {
                premNodes.push(cell.childNodes[0]);
            }
            i++;
        }
        const premises = parse(premNodes);
        const conclusion = parse(DomUtil.toArray(concRow.childNodes[0].childNodes))[0];
        const prem = SemanticProcessor.getInstance().factory_.makeBranchNode(SemanticType.PREMISES, premises, []);
        prem.mathmlTree = premTable;
        const conc = SemanticProcessor.getInstance().factory_.makeBranchNode(SemanticType.CONCLUSION, [conclusion], []);
        conc.mathmlTree = concRow.childNodes[0].childNodes[0];
        return { conclusion: conc, premises: prem };
    }
    findNestedRow(nodes, semantic, opt_value) {
        return SemanticProcessor.getInstance().findNestedRow_(nodes, semantic, 0, opt_value);
    }
    cleanInference(nodes) {
        return DomUtil.toArray(nodes).filter(function (x) {
            return DomUtil.tagName(x) !== 'MSPACE';
        });
    }
    operatorNode(node) {
        if (node.type === SemanticType.UNKNOWN) {
            node.type = SemanticType.OPERATOR;
        }
        return SemanticHeuristics.run('multioperator', node);
    }
    constructor() {
        this.funcAppls = {};
        this.splitRoles = new Map([
            [SemanticRole.SUBTRACTION, SemanticRole.NEGATIVE],
            [SemanticRole.ADDITION, SemanticRole.POSITIVE]
        ]);
        this.splitOps = ['−', '-', '‐', '‑', '+'];
        this.factory_ = new SemanticNodeFactory();
        SemanticHeuristics.updateFactory(this.factory_);
    }
    implicitNode_(nodes) {
        const operators = SemanticProcessor.getInstance().factory_.makeMultipleContentNodes(nodes.length - 1, NamedSymbol.invisibleTimes);
        SemanticProcessor.matchSpaces_(nodes, operators);
        const newNode = SemanticProcessor.getInstance().infixNode_(nodes, operators[0]);
        newNode.role = SemanticRole.IMPLICIT;
        operators.forEach(function (op) {
            op.parent = newNode;
        });
        newNode.contentNodes = operators;
        return newNode;
    }
    infixNode_(children, opNode) {
        const node = SemanticProcessor.getInstance().factory_.makeBranchNode(SemanticType.INFIXOP, children, [opNode], SemanticUtil.getEmbellishedInner(opNode).textContent);
        node.role = opNode.role;
        return SemanticHeuristics.run('propagateSimpleFunction', node);
    }
    explicitMixed_(nodes) {
        const partition = SemanticUtil.partitionNodes(nodes, function (x) {
            return x.textContent === NamedSymbol.invisiblePlus;
        });
        if (!partition.rel.length) {
            return nodes;
        }
        let result = [];
        for (let i = 0, rel; (rel = partition.rel[i]); i++) {
            const prev = partition.comp[i];
            const next = partition.comp[i + 1];
            const last = prev.length - 1;
            if (prev[last] &&
                next[0] &&
                SemanticPred.isType(prev[last], SemanticType.NUMBER) &&
                !SemanticPred.isRole(prev[last], SemanticRole.MIXED) &&
                SemanticPred.isType(next[0], SemanticType.FRACTION)) {
                const newNode = SemanticProcessor.getInstance().factory_.makeBranchNode(SemanticType.NUMBER, [prev[last], next[0]], []);
                newNode.role = SemanticRole.MIXED;
                result = result.concat(prev.slice(0, last));
                result.push(newNode);
                next.shift();
            }
            else {
                result = result.concat(prev);
                result.push(rel);
            }
        }
        return result.concat(partition.comp[partition.comp.length - 1]);
    }
    concatNode_(inner, nodeList, type) {
        if (nodeList.length === 0) {
            return inner;
        }
        const content = nodeList
            .map(function (x) {
            return SemanticUtil.getEmbellishedInner(x).textContent;
        })
            .join(' ');
        const newNode = SemanticProcessor.getInstance().factory_.makeBranchNode(type, [inner], nodeList, content);
        if (nodeList.length > 1) {
            newNode.role = SemanticRole.MULTIOP;
        }
        return newNode;
    }
    prefixNode_(node, prefixes) {
        const newPrefixes = this.splitSingles(prefixes);
        let newNode = node;
        while (newPrefixes.length > 0) {
            const op = newPrefixes.pop();
            newNode = SemanticProcessor.getInstance().concatNode_(newNode, op, SemanticType.PREFIXOP);
            if (op.length === 1 && this.splitOps.indexOf(op[0].textContent) !== -1) {
                newNode.role = this.splitRoles.get(op[0].role);
            }
        }
        return newNode;
    }
    splitSingles(prefixes) {
        let lastOp = 0;
        const result = [];
        let i = 0;
        while (i < prefixes.length) {
            const op = prefixes[i];
            if (this.splitRoles.has(op.role) &&
                (!prefixes[i - 1] || prefixes[i - 1].role !== op.role) &&
                (!prefixes[i + 1] || prefixes[i + 1].role !== op.role) &&
                this.splitOps.indexOf(op.textContent) !== -1) {
                result.push(prefixes.slice(lastOp, i));
                result.push(prefixes.slice(i, i + 1));
                lastOp = i + 1;
            }
            i++;
        }
        if (lastOp < i) {
            result.push(prefixes.slice(lastOp, i));
        }
        return result;
    }
    postfixNode_(node, postfixes) {
        if (!postfixes.length) {
            return node;
        }
        return SemanticProcessor.getInstance().concatNode_(node, postfixes, SemanticType.POSTFIXOP);
    }
    combineUnits_(nodes) {
        const partition = SemanticUtil.partitionNodes(nodes, function (x) {
            return !SemanticPred.isRole(x, SemanticRole.UNIT);
        });
        if (nodes.length === partition.rel.length) {
            return partition.rel;
        }
        const result = [];
        let rel;
        let last;
        do {
            const comp = partition.comp.shift();
            rel = partition.rel.shift();
            let unitNode = null;
            last = result.pop();
            if (last) {
                if (!comp.length || !SemanticPred.isUnitCounter(last)) {
                    result.push(last);
                }
                else {
                    comp.unshift(last);
                }
            }
            if (comp.length === 1) {
                unitNode = comp.pop();
            }
            if (comp.length > 1) {
                unitNode = SemanticProcessor.getInstance().implicitNode_(comp);
                unitNode.role = SemanticRole.UNIT;
            }
            if (unitNode) {
                result.push(unitNode);
            }
            if (rel) {
                result.push(rel);
            }
        } while (rel);
        return result;
    }
    getMixedNumbers_(nodes) {
        const partition = SemanticUtil.partitionNodes(nodes, function (x) {
            return (SemanticPred.isType(x, SemanticType.FRACTION) &&
                SemanticPred.isRole(x, SemanticRole.VULGAR));
        });
        if (!partition.rel.length) {
            return nodes;
        }
        let result = [];
        for (let i = 0, rel; (rel = partition.rel[i]); i++) {
            const comp = partition.comp[i];
            const last = comp.length - 1;
            if (comp[last] &&
                SemanticPred.isType(comp[last], SemanticType.NUMBER) &&
                (SemanticPred.isRole(comp[last], SemanticRole.INTEGER) ||
                    SemanticPred.isRole(comp[last], SemanticRole.FLOAT))) {
                const newNode = SemanticProcessor.getInstance().factory_.makeBranchNode(SemanticType.NUMBER, [comp[last], rel], []);
                newNode.role = SemanticRole.MIXED;
                result = result.concat(comp.slice(0, last));
                result.push(newNode);
            }
            else {
                result = result.concat(comp);
                result.push(rel);
            }
        }
        return result.concat(partition.comp[partition.comp.length - 1]);
    }
    getTextInRow_(nodes) {
        if (nodes.length === 0) {
            return nodes;
        }
        if (nodes.length === 1) {
            if (nodes[0].type === SemanticType.TEXT &&
                nodes[0].role === SemanticRole.UNKNOWN) {
                nodes[0].role = SemanticRole.ANNOTATION;
            }
            return nodes;
        }
        const { rel: rel, comp: comp } = SemanticUtil.partitionNodes(nodes, (x) => SemanticPred.isType(x, SemanticType.TEXT));
        if (rel.length === 0) {
            return nodes;
        }
        const result = [];
        let prevComp = comp.shift();
        while (rel.length > 0) {
            let currentRel = rel.shift();
            let nextComp = comp.shift();
            const text = [];
            while (!nextComp.length &&
                rel.length &&
                currentRel.role !== SemanticRole.SPACE &&
                rel[0].role !== SemanticRole.SPACE) {
                text.push(currentRel);
                currentRel = rel.shift();
                nextComp = comp.shift();
            }
            if (text.length) {
                if (prevComp.length) {
                    result.push(SemanticProcessor.getInstance().row(prevComp));
                }
                text.push(currentRel);
                const dummy = SemanticProcessor.getInstance().dummyNode_(text);
                result.push(dummy);
                prevComp = nextComp;
                continue;
            }
            if (currentRel.role !== SemanticRole.UNKNOWN) {
                if (prevComp.length) {
                    result.push(SemanticProcessor.getInstance().row(prevComp));
                }
                result.push(currentRel);
                prevComp = nextComp;
                continue;
            }
            const meaning = SemanticMap.Meaning.get(currentRel.textContent);
            if (meaning.type === SemanticType.PUNCTUATION) {
                currentRel.role = meaning.role;
                currentRel.font = meaning.font;
                if (prevComp.length) {
                    result.push(SemanticProcessor.getInstance().row(prevComp));
                }
                result.push(currentRel);
                prevComp = nextComp;
                continue;
            }
            if (meaning.type !== SemanticType.UNKNOWN) {
                currentRel.type = meaning.type;
                currentRel.role = meaning.role;
                currentRel.font = meaning.font;
                currentRel.addAnnotation('general', 'text');
                prevComp.push(currentRel);
                prevComp = prevComp.concat(nextComp);
                continue;
            }
            SemanticProcessor.meaningFromContent(currentRel, (n, c, m) => {
                if (n.role !== SemanticRole.UNKNOWN) {
                    return;
                }
                SemanticProcessor.numberRole_(n, c, m);
                if (n.role !== SemanticRole.OTHERNUMBER) {
                    n.type = SemanticType.NUMBER;
                    return;
                }
                if (m.some((x) => x.type !== SemanticType.NUMBER &&
                    x.type !== SemanticType.IDENTIFIER)) {
                    n.type = SemanticType.TEXT;
                    n.role = SemanticRole.ANNOTATION;
                    return;
                }
                n.role = SemanticRole.UNKNOWN;
            });
            if (currentRel.type === SemanticType.TEXT &&
                currentRel.role !== SemanticRole.UNKNOWN) {
                if (prevComp.length) {
                    result.push(SemanticProcessor.getInstance().row(prevComp));
                }
                result.push(currentRel);
                prevComp = nextComp;
                continue;
            }
            if (currentRel.role === SemanticRole.UNKNOWN) {
                if (rel.length || nextComp.length) {
                    if (nextComp.length && nextComp[0].type === SemanticType.FENCED) {
                        currentRel.type = SemanticType.FUNCTION;
                        currentRel.role = SemanticRole.PREFIXFUNC;
                    }
                    else {
                        currentRel.role = SemanticRole.TEXT;
                    }
                }
                else {
                    currentRel.type = SemanticType.IDENTIFIER;
                    currentRel.role = SemanticRole.UNIT;
                }
            }
            prevComp.push(currentRel);
            prevComp = prevComp.concat(nextComp);
        }
        if (prevComp.length > 0) {
            result.push(SemanticProcessor.getInstance().row(prevComp));
        }
        return result.length > 1
            ? [SemanticProcessor.getInstance().dummyNode_(result)]
            : result;
    }
    relationsInRow_(nodes) {
        const partition = SemanticUtil.partitionNodes(nodes, SemanticPred.isRelation);
        const firstRel = partition.rel[0];
        if (!firstRel) {
            return SemanticProcessor.getInstance().operationsInRow_(nodes);
        }
        if (nodes.length === 1) {
            return nodes[0];
        }
        const children = partition.comp.map(SemanticProcessor.getInstance().operationsInRow_);
        let node;
        if (partition.rel.some(function (x) {
            return !x.equals(firstRel);
        })) {
            node = SemanticProcessor.getInstance().factory_.makeBranchNode(SemanticType.MULTIREL, children, partition.rel);
            if (partition.rel.every(function (x) {
                return x.role === firstRel.role;
            })) {
                node.role = firstRel.role;
            }
            return node;
        }
        node = SemanticProcessor.getInstance().factory_.makeBranchNode(SemanticType.RELSEQ, children, partition.rel, SemanticUtil.getEmbellishedInner(firstRel).textContent);
        node.role = firstRel.role;
        return node;
    }
    operationsInRow_(nodes) {
        if (nodes.length === 0) {
            return SemanticProcessor.getInstance().factory_.makeEmptyNode();
        }
        nodes = SemanticProcessor.getInstance().explicitMixed_(nodes);
        if (nodes.length === 1) {
            return nodes[0];
        }
        const prefix = [];
        while (nodes.length > 0 && SemanticPred.isOperator(nodes[0])) {
            prefix.push(nodes.shift());
        }
        if (nodes.length === 0) {
            return SemanticProcessor.getInstance().prefixNode_(prefix.pop(), prefix);
        }
        if (nodes.length === 1) {
            return SemanticProcessor.getInstance().prefixNode_(nodes[0], prefix);
        }
        nodes = SemanticHeuristics.run('convert_juxtaposition', nodes);
        const split = SemanticUtil.sliceNodes(nodes, SemanticPred.isOperator);
        const node = SemanticProcessor.getInstance().wrapFactor(prefix, split);
        return SemanticProcessor.getInstance().addFactor(node, split);
    }
    wrapPostfix(split) {
        var _a;
        if (((_a = split.div) === null || _a === void 0 ? void 0 : _a.role) === SemanticRole.POSTFIXOP) {
            if (!split.tail.length || split.tail[0].type === SemanticType.OPERATOR) {
                split.head = [
                    SemanticProcessor.getInstance().postfixNode_(SemanticProcessor.getInstance().implicitNode(split.head), [split.div])
                ];
                split.div = split.tail.shift();
                SemanticProcessor.getInstance().wrapPostfix(split);
            }
            else {
                split.div.role = SemanticRole.DIVISION;
            }
        }
    }
    wrapFactor(prefix, split) {
        SemanticProcessor.getInstance().wrapPostfix(split);
        return SemanticProcessor.getInstance().prefixNode_(SemanticProcessor.getInstance().implicitNode(split.head), prefix);
    }
    addFactor(node, split) {
        if (!split.div) {
            if (SemanticPred.isUnitProduct(node)) {
                node.role = SemanticRole.UNIT;
            }
            return node;
        }
        return SemanticProcessor.getInstance().operationsTree_(split.tail, node, split.div);
    }
    operationsTree_(nodes, root, lastop, prefix = []) {
        if (nodes.length === 0) {
            prefix.unshift(lastop);
            if (root.type === SemanticType.INFIXOP) {
                const node = SemanticProcessor.getInstance().postfixNode_(root.childNodes.pop(), prefix);
                root.appendChild(node);
                return root;
            }
            return SemanticProcessor.getInstance().postfixNode_(root, prefix);
        }
        const split = SemanticUtil.sliceNodes(nodes, SemanticPred.isOperator);
        if (split.head.length === 0) {
            prefix.push(split.div);
            return SemanticProcessor.getInstance().operationsTree_(split.tail, root, lastop, prefix);
        }
        const node = SemanticProcessor.getInstance().wrapFactor(prefix, split);
        const newNode = SemanticProcessor.getInstance().appendOperand_(root, lastop, node);
        return SemanticProcessor.getInstance().addFactor(newNode, split);
    }
    appendOperand_(root, op, node) {
        if (root.type !== SemanticType.INFIXOP) {
            return SemanticProcessor.getInstance().infixNode_([root, node], op);
        }
        const division = SemanticProcessor.getInstance().appendDivisionOp_(root, op, node);
        if (division) {
            return division;
        }
        if (SemanticProcessor.getInstance().appendExistingOperator_(root, op, node)) {
            return root;
        }
        return op.role === SemanticRole.MULTIPLICATION
            ? SemanticProcessor.getInstance().appendMultiplicativeOp_(root, op, node)
            : SemanticProcessor.getInstance().appendAdditiveOp_(root, op, node);
    }
    appendDivisionOp_(root, op, node) {
        if (op.role === SemanticRole.DIVISION) {
            if (SemanticPred.isImplicit(root)) {
                return SemanticProcessor.getInstance().infixNode_([root, node], op);
            }
            return SemanticProcessor.getInstance().appendLastOperand_(root, op, node);
        }
        return root.role === SemanticRole.DIVISION
            ? SemanticProcessor.getInstance().infixNode_([root, node], op)
            : null;
    }
    appendLastOperand_(root, op, node) {
        let lastRoot = root;
        let lastChild = root.childNodes[root.childNodes.length - 1];
        while (lastChild &&
            lastChild.type === SemanticType.INFIXOP &&
            !SemanticPred.isImplicit(lastChild)) {
            lastRoot = lastChild;
            lastChild = lastRoot.childNodes[root.childNodes.length - 1];
        }
        const newNode = SemanticProcessor.getInstance().infixNode_([lastRoot.childNodes.pop(), node], op);
        lastRoot.appendChild(newNode);
        return root;
    }
    appendMultiplicativeOp_(root, op, node) {
        if (SemanticPred.isImplicit(root)) {
            return SemanticProcessor.getInstance().infixNode_([root, node], op);
        }
        let lastRoot = root;
        let lastChild = root.childNodes[root.childNodes.length - 1];
        while (lastChild &&
            lastChild.type === SemanticType.INFIXOP &&
            !SemanticPred.isImplicit(lastChild)) {
            lastRoot = lastChild;
            lastChild = lastRoot.childNodes[root.childNodes.length - 1];
        }
        const newNode = SemanticProcessor.getInstance().infixNode_([lastRoot.childNodes.pop(), node], op);
        lastRoot.appendChild(newNode);
        return root;
    }
    appendAdditiveOp_(root, op, node) {
        return SemanticProcessor.getInstance().infixNode_([root, node], op);
    }
    appendExistingOperator_(root, op, node) {
        if (!root ||
            root.type !== SemanticType.INFIXOP ||
            SemanticPred.isImplicit(root)) {
            return false;
        }
        if (root.contentNodes[0].equals(op)) {
            root.appendContentNode(op);
            root.appendChild(node);
            return true;
        }
        return SemanticProcessor.getInstance().appendExistingOperator_(root.childNodes[root.childNodes.length - 1], op, node);
    }
    getFencesInRow_(nodes) {
        let partition = SemanticUtil.partitionNodes(nodes, SemanticPred.isFence);
        partition = SemanticProcessor.purgeFences_(partition);
        const felem = partition.comp.shift();
        return SemanticProcessor.getInstance().fences_(partition.rel, partition.comp, [], [felem]);
    }
    fences_(fences, content, openStack, contentStack) {
        if (fences.length === 0 && openStack.length === 0) {
            return contentStack[0];
        }
        const interval = SemanticHeuristics.run('bracketed_interval', [fences[0], fences[1], ...(content[0] || [])], () => null);
        if (interval) {
            fences.shift();
            fences.shift();
            content.shift();
            const stack = contentStack.pop() || [];
            contentStack.push([...stack, interval, ...content.shift()]);
            return SemanticProcessor.getInstance().fences_(fences, content, openStack, contentStack);
        }
        const openPred = (x) => SemanticPred.isRole(x, SemanticRole.OPEN);
        if (fences.length === 0) {
            const result = contentStack.shift();
            while (openStack.length > 0) {
                if (openPred(openStack[0])) {
                    const firstOpen = openStack.shift();
                    SemanticProcessor.fenceToPunct_(firstOpen);
                    result.push(firstOpen);
                }
                else {
                    const split = SemanticUtil.sliceNodes(openStack, openPred);
                    const cutLength = split.head.length - 1;
                    const innerNodes = SemanticProcessor.getInstance().neutralFences_(split.head, contentStack.slice(0, cutLength));
                    contentStack = contentStack.slice(cutLength);
                    result.push(...innerNodes);
                    if (split.div) {
                        split.tail.unshift(split.div);
                    }
                    openStack = split.tail;
                }
                result.push(...contentStack.shift());
            }
            return result;
        }
        const lastOpen = openStack[openStack.length - 1];
        const firstRole = fences[0].role;
        if (firstRole === SemanticRole.OPEN ||
            (SemanticPred.isNeutralFence(fences[0]) &&
                !(lastOpen && SemanticPred.compareNeutralFences(fences[0], lastOpen)))) {
            openStack.push(fences.shift());
            const cont = content.shift();
            if (cont) {
                contentStack.push(cont);
            }
            return SemanticProcessor.getInstance().fences_(fences, content, openStack, contentStack);
        }
        if (lastOpen &&
            firstRole === SemanticRole.CLOSE &&
            lastOpen.role === SemanticRole.OPEN) {
            const fenced = SemanticProcessor.getInstance().horizontalFencedNode_(openStack.pop(), fences.shift(), contentStack.pop());
            contentStack.push(contentStack.pop().concat([fenced], content.shift()));
            return SemanticProcessor.getInstance().fences_(fences, content, openStack, contentStack);
        }
        if (lastOpen &&
            SemanticPred.compareNeutralFences(fences[0], lastOpen)) {
            if (!SemanticPred.elligibleLeftNeutral(lastOpen) ||
                !SemanticPred.elligibleRightNeutral(fences[0])) {
                openStack.push(fences.shift());
                const cont = content.shift();
                if (cont) {
                    contentStack.push(cont);
                }
                return SemanticProcessor.getInstance().fences_(fences, content, openStack, contentStack);
            }
            const fenced = SemanticProcessor.getInstance().horizontalFencedNode_(openStack.pop(), fences.shift(), contentStack.pop());
            contentStack.push(contentStack.pop().concat([fenced], content.shift()));
            return SemanticProcessor.getInstance().fences_(fences, content, openStack, contentStack);
        }
        if (lastOpen &&
            firstRole === SemanticRole.CLOSE &&
            SemanticPred.isNeutralFence(lastOpen) &&
            openStack.some(openPred)) {
            const split = SemanticUtil.sliceNodes(openStack, openPred, true);
            const rightContent = contentStack.pop();
            const cutLength = contentStack.length - split.tail.length + 1;
            const innerNodes = SemanticProcessor.getInstance().neutralFences_(split.tail, contentStack.slice(cutLength));
            contentStack = contentStack.slice(0, cutLength);
            const fenced = SemanticProcessor.getInstance().horizontalFencedNode_(split.div, fences.shift(), contentStack.pop().concat(innerNodes, rightContent));
            contentStack.push(contentStack.pop().concat([fenced], content.shift()));
            return SemanticProcessor.getInstance().fences_(fences, content, split.head, contentStack);
        }
        const fenced = fences.shift();
        SemanticProcessor.fenceToPunct_(fenced);
        contentStack.push(contentStack.pop().concat([fenced], content.shift()));
        return SemanticProcessor.getInstance().fences_(fences, content, openStack, contentStack);
    }
    neutralFences_(fences, content) {
        if (fences.length === 0) {
            return fences;
        }
        if (fences.length === 1) {
            SemanticProcessor.fenceToPunct_(fences[0]);
            return fences;
        }
        const firstFence = fences.shift();
        if (!SemanticPred.elligibleLeftNeutral(firstFence)) {
            SemanticProcessor.fenceToPunct_(firstFence);
            const restContent = content.shift();
            restContent.unshift(firstFence);
            return restContent.concat(SemanticProcessor.getInstance().neutralFences_(fences, content));
        }
        const split = SemanticUtil.sliceNodes(fences, function (x) {
            return SemanticPred.compareNeutralFences(x, firstFence);
        });
        if (!split.div) {
            SemanticProcessor.fenceToPunct_(firstFence);
            const restContent = content.shift();
            restContent.unshift(firstFence);
            return restContent.concat(SemanticProcessor.getInstance().neutralFences_(fences, content));
        }
        if (!SemanticPred.elligibleRightNeutral(split.div)) {
            SemanticProcessor.fenceToPunct_(split.div);
            fences.unshift(firstFence);
            return SemanticProcessor.getInstance().neutralFences_(fences, content);
        }
        const newContent = SemanticProcessor.getInstance().combineFencedContent_(firstFence, split.div, split.head, content);
        if (split.tail.length > 0) {
            const leftContent = newContent.shift();
            const result = SemanticProcessor.getInstance().neutralFences_(split.tail, newContent);
            return leftContent.concat(result);
        }
        return newContent[0];
    }
    combineFencedContent_(leftFence, rightFence, midFences, content) {
        if (midFences.length === 0) {
            const fenced = SemanticProcessor.getInstance().horizontalFencedNode_(leftFence, rightFence, content.shift());
            if (content.length > 0) {
                content[0].unshift(fenced);
            }
            else {
                content = [[fenced]];
            }
            return content;
        }
        const leftContent = content.shift();
        const cutLength = midFences.length - 1;
        const midContent = content.slice(0, cutLength);
        content = content.slice(cutLength);
        const rightContent = content.shift();
        const innerNodes = SemanticProcessor.getInstance().neutralFences_(midFences, midContent);
        leftContent.push(...innerNodes);
        leftContent.push(...rightContent);
        const fenced = SemanticProcessor.getInstance().horizontalFencedNode_(leftFence, rightFence, leftContent);
        if (content.length > 0) {
            content[0].unshift(fenced);
        }
        else {
            content = [[fenced]];
        }
        return content;
    }
    horizontalFencedNode_(ofence, cfence, content) {
        const childNode = SemanticProcessor.getInstance().row(content);
        let newNode = SemanticProcessor.getInstance().factory_.makeBranchNode(SemanticType.FENCED, [childNode], [ofence, cfence]);
        if (ofence.role === SemanticRole.OPEN) {
            SemanticProcessor.getInstance().classifyHorizontalFence_(newNode);
            newNode = SemanticHeuristics.run('propagateComposedFunction', newNode);
        }
        else {
            newNode.role = ofence.role;
        }
        newNode = SemanticHeuristics.run('detect_cycle', newNode);
        return SemanticProcessor.rewriteFencedNode_(newNode);
    }
    classifyHorizontalFence_(node) {
        node.role = SemanticRole.LEFTRIGHT;
        const children = node.childNodes;
        if (!SemanticPred.isSetNode(node) || children.length > 1) {
            return;
        }
        if (children.length === 0 || children[0].type === SemanticType.EMPTY) {
            node.role = SemanticRole.SETEMPTY;
            return;
        }
        const type = children[0].type;
        if (children.length === 1 &&
            SemanticPred.isSingletonSetContent(children[0])) {
            node.role = SemanticRole.SETSINGLE;
            return;
        }
        const role = children[0].role;
        if (type !== SemanticType.PUNCTUATED || role !== SemanticRole.SEQUENCE) {
            return;
        }
        if (children[0].contentNodes[0].role === SemanticRole.COMMA) {
            node.role = SemanticRole.SETCOLLECT;
            return;
        }
        if (children[0].contentNodes.length === 1 &&
            (children[0].contentNodes[0].role === SemanticRole.VBAR ||
                children[0].contentNodes[0].role === SemanticRole.COLON)) {
            node.role = SemanticRole.SETEXT;
            SemanticProcessor.getInstance().setExtension_(node);
            return;
        }
    }
    setExtension_(set) {
        const extender = set.childNodes[0].childNodes[0];
        if (extender &&
            extender.type === SemanticType.INFIXOP &&
            extender.contentNodes.length === 1 &&
            SemanticPred.isMembership(extender.contentNodes[0])) {
            extender.addAnnotation('set', 'intensional');
            extender.contentNodes[0].addAnnotation('set', 'intensional');
        }
    }
    getPunctuationInRow_(nodes) {
        if (nodes.length <= 1) {
            return nodes;
        }
        const allowedType = (x) => {
            const type = x.type;
            return (type === 'punctuation' ||
                type === 'text' ||
                type === 'operator' ||
                type === 'relation');
        };
        const partition = SemanticUtil.partitionNodes(nodes, function (x) {
            if (!SemanticPred.isPunctuation(x)) {
                return false;
            }
            if (SemanticPred.isPunctuation(x) &&
                !SemanticPred.isRole(x, SemanticRole.ELLIPSIS)) {
                return true;
            }
            const index = nodes.indexOf(x);
            if (index === 0) {
                if (nodes[1] && allowedType(nodes[1])) {
                    return false;
                }
                return true;
            }
            const prev = nodes[index - 1];
            if (index === nodes.length - 1) {
                if (allowedType(prev)) {
                    return false;
                }
                return true;
            }
            const next = nodes[index + 1];
            if (allowedType(prev) && allowedType(next)) {
                return false;
            }
            return true;
        });
        if (partition.rel.length === 0) {
            return nodes;
        }
        let newNodes = [];
        let firstComp = partition.comp.shift();
        if (firstComp.length > 0) {
            newNodes.push(SemanticProcessor.getInstance().row(firstComp));
        }
        let relCounter = 0;
        while (partition.comp.length > 0) {
            let puncts = [];
            const saveCount = relCounter;
            do {
                puncts.push(partition.rel[relCounter++]);
                firstComp = partition.comp.shift();
            } while (partition.rel[relCounter] &&
                firstComp &&
                firstComp.length === 0);
            puncts = SemanticHeuristics.run('ellipses', puncts);
            partition.rel.splice(saveCount, relCounter - saveCount, ...puncts);
            relCounter = saveCount + puncts.length;
            newNodes = newNodes.concat(puncts);
            if (firstComp && firstComp.length > 0) {
                newNodes.push(SemanticProcessor.getInstance().row(firstComp));
            }
        }
        return newNodes.length === 1 && partition.rel.length === 1
            ? newNodes
            : [
                SemanticProcessor.getInstance().punctuatedNode_(newNodes, partition.rel)
            ];
    }
    punctuatedNode_(nodes, punctuations) {
        const newNode = SemanticProcessor.getInstance().factory_.makeBranchNode(SemanticType.PUNCTUATED, nodes, punctuations);
        if (punctuations.length === nodes.length) {
            const firstRole = punctuations[0].role;
            if (firstRole !== SemanticRole.UNKNOWN &&
                punctuations.every(function (punct) {
                    return punct.role === firstRole;
                })) {
                newNode.role = firstRole;
                return newNode;
            }
        }
        const fpunct = punctuations[0];
        if (SemanticPred.singlePunctAtPosition(nodes, punctuations, 0)) {
            newNode.role =
                fpunct.childNodes.length && !fpunct.embellished
                    ? fpunct.role
                    : SemanticRole.STARTPUNCT;
        }
        else if (SemanticPred.singlePunctAtPosition(nodes, punctuations, nodes.length - 1)) {
            newNode.role =
                fpunct.childNodes.length && !fpunct.embellished
                    ? fpunct.role
                    : SemanticRole.ENDPUNCT;
        }
        else if (punctuations.every((x) => SemanticPred.isRole(x, SemanticRole.DUMMY))) {
            newNode.role = SemanticRole.TEXT;
        }
        else if (punctuations.every((x) => SemanticPred.isRole(x, SemanticRole.SPACE))) {
            newNode.role = SemanticRole.SPACE;
        }
        else {
            newNode.role = SemanticRole.SEQUENCE;
        }
        return newNode;
    }
    dummyNode_(children) {
        const commata = SemanticProcessor.getInstance().factory_.makeMultipleContentNodes(children.length - 1, NamedSymbol.invisibleComma);
        commata.forEach(function (comma) {
            comma.role = SemanticRole.DUMMY;
        });
        return SemanticProcessor.getInstance().punctuatedNode_(children, commata);
    }
    accentRole_(node, type) {
        if (!SemanticPred.isAccent(node)) {
            return false;
        }
        const content = node.textContent;
        const role = SemanticMap.Secondary.get(content, SemanticSecondary.BAR) ||
            SemanticMap.Secondary.get(content, SemanticSecondary.TILDE) ||
            node.role;
        node.role =
            type === SemanticType.UNDERSCORE
                ? SemanticRole.UNDERACCENT
                : SemanticRole.OVERACCENT;
        node.addAnnotation('accent', role);
        return true;
    }
    accentNode_(center, children, type, length, accent) {
        children = children.slice(0, length + 1);
        const child1 = children[1];
        const child2 = children[2];
        let innerNode;
        if (!accent && child2) {
            innerNode = SemanticProcessor.getInstance().factory_.makeBranchNode(SemanticType.SUBSCRIPT, [center, child1], []);
            innerNode.role = SemanticRole.SUBSUP;
            children = [innerNode, child2];
            type = SemanticType.SUPERSCRIPT;
        }
        if (accent) {
            const underAccent = SemanticProcessor.getInstance().accentRole_(child1, type);
            if (child2) {
                const overAccent = SemanticProcessor.getInstance().accentRole_(child2, SemanticType.OVERSCORE);
                if (overAccent && !underAccent) {
                    innerNode = SemanticProcessor.getInstance().factory_.makeBranchNode(SemanticType.OVERSCORE, [center, child2], []);
                    children = [innerNode, child1];
                    type = SemanticType.UNDERSCORE;
                }
                else {
                    innerNode = SemanticProcessor.getInstance().factory_.makeBranchNode(SemanticType.UNDERSCORE, [center, child1], []);
                    children = [innerNode, child2];
                    type = SemanticType.OVERSCORE;
                }
                innerNode.role = SemanticRole.UNDEROVER;
            }
        }
        return SemanticProcessor.getInstance().makeLimitNode_(center, children, innerNode, type);
    }
    makeLimitNode_(center, children, innerNode, type) {
        if (type === SemanticType.LIMUPPER &&
            center.type === SemanticType.LIMLOWER) {
            center.childNodes.push(children[1]);
            children[1].parent = center;
            center.type = SemanticType.LIMBOTH;
            return center;
        }
        if (type === SemanticType.LIMLOWER &&
            center.type === SemanticType.LIMUPPER) {
            center.childNodes.splice(1, -1, children[1]);
            children[1].parent = center;
            center.type = SemanticType.LIMBOTH;
            return center;
        }
        const newNode = SemanticProcessor.getInstance().factory_.makeBranchNode(type, children, []);
        const embellished = SemanticPred.isEmbellished(center);
        if (innerNode) {
            innerNode.embellished = embellished;
        }
        newNode.embellished = embellished;
        newNode.role = center.role;
        return newNode;
    }
    getFunctionsInRow_(restNodes, opt_result) {
        const result = opt_result || [];
        if (restNodes.length === 0) {
            return result;
        }
        const firstNode = restNodes.shift();
        const heuristic = SemanticProcessor.classifyFunction_(firstNode, restNodes);
        if (!heuristic) {
            result.push(firstNode);
            return SemanticProcessor.getInstance().getFunctionsInRow_(restNodes, result);
        }
        const processedRest = SemanticProcessor.getInstance().getFunctionsInRow_(restNodes, []);
        const newRest = SemanticProcessor.getInstance().getFunctionArgs_(firstNode, processedRest, heuristic);
        return result.concat(newRest);
    }
    getFunctionArgs_(func, rest, heuristic) {
        let partition, arg, funcNode;
        switch (heuristic) {
            case 'integral': {
                const components = SemanticProcessor.getInstance().getIntegralArgs_(rest);
                if (!components.intvar && !components.integrand.length) {
                    components.rest.unshift(func);
                    return components.rest;
                }
                const integrand = SemanticProcessor.getInstance().row(components.integrand);
                funcNode = SemanticProcessor.getInstance().integralNode_(func, integrand, components.intvar);
                SemanticHeuristics.run('intvar_from_fraction', funcNode);
                components.rest.unshift(funcNode);
                return components.rest;
            }
            case 'prefix': {
                if (rest[0] && rest[0].type === SemanticType.FENCED) {
                    const arg = rest.shift();
                    if (!SemanticPred.isNeutralFence(arg)) {
                        arg.role = SemanticRole.LEFTRIGHT;
                    }
                    funcNode = SemanticProcessor.getInstance().functionNode_(func, arg);
                    rest.unshift(funcNode);
                    return rest;
                }
                partition = SemanticUtil.sliceNodes(rest, SemanticPred.isPrefixFunctionBoundary);
                if (!partition.head.length) {
                    if (!partition.div ||
                        !SemanticPred.isType(partition.div, SemanticType.APPL)) {
                        rest.unshift(func);
                        return rest;
                    }
                    arg = partition.div;
                }
                else {
                    arg = SemanticProcessor.getInstance().row(partition.head);
                    if (partition.div) {
                        partition.tail.unshift(partition.div);
                    }
                }
                funcNode = SemanticProcessor.getInstance().functionNode_(func, arg);
                partition.tail.unshift(funcNode);
                return partition.tail;
            }
            case 'bigop': {
                partition = SemanticUtil.sliceNodes(rest, SemanticPred.isBigOpBoundary);
                if (!partition.head.length) {
                    rest.unshift(func);
                    return rest;
                }
                arg = SemanticProcessor.getInstance().row(partition.head);
                funcNode = SemanticProcessor.getInstance().bigOpNode_(func, arg);
                if (partition.div) {
                    partition.tail.unshift(partition.div);
                }
                partition.tail.unshift(funcNode);
                return partition.tail;
            }
            case 'simple':
            default: {
                if (rest.length === 0) {
                    return [func];
                }
                const firstArg = rest[0];
                if (firstArg.type === SemanticType.FENCED &&
                    !SemanticPred.isNeutralFence(firstArg) &&
                    SemanticPred.isSimpleFunctionScope(firstArg)) {
                    firstArg.role = SemanticRole.LEFTRIGHT;
                    SemanticProcessor.propagateFunctionRole_(func, SemanticRole.SIMPLEFUNC);
                    funcNode = SemanticProcessor.getInstance().functionNode_(func, rest.shift());
                    rest.unshift(funcNode);
                    return rest;
                }
                rest.unshift(func);
                return rest;
            }
        }
    }
    getIntegralArgs_(nodes, args = []) {
        if (nodes.length === 0) {
            const partition = SemanticUtil.sliceNodes(args, SemanticPred.isBigOpBoundary);
            if (partition.div) {
                partition.tail.unshift(partition.div);
            }
            return { integrand: partition.head, intvar: null, rest: partition.tail };
        }
        SemanticHeuristics.run('intvar_from_implicit', nodes);
        const firstNode = nodes[0];
        if (SemanticPred.isGeneralFunctionBoundary(firstNode)) {
            const { integrand: args2, rest: rest2 } = SemanticProcessor.getInstance().getIntegralArgs_(args);
            return { integrand: args2, intvar: null, rest: rest2.concat(nodes) };
        }
        if (SemanticPred.isIntegralDxBoundarySingle(firstNode)) {
            firstNode.role = SemanticRole.INTEGRAL;
            return { integrand: args, intvar: firstNode, rest: nodes.slice(1) };
        }
        if (nodes[1] && SemanticPred.isIntegralDxBoundary(firstNode, nodes[1])) {
            const intvar = SemanticProcessor.getInstance().prefixNode_(nodes[1], [firstNode]);
            intvar.role = SemanticRole.INTEGRAL;
            return { integrand: args, intvar: intvar, rest: nodes.slice(2) };
        }
        args.push(nodes.shift());
        return SemanticProcessor.getInstance().getIntegralArgs_(nodes, args);
    }
    functionNode_(func, arg) {
        const applNode = SemanticProcessor.getInstance().factory_.makeContentNode(NamedSymbol.functionApplication);
        const appl = SemanticProcessor.getInstance().funcAppls[func.id];
        if (appl) {
            applNode.mathmlTree = appl.mathmlTree;
            applNode.mathml = appl.mathml;
            applNode.annotation = appl.annotation;
            applNode.attributes = appl.attributes;
            delete SemanticProcessor.getInstance().funcAppls[func.id];
        }
        applNode.type = SemanticType.PUNCTUATION;
        applNode.role = SemanticRole.APPLICATION;
        const funcop = SemanticProcessor.getFunctionOp_(func, function (node) {
            return (SemanticPred.isType(node, SemanticType.FUNCTION) ||
                (SemanticPred.isType(node, SemanticType.IDENTIFIER) &&
                    SemanticPred.isRole(node, SemanticRole.SIMPLEFUNC)));
        });
        return SemanticProcessor.getInstance().functionalNode_(SemanticType.APPL, [func, arg], funcop, [applNode]);
    }
    bigOpNode_(bigOp, arg) {
        const largeop = SemanticProcessor.getFunctionOp_(bigOp, (x) => SemanticPred.isType(x, SemanticType.LARGEOP));
        return SemanticProcessor.getInstance().functionalNode_(SemanticType.BIGOP, [bigOp, arg], largeop, []);
    }
    integralNode_(integral, integrand, intvar) {
        integrand =
            integrand || SemanticProcessor.getInstance().factory_.makeEmptyNode();
        intvar = intvar || SemanticProcessor.getInstance().factory_.makeEmptyNode();
        const largeop = SemanticProcessor.getFunctionOp_(integral, (x) => SemanticPred.isType(x, SemanticType.LARGEOP));
        return SemanticProcessor.getInstance().functionalNode_(SemanticType.INTEGRAL, [integral, integrand, intvar], largeop, []);
    }
    functionalNode_(type, children, operator, content) {
        const funcop = children[0];
        let oldParent;
        if (operator) {
            oldParent = operator.parent;
            content.push(operator);
        }
        const newNode = SemanticProcessor.getInstance().factory_.makeBranchNode(type, children, content);
        newNode.role = funcop.role;
        if (oldParent) {
            operator.parent = oldParent;
        }
        return newNode;
    }
    fractionNode_(denom, enume) {
        const newNode = SemanticProcessor.getInstance().factory_.makeBranchNode(SemanticType.FRACTION, [denom, enume], []);
        newNode.role = newNode.childNodes.every(function (x) {
            return (SemanticPred.isType(x, SemanticType.NUMBER) &&
                SemanticPred.isRole(x, SemanticRole.INTEGER));
        })
            ? SemanticRole.VULGAR
            : newNode.childNodes.every(SemanticPred.isPureUnit)
                ? SemanticRole.UNIT
                : SemanticRole.DIVISION;
        return SemanticHeuristics.run('propagateSimpleFunction', newNode);
    }
    scriptNode_(nodes, role, opt_noSingle) {
        let newNode;
        switch (nodes.length) {
            case 0:
                newNode = SemanticProcessor.getInstance().factory_.makeEmptyNode();
                break;
            case 1:
                newNode = nodes[0];
                if (opt_noSingle) {
                    return newNode;
                }
                break;
            default:
                newNode = SemanticProcessor.getInstance().dummyNode_(nodes);
        }
        newNode.role = role;
        return newNode;
    }
    findNestedRow_(nodes, semantic, level, value) {
        if (level > 3) {
            return null;
        }
        for (let i = 0, node; (node = nodes[i]); i++) {
            const tag = DomUtil.tagName(node);
            if (tag !== MMLTAGS.MSPACE) {
                if (tag === MMLTAGS.MROW) {
                    return SemanticProcessor.getInstance().findNestedRow_(DomUtil.toArray(node.childNodes), semantic, level + 1, value);
                }
                if (SemanticProcessor.findSemantics(node, semantic, value)) {
                    return node;
                }
            }
        }
        return null;
    }
}
SemanticProcessor.FENCE_TO_PUNCT_ = {
    [SemanticRole.METRIC]: SemanticRole.METRIC,
    [SemanticRole.NEUTRAL]: SemanticRole.VBAR,
    [SemanticRole.OPEN]: SemanticRole.OPENFENCE,
    [SemanticRole.CLOSE]: SemanticRole.CLOSEFENCE
};
SemanticProcessor.MML_TO_LIMIT_ = {
    [MMLTAGS.MSUB]: { type: SemanticType.LIMLOWER, length: 1 },
    [MMLTAGS.MUNDER]: { type: SemanticType.LIMLOWER, length: 1 },
    [MMLTAGS.MSUP]: { type: SemanticType.LIMUPPER, length: 1 },
    [MMLTAGS.MOVER]: { type: SemanticType.LIMUPPER, length: 1 },
    [MMLTAGS.MSUBSUP]: { type: SemanticType.LIMBOTH, length: 2 },
    [MMLTAGS.MUNDEROVER]: { type: SemanticType.LIMBOTH, length: 2 }
};
SemanticProcessor.MML_TO_BOUNDS_ = {
    [MMLTAGS.MSUB]: { type: SemanticType.SUBSCRIPT, length: 1, accent: false },
    [MMLTAGS.MSUP]: {
        type: SemanticType.SUPERSCRIPT,
        length: 1,
        accent: false
    },
    [MMLTAGS.MSUBSUP]: {
        type: SemanticType.SUBSCRIPT,
        length: 2,
        accent: false
    },
    [MMLTAGS.MUNDER]: {
        type: SemanticType.UNDERSCORE,
        length: 1,
        accent: true
    },
    [MMLTAGS.MOVER]: { type: SemanticType.OVERSCORE, length: 1, accent: true },
    [MMLTAGS.MUNDEROVER]: {
        type: SemanticType.UNDERSCORE,
        length: 2,
        accent: true
    }
};
SemanticProcessor.CLASSIFY_FUNCTION_ = {
    [SemanticRole.INTEGRAL]: 'integral',
    [SemanticRole.SUM]: 'bigop',
    [SemanticRole.PREFIXFUNC]: 'prefix',
    [SemanticRole.LIMFUNC]: 'prefix',
    [SemanticRole.SIMPLEFUNC]: 'prefix',
    [SemanticRole.COMPFUNC]: 'prefix'
};
SemanticProcessor.MATHJAX_FONTS = {
    '-tex-caligraphic': SemanticFont.CALIGRAPHIC,
    '-tex-caligraphic-bold': SemanticFont.CALIGRAPHICBOLD,
    '-tex-calligraphic': SemanticFont.CALIGRAPHIC,
    '-tex-calligraphic-bold': SemanticFont.CALIGRAPHICBOLD,
    '-tex-oldstyle': SemanticFont.OLDSTYLE,
    '-tex-oldstyle-bold': SemanticFont.OLDSTYLEBOLD,
    '-tex-mathit': SemanticFont.ITALIC
};
