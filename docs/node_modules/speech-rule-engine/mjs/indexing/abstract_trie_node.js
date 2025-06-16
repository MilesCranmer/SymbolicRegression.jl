import { Debugger } from '../common/debugger.js';
import { TrieNodeKind } from './trie_node.js';
export class AbstractTrieNode {
    constructor(constraint, test) {
        this.constraint = constraint;
        this.test = test;
        this.children_ = {};
        this.kind = TrieNodeKind.ROOT;
    }
    getConstraint() {
        return this.constraint;
    }
    getKind() {
        return this.kind;
    }
    applyTest(object) {
        return this.test(object);
    }
    addChild(node) {
        const constraint = node.getConstraint();
        const child = this.children_[constraint];
        this.children_[constraint] = node;
        return child;
    }
    getChild(constraint) {
        return this.children_[constraint];
    }
    getChildren() {
        const children = [];
        for (const val of Object.values(this.children_)) {
            children.push(val);
        }
        return children;
    }
    findChildren(object) {
        const children = [];
        for (const val of Object.values(this.children_)) {
            if (val.applyTest(object)) {
                children.push(val);
            }
        }
        return children;
    }
    removeChild(constraint) {
        delete this.children_[constraint];
    }
    toString() {
        return this.constraint;
    }
}
export class StaticTrieNode extends AbstractTrieNode {
    constructor(constraint, test) {
        super(constraint, test);
        this.rule_ = null;
        this.kind = TrieNodeKind.STATIC;
    }
    getRule() {
        return this.rule_;
    }
    setRule(rule) {
        if (this.rule_) {
            Debugger.getInstance().output('Replacing rule ' + this.rule_ + ' with ' + rule);
        }
        this.rule_ = rule;
    }
    toString() {
        const rule = this.getRule();
        return rule
            ? this.constraint + '\n' + '==> ' + this.getRule().action
            : this.constraint;
    }
}
