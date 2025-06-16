import * as BaseUtil from '../common/base_util.js';
import { Engine } from '../common/engine.js';
import * as XpathUtil from '../common/xpath_util.js';
import { Attribute as EnrichAttribute } from '../enrich_mathml/enrich_attr.js';
import { SemanticType } from './semantic_meaning.js';
const Options = {
    tree: false
};
export class SemanticSkeleton {
    static fromTree(tree) {
        return SemanticSkeleton.fromNode(tree.root);
    }
    static fromNode(node) {
        return new SemanticSkeleton(SemanticSkeleton.fromNode_(node));
    }
    static fromString(skel) {
        return new SemanticSkeleton(SemanticSkeleton.fromString_(skel));
    }
    static simpleCollapseStructure(strct) {
        return typeof strct === 'number';
    }
    static contentCollapseStructure(strct) {
        return (!!strct &&
            !SemanticSkeleton.simpleCollapseStructure(strct) &&
            strct[0] === 'c');
    }
    static interleaveIds(first, second) {
        return BaseUtil.interleaveLists(SemanticSkeleton.collapsedLeafs(first), SemanticSkeleton.collapsedLeafs(second));
    }
    static collapsedLeafs(...args) {
        const collapseStructure = (coll) => {
            if (SemanticSkeleton.simpleCollapseStructure(coll)) {
                return [coll];
            }
            coll = coll;
            return SemanticSkeleton.contentCollapseStructure(coll[1])
                ? coll.slice(2)
                : coll.slice(1);
        };
        return args.reduce((x, y) => x.concat(collapseStructure(y)), []);
    }
    static fromStructure(mml, tree) {
        return new SemanticSkeleton(SemanticSkeleton.tree_(mml, tree.root));
    }
    static combineContentChildren(type, _role, content, children) {
        switch (type) {
            case SemanticType.RELSEQ:
            case SemanticType.INFIXOP:
            case SemanticType.MULTIREL:
                return BaseUtil.interleaveLists(children, content);
            case SemanticType.PREFIXOP:
                return content.concat(children);
            case SemanticType.POSTFIXOP:
                return children.concat(content);
            case SemanticType.MATRIX:
            case SemanticType.VECTOR:
            case SemanticType.FENCED:
                children.unshift(content[0]);
                children.push(content[1]);
                return children;
            case SemanticType.CASES:
                children.unshift(content[0]);
                return children;
            case SemanticType.APPL:
                return [children[0], content[0], children[1]];
            case SemanticType.ROOT:
                return [children[0], children[1]];
            case SemanticType.ROW:
            case SemanticType.LINE:
                if (content.length) {
                    children.unshift(content[0]);
                }
                return children;
            default:
                return children;
        }
    }
    static makeSexp_(struct) {
        if (SemanticSkeleton.simpleCollapseStructure(struct)) {
            return struct.toString();
        }
        if (SemanticSkeleton.contentCollapseStructure(struct)) {
            return ('(' +
                'c ' +
                struct.slice(1).map(SemanticSkeleton.makeSexp_).join(' ') +
                ')');
        }
        return ('(' + struct.map(SemanticSkeleton.makeSexp_).join(' ') + ')');
    }
    static fromString_(skeleton) {
        let str = skeleton.replace(/\(/g, '[');
        str = str.replace(/\)/g, ']');
        str = str.replace(/ /g, ',');
        str = str.replace(/c/g, '"c"');
        return JSON.parse(str);
    }
    static fromNode_(node) {
        if (!node) {
            return [];
        }
        const content = node.contentNodes;
        let contentStructure;
        if (content.length) {
            contentStructure = content.map(SemanticSkeleton.fromNode_);
            contentStructure.unshift('c');
        }
        const children = node.childNodes;
        if (!children.length) {
            return content.length ? [node.id, contentStructure] : node.id;
        }
        const structure = children.map(SemanticSkeleton.fromNode_);
        if (content.length) {
            structure.unshift(contentStructure);
        }
        structure.unshift(node.id);
        return structure;
    }
    static tree_(mml, node, level = 0, posinset = 1, setsize = 1) {
        if (!node) {
            return [];
        }
        const id = node.id;
        const skeleton = [id];
        XpathUtil.updateEvaluator(mml);
        const mmlChild = XpathUtil.evalXPath(`.//self::*[@${EnrichAttribute.ID}=${id}]`, mml)[0];
        if (!node.childNodes.length) {
            SemanticSkeleton.addAria(mmlChild, level, posinset, setsize);
            return node.id;
        }
        const children = SemanticSkeleton.combineContentChildren(node.type, node.role, node.contentNodes.map(function (x) {
            return x;
        }), node.childNodes.map(function (x) {
            return x;
        }));
        if (mmlChild) {
            SemanticSkeleton.addOwns_(mmlChild, children);
        }
        for (let i = 0, l = children.length, child; (child = children[i]); i++) {
            skeleton.push(SemanticSkeleton.tree_(mml, child, level + 1, i + 1, l));
        }
        SemanticSkeleton.addAria(mmlChild, level, posinset, setsize, !Options.tree ? 'treeitem' : level ? 'group' : 'tree');
        return skeleton;
    }
    static addAria(node, level, posinset, setsize, role = !Options.tree ? 'treeitem' : level ? 'treeitem' : 'tree') {
        if (!Engine.getInstance().aria || !node) {
            return;
        }
        node.setAttribute('aria-level', level.toString());
        node.setAttribute('aria-posinset', posinset.toString());
        node.setAttribute('aria-setsize', setsize.toString());
        node.setAttribute('role', role);
        if (node.hasAttribute(EnrichAttribute.OWNS)) {
            node.setAttribute('aria-owns', node.getAttribute(EnrichAttribute.OWNS));
        }
    }
    static addOwns_(node, children) {
        const collapsed = node.getAttribute(EnrichAttribute.COLLAPSED);
        const leafs = collapsed
            ? SemanticSkeleton.realLeafs_(SemanticSkeleton.fromString(collapsed).array)
            : children.map((x) => x.id);
        node.setAttribute(EnrichAttribute.OWNS, leafs.join(' '));
    }
    static realLeafs_(sexp) {
        if (SemanticSkeleton.simpleCollapseStructure(sexp)) {
            return [sexp];
        }
        if (SemanticSkeleton.contentCollapseStructure(sexp)) {
            return [];
        }
        sexp = sexp;
        let result = [];
        for (let i = 1; i < sexp.length; i++) {
            result = result.concat(SemanticSkeleton.realLeafs_(sexp[i]));
        }
        return result;
    }
    constructor(skeleton) {
        this.parents = null;
        this.levelsMap = null;
        skeleton = skeleton === 0 ? skeleton : skeleton || [];
        this.array = skeleton;
    }
    populate() {
        if (this.parents && this.levelsMap) {
            return;
        }
        this.parents = {};
        this.levelsMap = {};
        this.populate_(this.array, this.array, []);
    }
    toString() {
        return SemanticSkeleton.makeSexp_(this.array);
    }
    populate_(element, layer, parents) {
        if (SemanticSkeleton.simpleCollapseStructure(element)) {
            element = element;
            this.levelsMap[element] = layer;
            this.parents[element] =
                element === parents[0] ? parents.slice(1) : parents;
            return;
        }
        const newElement = SemanticSkeleton.contentCollapseStructure(element)
            ? element.slice(1)
            : element;
        const newParents = [newElement[0]].concat(parents);
        for (let i = 0, l = newElement.length; i < l; i++) {
            const current = newElement[i];
            this.populate_(current, element, newParents);
        }
    }
    isRoot(id) {
        const level = this.levelsMap[id];
        return id === level[0];
    }
    directChildren(id) {
        if (!this.isRoot(id)) {
            return [];
        }
        const level = this.levelsMap[id];
        return level.slice(1).map((child) => {
            if (SemanticSkeleton.simpleCollapseStructure(child)) {
                return child;
            }
            if (SemanticSkeleton.contentCollapseStructure(child)) {
                return child[1];
            }
            return child[0];
        });
    }
    subtreeNodes(id) {
        if (!this.isRoot(id)) {
            return [];
        }
        const subtreeNodes_ = (tree, nodes) => {
            if (SemanticSkeleton.simpleCollapseStructure(tree)) {
                nodes.push(tree);
                return;
            }
            tree = tree;
            if (SemanticSkeleton.contentCollapseStructure(tree)) {
                tree = tree.slice(1);
            }
            tree.forEach((x) => subtreeNodes_(x, nodes));
        };
        const level = this.levelsMap[id];
        const subtree = [];
        subtreeNodes_(level.slice(1), subtree);
        return subtree;
    }
}
