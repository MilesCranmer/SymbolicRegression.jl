import * as DomUtil from '../common/dom_util.js';
import { KeyCode } from '../common/event_util.js';
import { SemanticRole, SemanticType } from '../semantic_tree/semantic_meaning.js';
import { SyntaxWalker } from './syntax_walker.js';
import { WalkerMoves } from './walker.js';
export class TableWalker extends SyntaxWalker {
    constructor(node, generator, highlighter, xml) {
        super(node, generator, highlighter, xml);
        this.node = node;
        this.generator = generator;
        this.highlighter = highlighter;
        this.firstJump = null;
        this.key_ = null;
        this.row_ = 0;
        this.currentTable_ = null;
        this.keyMapping.set(KeyCode.ZERO, this.jumpCell.bind(this));
        this.keyMapping.set(KeyCode.ONE, this.jumpCell.bind(this));
        this.keyMapping.set(KeyCode.TWO, this.jumpCell.bind(this));
        this.keyMapping.set(KeyCode.THREE, this.jumpCell.bind(this));
        this.keyMapping.set(KeyCode.FOUR, this.jumpCell.bind(this));
        this.keyMapping.set(KeyCode.FIVE, this.jumpCell.bind(this));
        this.keyMapping.set(KeyCode.SIX, this.jumpCell.bind(this));
        this.keyMapping.set(KeyCode.SEVEN, this.jumpCell.bind(this));
        this.keyMapping.set(KeyCode.EIGHT, this.jumpCell.bind(this));
        this.keyMapping.set(KeyCode.NINE, this.jumpCell.bind(this));
    }
    move(key) {
        this.key_ = key;
        const result = super.move(key);
        this.modifier = false;
        return result;
    }
    up() {
        this.moved = WalkerMoves.UP;
        return this.eligibleCell_() ? this.verticalMove_(false) : super.up();
    }
    down() {
        this.moved = WalkerMoves.DOWN;
        return this.eligibleCell_() ? this.verticalMove_(true) : super.down();
    }
    jumpCell() {
        if (!this.isInTable_() || this.key_ === null) {
            return this.getFocus();
        }
        if (this.moved === WalkerMoves.ROW) {
            this.moved = WalkerMoves.CELL;
            const column = this.key_ - KeyCode.ZERO;
            if (!this.isLegalJump_(this.row_, column)) {
                return this.getFocus();
            }
            return this.jumpCell_(this.row_, column);
        }
        const row = this.key_ - KeyCode.ZERO;
        if (row > this.currentTable_.childNodes.length) {
            return this.getFocus();
        }
        this.row_ = row;
        this.moved = WalkerMoves.ROW;
        return this.getFocus().clone();
    }
    undo() {
        const focus = super.undo();
        if (focus === this.firstJump) {
            this.firstJump = null;
        }
        return focus;
    }
    eligibleCell_() {
        const primary = this.getFocus().getSemanticPrimary();
        return (this.modifier &&
            primary.type === SemanticType.CELL &&
            TableWalker.ELIGIBLE_CELL_ROLES.indexOf(primary.role) !== -1);
    }
    verticalMove_(direction) {
        const parent = this.previousLevel();
        if (!parent) {
            return null;
        }
        const origFocus = this.getFocus();
        const origIndex = this.levels.indexOf(this.primaryId());
        const origLevel = this.levels.pop();
        const parentIndex = this.levels.indexOf(parent);
        const row = this.levels.get(direction ? parentIndex + 1 : parentIndex - 1);
        if (!row) {
            this.levels.push(origLevel);
            return null;
        }
        this.setFocus(this.singletonFocus(row));
        const children = this.nextLevel();
        const newNode = children[origIndex];
        if (!newNode) {
            this.setFocus(origFocus);
            this.levels.push(origLevel);
            return null;
        }
        this.levels.push(children);
        return this.singletonFocus(children[origIndex]);
    }
    jumpCell_(row, column) {
        if (!this.firstJump) {
            this.firstJump = this.getFocus();
            this.virtualize(true);
        }
        else {
            this.virtualize(false);
        }
        const id = this.currentTable_.id.toString();
        let level;
        do {
            level = this.levels.pop();
        } while (level.indexOf(id) === -1);
        this.levels.push(level);
        this.setFocus(this.singletonFocus(id));
        this.levels.push(this.nextLevel());
        const semRow = this.currentTable_.childNodes[row - 1];
        this.setFocus(this.singletonFocus(semRow.id.toString()));
        this.levels.push(this.nextLevel());
        return this.singletonFocus(semRow.childNodes[column - 1].id.toString());
    }
    isLegalJump_(row, column) {
        const xmlTable = DomUtil.querySelectorAllByAttrValue(this.getRebuilt().xml, 'id', this.currentTable_.id.toString())[0];
        if (!xmlTable || xmlTable.hasAttribute('alternative')) {
            return false;
        }
        const rowNode = this.currentTable_.childNodes[row - 1];
        if (!rowNode) {
            return false;
        }
        const xmlRow = DomUtil.querySelectorAllByAttrValue(xmlTable, 'id', rowNode.id.toString())[0];
        if (!xmlRow || xmlRow.hasAttribute('alternative')) {
            return false;
        }
        return !!(rowNode && rowNode.childNodes[column - 1]);
    }
    isInTable_() {
        let snode = this.getFocus().getSemanticPrimary();
        while (snode) {
            if (TableWalker.ELIGIBLE_TABLE_TYPES.indexOf(snode.type) !== -1) {
                this.currentTable_ = snode;
                return true;
            }
            snode = snode.parent;
        }
        return false;
    }
}
TableWalker.ELIGIBLE_CELL_ROLES = [
    SemanticRole.DETERMINANT,
    SemanticRole.ROWVECTOR,
    SemanticRole.BINOMIAL,
    SemanticRole.SQUAREMATRIX,
    SemanticRole.MULTILINE,
    SemanticRole.MATRIX,
    SemanticRole.VECTOR,
    SemanticRole.CASES,
    SemanticRole.TABLE
];
TableWalker.ELIGIBLE_TABLE_TYPES = [
    SemanticType.MULTILINE,
    SemanticType.MATRIX,
    SemanticType.VECTOR,
    SemanticType.CASES,
    SemanticType.TABLE
];
