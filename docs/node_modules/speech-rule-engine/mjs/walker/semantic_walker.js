import { SemanticRole, SemanticType } from '../semantic_tree/semantic_meaning.js';
import { AbstractWalker } from './abstract_walker.js';
import { Levels } from './levels.js';
export class SemanticWalker extends AbstractWalker {
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
        levels.push([this.getFocus()]);
        return levels;
    }
    up() {
        super.up();
        const parent = this.previousLevel();
        if (!parent) {
            return null;
        }
        this.levels.pop();
        const found = this.levels.find(function (focus) {
            return focus.getSemanticNodes().some(function (node) {
                return node.id.toString() === parent;
            });
        });
        return found;
    }
    down() {
        super.down();
        const children = this.nextLevel();
        if (children.length === 0) {
            return null;
        }
        this.levels.push(children);
        return children[0];
    }
    combineContentChildren(type, role, content, children) {
        switch (type) {
            case SemanticType.RELSEQ:
            case SemanticType.INFIXOP:
            case SemanticType.MULTIREL:
                return this.makePairList(children, content);
            case SemanticType.PREFIXOP:
                return [this.focusFromId(children[0], content.concat(children))];
            case SemanticType.POSTFIXOP:
                return [this.focusFromId(children[0], children.concat(content))];
            case SemanticType.MATRIX:
            case SemanticType.VECTOR:
            case SemanticType.FENCED:
                return [
                    this.focusFromId(children[0], [content[0], children[0], content[1]])
                ];
            case SemanticType.CASES:
                return [this.focusFromId(children[0], [content[0], children[0]])];
            case SemanticType.PUNCTUATED:
                if (role === SemanticRole.TEXT) {
                    return children.map(this.singletonFocus.bind(this));
                }
                if (children.length === content.length) {
                    return content.map(this.singletonFocus.bind(this));
                }
                return this.combinePunctuations(children, content, [], []);
            case SemanticType.APPL:
                return [
                    this.focusFromId(children[0], [children[0], content[0]]),
                    this.singletonFocus(children[1])
                ];
            case SemanticType.ROOT:
                return [
                    this.singletonFocus(children[0]),
                    this.singletonFocus(children[1])
                ];
            default:
                return children.map(this.singletonFocus.bind(this));
        }
    }
    combinePunctuations(children, content, prepunct, acc) {
        if (children.length === 0) {
            return acc;
        }
        const child = children.shift();
        const cont = content.shift();
        if (child === cont) {
            prepunct.push(cont);
            return this.combinePunctuations(children, content, prepunct, acc);
        }
        else {
            content.unshift(cont);
            prepunct.push(child);
            if (children.length === content.length) {
                acc.push(this.focusFromId(child, prepunct.concat(content)));
                return acc;
            }
            else {
                acc.push(this.focusFromId(child, prepunct));
                return this.combinePunctuations(children, content, [], acc);
            }
        }
    }
    makePairList(children, content) {
        if (children.length === 0) {
            return [];
        }
        if (children.length === 1) {
            return [this.singletonFocus(children[0])];
        }
        const result = [this.singletonFocus(children.shift())];
        for (let i = 0, l = children.length; i < l; i++) {
            result.push(this.focusFromId(children[i], [content[i], children[i]]));
        }
        return result;
    }
    left() {
        super.left();
        const index = this.levels.indexOf(this.getFocus());
        if (index === null) {
            return null;
        }
        const ids = this.levels.get(index - 1);
        return ids ? ids : null;
    }
    right() {
        super.right();
        const index = this.levels.indexOf(this.getFocus());
        if (index === null) {
            return null;
        }
        const ids = this.levels.get(index + 1);
        return ids ? ids : null;
    }
    findFocusOnLevel(id) {
        const focus = this.levels.find((x) => {
            const pid = x.getSemanticPrimary().id;
            return pid === id;
        });
        return focus;
    }
}
