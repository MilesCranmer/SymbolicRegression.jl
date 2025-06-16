import { Debugger } from '../common/debugger.js';
import * as DomUtil from '../common/dom_util.js';
import { EnginePromise } from '../common/engine.js';
import * as Semantic from '../semantic_tree/semantic.js';
import * as EnrichMathml from './enrich_mathml.js';
import './enrich_case_factory.js';
export function semanticMathmlNode(mml) {
    const clone = DomUtil.cloneNode(mml);
    const tree = Semantic.getTree(clone);
    return EnrichMathml.enrich(clone, tree);
}
export function semanticMathmlSync(expr) {
    const mml = DomUtil.parseInput(expr);
    return semanticMathmlNode(mml);
}
export function semanticMathml(expr, callback) {
    EnginePromise.getall().then(() => {
        const mml = DomUtil.parseInput(expr);
        callback(semanticMathmlNode(mml));
    });
}
export function testTranslation(expr) {
    Debugger.getInstance().init();
    const mml = semanticMathmlSync(prepareMmlString(expr));
    Debugger.getInstance().exit();
    return mml;
}
export function prepareMmlString(expr) {
    if (!expr.match(/^<math/)) {
        expr = '<math>' + expr;
    }
    if (!expr.match(/\/math>$/)) {
        expr += '</math>';
    }
    return expr;
}
