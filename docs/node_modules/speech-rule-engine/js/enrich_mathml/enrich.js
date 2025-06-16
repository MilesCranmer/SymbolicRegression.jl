"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.semanticMathmlNode = semanticMathmlNode;
exports.semanticMathmlSync = semanticMathmlSync;
exports.semanticMathml = semanticMathml;
exports.testTranslation = testTranslation;
exports.prepareMmlString = prepareMmlString;
const debugger_js_1 = require("../common/debugger.js");
const DomUtil = require("../common/dom_util.js");
const engine_js_1 = require("../common/engine.js");
const Semantic = require("../semantic_tree/semantic.js");
const EnrichMathml = require("./enrich_mathml.js");
require("./enrich_case_factory.js");
function semanticMathmlNode(mml) {
    const clone = DomUtil.cloneNode(mml);
    const tree = Semantic.getTree(clone);
    return EnrichMathml.enrich(clone, tree);
}
function semanticMathmlSync(expr) {
    const mml = DomUtil.parseInput(expr);
    return semanticMathmlNode(mml);
}
function semanticMathml(expr, callback) {
    engine_js_1.EnginePromise.getall().then(() => {
        const mml = DomUtil.parseInput(expr);
        callback(semanticMathmlNode(mml));
    });
}
function testTranslation(expr) {
    debugger_js_1.Debugger.getInstance().init();
    const mml = semanticMathmlSync(prepareMmlString(expr));
    debugger_js_1.Debugger.getInstance().exit();
    return mml;
}
function prepareMmlString(expr) {
    if (!expr.match(/^<math/)) {
        expr = '<math>' + expr;
    }
    if (!expr.match(/\/math>$/)) {
        expr += '</math>';
    }
    return expr;
}
