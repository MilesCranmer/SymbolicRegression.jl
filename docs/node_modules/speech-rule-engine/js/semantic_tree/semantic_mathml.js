"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.SemanticMathml = void 0;
const DomUtil = require("../common/dom_util.js");
const semantic_meaning_js_1 = require("./semantic_meaning.js");
const semantic_attr_js_1 = require("./semantic_attr.js");
const semantic_parser_js_1 = require("./semantic_parser.js");
const SemanticPred = require("./semantic_pred.js");
const semantic_processor_js_1 = require("./semantic_processor.js");
const SemanticUtil = require("./semantic_util.js");
const semantic_util_js_1 = require("../semantic_tree/semantic_util.js");
const semantic_heuristic_factory_js_1 = require("./semantic_heuristic_factory.js");
class SemanticMathml extends semantic_parser_js_1.SemanticAbstractParser {
    static getAttribute_(node, attr, def) {
        if (!node.hasAttribute(attr)) {
            return def;
        }
        const value = node.getAttribute(attr);
        if (value.match(/^\s*$/)) {
            return null;
        }
        return value;
    }
    constructor() {
        super('MathML');
        this.parseMap_ = new Map([
            [semantic_util_js_1.MMLTAGS.SEMANTICS, this.semantics_.bind(this)],
            [semantic_util_js_1.MMLTAGS.MATH, this.rows_.bind(this)],
            [semantic_util_js_1.MMLTAGS.MROW, this.rows_.bind(this)],
            [semantic_util_js_1.MMLTAGS.MPADDED, this.rows_.bind(this)],
            [semantic_util_js_1.MMLTAGS.MSTYLE, this.rows_.bind(this)],
            [semantic_util_js_1.MMLTAGS.MFRAC, this.fraction_.bind(this)],
            [semantic_util_js_1.MMLTAGS.MSUB, this.limits_.bind(this)],
            [semantic_util_js_1.MMLTAGS.MSUP, this.limits_.bind(this)],
            [semantic_util_js_1.MMLTAGS.MSUBSUP, this.limits_.bind(this)],
            [semantic_util_js_1.MMLTAGS.MOVER, this.limits_.bind(this)],
            [semantic_util_js_1.MMLTAGS.MUNDER, this.limits_.bind(this)],
            [semantic_util_js_1.MMLTAGS.MUNDEROVER, this.limits_.bind(this)],
            [semantic_util_js_1.MMLTAGS.MROOT, this.root_.bind(this)],
            [semantic_util_js_1.MMLTAGS.MSQRT, this.sqrt_.bind(this)],
            [semantic_util_js_1.MMLTAGS.MTABLE, this.table_.bind(this)],
            [semantic_util_js_1.MMLTAGS.MLABELEDTR, this.tableLabeledRow_.bind(this)],
            [semantic_util_js_1.MMLTAGS.MTR, this.tableRow_.bind(this)],
            [semantic_util_js_1.MMLTAGS.MTD, this.tableCell_.bind(this)],
            [semantic_util_js_1.MMLTAGS.MS, this.text_.bind(this)],
            [semantic_util_js_1.MMLTAGS.MTEXT, this.text_.bind(this)],
            [semantic_util_js_1.MMLTAGS.MSPACE, this.space_.bind(this)],
            [semantic_util_js_1.MMLTAGS.ANNOTATIONXML, this.text_.bind(this)],
            [semantic_util_js_1.MMLTAGS.MI, this.identifier_.bind(this)],
            [semantic_util_js_1.MMLTAGS.MN, this.number_.bind(this)],
            [semantic_util_js_1.MMLTAGS.MO, this.operator_.bind(this)],
            [semantic_util_js_1.MMLTAGS.MFENCED, this.fenced_.bind(this)],
            [semantic_util_js_1.MMLTAGS.MENCLOSE, this.enclosed_.bind(this)],
            [semantic_util_js_1.MMLTAGS.MMULTISCRIPTS, this.multiscripts_.bind(this)],
            [semantic_util_js_1.MMLTAGS.ANNOTATION, this.empty_.bind(this)],
            [semantic_util_js_1.MMLTAGS.NONE, this.empty_.bind(this)],
            [semantic_util_js_1.MMLTAGS.MACTION, this.action_.bind(this)]
        ]);
        const meaning = {
            type: semantic_meaning_js_1.SemanticType.IDENTIFIER,
            role: semantic_meaning_js_1.SemanticRole.NUMBERSET,
            font: semantic_meaning_js_1.SemanticFont.DOUBLESTRUCK
        };
        [
            'C',
            'H',
            'N',
            'P',
            'Q',
            'R',
            'Z',
            'ℂ',
            'ℍ',
            'ℕ',
            'ℙ',
            'ℚ',
            'ℝ',
            'ℤ'
        ].forEach(((x) => this.getFactory().defaultMap.set(x, meaning)).bind(this));
    }
    parse(mml) {
        semantic_processor_js_1.SemanticProcessor.getInstance().setNodeFactory(this.getFactory());
        const children = DomUtil.toArray(mml.childNodes);
        const tag = DomUtil.tagName(mml);
        const func = this.parseMap_.get(tag);
        const newNode = (func ? func : this.dummy_.bind(this))(mml, children);
        SemanticUtil.addAttributes(newNode, mml);
        if ([
            semantic_util_js_1.MMLTAGS.MATH,
            semantic_util_js_1.MMLTAGS.MROW,
            semantic_util_js_1.MMLTAGS.MPADDED,
            semantic_util_js_1.MMLTAGS.MSTYLE,
            semantic_util_js_1.MMLTAGS.SEMANTICS,
            semantic_util_js_1.MMLTAGS.MACTION
        ].indexOf(tag) !== -1) {
            return newNode;
        }
        newNode.mathml.unshift(mml);
        newNode.mathmlTree = mml;
        return newNode;
    }
    semantics_(_node, children) {
        return children.length
            ? this.parse(children[0])
            : this.getFactory().makeEmptyNode();
    }
    rows_(node, children) {
        const semantics = node.getAttribute('semantics');
        if (semantics && semantics.match('bspr_')) {
            return semantic_processor_js_1.SemanticProcessor.proof(node, semantics, this.parseList.bind(this));
        }
        children = SemanticUtil.purgeNodes(children);
        let newNode;
        if (children.length === 1) {
            newNode = this.parse(children[0]);
            if (newNode.type === semantic_meaning_js_1.SemanticType.EMPTY && !newNode.mathmlTree) {
                newNode.mathmlTree = node;
            }
        }
        else {
            const snode = semantic_heuristic_factory_js_1.SemanticHeuristics.run('function_from_identifiers', node);
            newNode =
                snode && snode !== node
                    ? snode
                    : semantic_processor_js_1.SemanticProcessor.getInstance().row(this.parseList(children));
        }
        newNode.mathml.unshift(node);
        return newNode;
    }
    fraction_(node, children) {
        if (!children.length) {
            return this.getFactory().makeEmptyNode();
        }
        const upper = this.parse(children[0]);
        const lower = children[1]
            ? this.parse(children[1])
            : this.getFactory().makeEmptyNode();
        const sem = semantic_processor_js_1.SemanticProcessor.getInstance().fractionLikeNode(upper, lower, node.getAttribute('linethickness'), node.getAttribute('bevelled') === 'true');
        return sem;
    }
    limits_(node, children) {
        return semantic_processor_js_1.SemanticProcessor.getInstance().limitNode(DomUtil.tagName(node), this.parseList(children));
    }
    root_(node, children) {
        if (!children[1]) {
            return this.sqrt_(node, children);
        }
        return this.getFactory().makeBranchNode(semantic_meaning_js_1.SemanticType.ROOT, [this.parse(children[1]), this.parse(children[0])], []);
    }
    sqrt_(_node, children) {
        const semNodes = this.parseList(SemanticUtil.purgeNodes(children));
        return this.getFactory().makeBranchNode(semantic_meaning_js_1.SemanticType.SQRT, [semantic_processor_js_1.SemanticProcessor.getInstance().row(semNodes)], []);
    }
    table_(node, children) {
        const semantics = node.getAttribute('semantics');
        if (semantics && semantics.match('bspr_')) {
            return semantic_processor_js_1.SemanticProcessor.proof(node, semantics, this.parseList.bind(this));
        }
        const newNode = this.getFactory().makeBranchNode(semantic_meaning_js_1.SemanticType.TABLE, this.parseList(children), []);
        newNode.mathmlTree = node;
        return semantic_processor_js_1.SemanticProcessor.tableToMultiline(newNode);
    }
    tableRow_(_node, children) {
        const newNode = this.getFactory().makeBranchNode(semantic_meaning_js_1.SemanticType.ROW, this.parseList(children), []);
        newNode.role = semantic_meaning_js_1.SemanticRole.TABLE;
        return newNode;
    }
    tableLabeledRow_(node, children) {
        var _a;
        if (!children.length) {
            return this.tableRow_(node, children);
        }
        const label = this.parse(children[0]);
        label.role = semantic_meaning_js_1.SemanticRole.LABEL;
        if (((_a = label.childNodes[0]) === null || _a === void 0 ? void 0 : _a.type) === semantic_meaning_js_1.SemanticType.TEXT) {
            label.childNodes[0].role = semantic_meaning_js_1.SemanticRole.LABEL;
        }
        const newNode = this.getFactory().makeBranchNode(semantic_meaning_js_1.SemanticType.ROW, this.parseList(children.slice(1)), [label]);
        newNode.role = semantic_meaning_js_1.SemanticRole.TABLE;
        return newNode;
    }
    tableCell_(_node, children) {
        const semNodes = this.parseList(SemanticUtil.purgeNodes(children));
        let childNodes;
        if (!semNodes.length) {
            childNodes = [];
        }
        else if (semNodes.length === 1 &&
            SemanticPred.isType(semNodes[0], semantic_meaning_js_1.SemanticType.EMPTY)) {
            childNodes = semNodes;
        }
        else {
            childNodes = [semantic_processor_js_1.SemanticProcessor.getInstance().row(semNodes)];
        }
        const newNode = this.getFactory().makeBranchNode(semantic_meaning_js_1.SemanticType.CELL, childNodes, []);
        newNode.role = semantic_meaning_js_1.SemanticRole.TABLE;
        return newNode;
    }
    space_(node, children) {
        const width = node.getAttribute('width');
        const match = width && width.match(/[a-z]*$/);
        if (!match) {
            return this.empty_(node, children);
        }
        const sizes = {
            cm: 0.4,
            pc: 0.5,
            em: 0.5,
            ex: 1,
            in: 0.15,
            pt: 5,
            mm: 5
        };
        const unit = match[0];
        const measure = parseFloat(width.slice(0, match.index));
        const size = sizes[unit];
        if (!size || isNaN(measure) || measure < size) {
            return this.empty_(node, children);
        }
        const newNode = this.getFactory().makeUnprocessed(node);
        return semantic_processor_js_1.SemanticProcessor.getInstance().text(newNode, DomUtil.tagName(node));
    }
    text_(node, children) {
        const newNode = this.leaf_(node, children);
        if (!node.textContent) {
            return newNode;
        }
        newNode.updateContent(node.textContent, true);
        return semantic_processor_js_1.SemanticProcessor.getInstance().text(newNode, DomUtil.tagName(node));
    }
    identifier_(node, children) {
        const newNode = this.leaf_(node, children);
        return semantic_processor_js_1.SemanticProcessor.getInstance().identifierNode(newNode, semantic_processor_js_1.SemanticProcessor.getInstance().font(node.getAttribute('mathvariant')), node.getAttribute('class'));
    }
    number_(node, children) {
        const newNode = this.leaf_(node, children);
        semantic_processor_js_1.SemanticProcessor.number(newNode);
        return newNode;
    }
    operator_(node, children) {
        const newNode = this.leaf_(node, children);
        semantic_processor_js_1.SemanticProcessor.getInstance().operatorNode(newNode);
        return newNode;
    }
    fenced_(node, children) {
        const semNodes = this.parseList(SemanticUtil.purgeNodes(children));
        const sepValue = SemanticMathml.getAttribute_(node, 'separators', ',');
        const open = SemanticMathml.getAttribute_(node, 'open', '(');
        const close = SemanticMathml.getAttribute_(node, 'close', ')');
        const newNode = semantic_processor_js_1.SemanticProcessor.getInstance().mfenced(open, close, sepValue, semNodes);
        const nodes = semantic_processor_js_1.SemanticProcessor.getInstance().tablesInRow([newNode]);
        return nodes[0];
    }
    enclosed_(node, children) {
        const semNodes = this.parseList(SemanticUtil.purgeNodes(children));
        const newNode = this.getFactory().makeBranchNode(semantic_meaning_js_1.SemanticType.ENCLOSE, [semantic_processor_js_1.SemanticProcessor.getInstance().row(semNodes)], []);
        newNode.role =
            node.getAttribute('notation') || semantic_meaning_js_1.SemanticRole.UNKNOWN;
        return newNode;
    }
    multiscripts_(_node, children) {
        if (!children.length) {
            return this.getFactory().makeEmptyNode();
        }
        const base = this.parse(children.shift());
        if (!children.length) {
            return base;
        }
        const lsup = [];
        const lsub = [];
        const rsup = [];
        const rsub = [];
        let prescripts = false;
        let scriptcount = 0;
        for (let i = 0, child; (child = children[i]); i++) {
            if (DomUtil.tagName(child) === semantic_util_js_1.MMLTAGS.MPRESCRIPTS) {
                prescripts = true;
                scriptcount = 0;
                continue;
            }
            prescripts
                ? scriptcount & 1
                    ? lsup.push(child)
                    : lsub.push(child)
                : scriptcount & 1
                    ? rsup.push(child)
                    : rsub.push(child);
            scriptcount++;
        }
        if (!SemanticUtil.purgeNodes(lsup).length &&
            !SemanticUtil.purgeNodes(lsub).length) {
            return semantic_processor_js_1.SemanticProcessor.getInstance().pseudoTensor(base, this.parseList(rsub), this.parseList(rsup));
        }
        return semantic_processor_js_1.SemanticProcessor.getInstance().tensor(base, this.parseList(lsub), this.parseList(lsup), this.parseList(rsub), this.parseList(rsup));
    }
    empty_(_node, _children) {
        return this.getFactory().makeEmptyNode();
    }
    action_(node, children) {
        const selection = children[node.hasAttribute('selection')
            ? parseInt(node.getAttribute('selection'), 10) - 1
            : 0];
        const stree = this.parse(selection);
        stree.mathmlTree = selection;
        return stree;
    }
    dummy_(node, _children) {
        const unknown = this.getFactory().makeUnprocessed(node);
        unknown.role = node.tagName;
        unknown.textContent = node.textContent;
        return unknown;
    }
    leaf_(mml, children) {
        if (children.length === 1 &&
            children[0].nodeType !== DomUtil.NodeType.TEXT_NODE) {
            const node = this.getFactory().makeUnprocessed(mml);
            node.role = children[0].tagName;
            SemanticUtil.addAttributes(node, children[0]);
            return node;
        }
        const node = this.getFactory().makeLeafNode(mml.textContent, semantic_processor_js_1.SemanticProcessor.getInstance().font(mml.getAttribute('mathvariant')));
        if (mml.hasAttribute('data-latex')) {
            semantic_attr_js_1.SemanticMap.LatexCommands.set(mml.getAttribute('data-latex'), mml.textContent);
        }
        return node;
    }
}
exports.SemanticMathml = SemanticMathml;
