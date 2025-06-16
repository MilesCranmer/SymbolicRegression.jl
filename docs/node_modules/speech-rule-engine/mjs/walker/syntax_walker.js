import { interleaveLists } from '../common/base_util.js';
import { SemanticRole, SemanticType } from '../semantic_tree/semantic_meaning.js';
import { AbstractWalker } from './abstract_walker.js';
import { Levels } from './levels.js';
export class SyntaxWalker extends AbstractWalker {
    constructor(node, generator, highlighter, xml) {
        super(node, generator, highlighter, xml);
        this.node = node;
        this.generator = generator;
        this.highlighter = highlighter;
        this.levels = null;
        this.restoreState();
    }
    initLevels() {
        const levels = new Levels();
        levels.push([this.primaryId()]);
        return levels;
    }
    up() {
        super.up();
        const parent = this.previousLevel();
        if (!parent) {
            return null;
        }
        this.levels.pop();
        return this.singletonFocus(parent);
    }
    down() {
        super.down();
        const children = this.nextLevel();
        if (children.length === 0) {
            return null;
        }
        const focus = this.singletonFocus(children[0]);
        if (focus) {
            this.levels.push(children);
        }
        return focus;
    }
    combineContentChildren(type, role, content, children) {
        switch (type) {
            case SemanticType.RELSEQ:
            case SemanticType.INFIXOP:
            case SemanticType.MULTIREL:
                return interleaveLists(children, content);
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
            case SemanticType.PUNCTUATED:
                if (role === SemanticRole.TEXT) {
                    return interleaveLists(children, content);
                }
                return children;
            case SemanticType.APPL:
                return [children[0], content[0], children[1]];
            case SemanticType.ROOT:
                return [children[0], children[1]];
            default:
                return children;
        }
    }
    left() {
        super.left();
        const index = this.levels.indexOf(this.primaryId());
        if (index === null) {
            return null;
        }
        const id = this.levels.get(index - 1);
        return id ? this.singletonFocus(id) : null;
    }
    right() {
        super.right();
        const index = this.levels.indexOf(this.primaryId());
        if (index === null) {
            return null;
        }
        const id = this.levels.get(index + 1);
        return id ? this.singletonFocus(id) : null;
    }
    findFocusOnLevel(id) {
        return this.singletonFocus(id.toString());
    }
    focusDomNodes() {
        return [this.getFocus().getDomPrimary()];
    }
    focusSemanticNodes() {
        return [this.getFocus().getSemanticPrimary()];
    }
}
