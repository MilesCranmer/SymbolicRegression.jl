import { SemanticAnnotator } from './semantic_annotator.js';
export const annotators = new Map();
export const visitors = new Map();
export function register(annotator) {
    const name = annotator.domain + ':' + annotator.name;
    annotator instanceof SemanticAnnotator
        ? annotators.set(name, annotator)
        : visitors.set(name, annotator);
}
export function activate(domain, name) {
    const key = domain + ':' + name;
    const annotator = annotators.get(key) || visitors.get(key);
    if (annotator) {
        annotator.active = true;
    }
}
export function deactivate(domain, name) {
    const key = domain + ':' + name;
    const annotator = annotators.get(key) || visitors.get(key);
    if (annotator) {
        annotator.active = false;
    }
}
export function annotate(node) {
    for (const annotator of annotators.values()) {
        if (annotator.active) {
            annotator.annotate(node);
        }
    }
    for (const visitor of visitors.values()) {
        if (visitor.active) {
            visitor.visit(node, Object.assign({}, visitor.def));
        }
    }
}
