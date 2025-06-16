"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.visitors = exports.annotators = void 0;
exports.register = register;
exports.activate = activate;
exports.deactivate = deactivate;
exports.annotate = annotate;
const semantic_annotator_js_1 = require("./semantic_annotator.js");
exports.annotators = new Map();
exports.visitors = new Map();
function register(annotator) {
    const name = annotator.domain + ':' + annotator.name;
    annotator instanceof semantic_annotator_js_1.SemanticAnnotator
        ? exports.annotators.set(name, annotator)
        : exports.visitors.set(name, annotator);
}
function activate(domain, name) {
    const key = domain + ':' + name;
    const annotator = exports.annotators.get(key) || exports.visitors.get(key);
    if (annotator) {
        annotator.active = true;
    }
}
function deactivate(domain, name) {
    const key = domain + ':' + name;
    const annotator = exports.annotators.get(key) || exports.visitors.get(key);
    if (annotator) {
        annotator.active = false;
    }
}
function annotate(node) {
    for (const annotator of exports.annotators.values()) {
        if (annotator.active) {
            annotator.annotate(node);
        }
    }
    for (const visitor of exports.visitors.values()) {
        if (visitor.active) {
            visitor.visit(node, Object.assign({}, visitor.def));
        }
    }
}
