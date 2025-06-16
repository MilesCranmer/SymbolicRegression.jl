import * as DomUtil from '../common/dom_util.js';
import { SemanticTree } from './semantic_tree.js';
export function xmlTree(mml) {
    return getTree(mml).xml();
}
export function getTree(mml) {
    return new SemanticTree(mml);
}
export function getTreeFromString(expr) {
    const mml = DomUtil.parseInput(expr);
    return getTree(mml);
}
