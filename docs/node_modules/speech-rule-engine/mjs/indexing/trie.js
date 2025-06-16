import { TrieNodeKind } from './trie_node.js';
import { getNode } from './trie_node_factory.js';
export class Trie {
    static collectRules_(root) {
        const rules = [];
        let explore = [root];
        while (explore.length) {
            const node = explore.shift();
            if (node.getKind() === TrieNodeKind.QUERY ||
                node.getKind() === TrieNodeKind.BOOLEAN) {
                const rule = node.getRule();
                if (rule) {
                    rules.unshift(rule);
                }
            }
            explore = explore.concat(node.getChildren());
        }
        return rules;
    }
    static printWithDepth_(node, depth, str) {
        const prefix = new Array(depth + 2).join(depth.toString()) + ': ';
        str += prefix + node.toString() + '\n';
        const children = node.getChildren();
        for (let i = 0, child; (child = children[i]); i++) {
            str = Trie.printWithDepth_(child, depth + 1, str);
        }
        return str;
    }
    static order_(node) {
        const children = node.getChildren();
        if (!children.length) {
            return 0;
        }
        const max = Math.max.apply(null, children.map(Trie.order_));
        return Math.max(children.length, max);
    }
    constructor() {
        this.root = getNode(TrieNodeKind.ROOT, '', null);
    }
    addRule(rule) {
        let node = this.root;
        const context = rule.context;
        const dynamicCstr = rule.dynamicCstr.getValues();
        for (let i = 0, l = dynamicCstr.length; i < l; i++) {
            node = this.addNode_(node, dynamicCstr[i], TrieNodeKind.DYNAMIC, context);
        }
        node = this.addNode_(node, rule.precondition.query, TrieNodeKind.QUERY, context);
        const booleans = rule.precondition.constraints;
        for (let i = 0, l = booleans.length; i < l; i++) {
            node = this.addNode_(node, booleans[i], TrieNodeKind.BOOLEAN, context);
        }
        node.setRule(rule);
    }
    lookupRules(xml, dynamic) {
        let nodes = [this.root];
        const rules = [];
        while (dynamic.length) {
            const dynamicSet = dynamic.shift();
            const newNodes = [];
            while (nodes.length) {
                const node = nodes.shift();
                const children = node.getChildren();
                children.forEach((child) => {
                    if (child.getKind() !== TrieNodeKind.DYNAMIC ||
                        dynamicSet.indexOf(child.getConstraint()) !== -1) {
                        newNodes.push(child);
                    }
                });
            }
            nodes = newNodes.slice();
        }
        while (nodes.length) {
            const node = nodes.shift();
            if (node.getRule) {
                const rule = node.getRule();
                if (rule) {
                    rules.push(rule);
                }
            }
            const children = node.findChildren(xml);
            nodes = nodes.concat(children);
        }
        return rules;
    }
    hasSubtrie(cstrs) {
        let subtrie = this.root;
        for (let i = 0, l = cstrs.length; i < l; i++) {
            const cstr = cstrs[i];
            subtrie = subtrie.getChild(cstr);
            if (!subtrie) {
                return false;
            }
        }
        return true;
    }
    toString() {
        return Trie.printWithDepth_(this.root, 0, '');
    }
    collectRules(root = this.root) {
        return Trie.collectRules_(root);
    }
    order() {
        return Trie.order_(this.root);
    }
    enumerate(opt_info) {
        return this.enumerate_(this.root, opt_info);
    }
    byConstraint(constraint) {
        let node = this.root;
        while (constraint.length && node) {
            const cstr = constraint.shift();
            node = node.getChild(cstr);
        }
        return node || null;
    }
    enumerate_(node, info) {
        info = info || {};
        const children = node.getChildren();
        for (let i = 0, child; (child = children[i]); i++) {
            if (child.kind !== TrieNodeKind.DYNAMIC) {
                continue;
            }
            info[child.getConstraint()] = this.enumerate_(child, info[child.getConstraint()]);
        }
        return info;
    }
    addNode_(node, constraint, kind, context) {
        let nextNode = node.getChild(constraint);
        if (!nextNode) {
            nextNode = getNode(kind, constraint, context);
            node.addChild(nextNode);
        }
        return nextNode;
    }
}
