export class SemanticAnnotator {
    constructor(domain, name, func) {
        this.domain = domain;
        this.name = name;
        this.func = func;
        this.active = false;
    }
    annotate(node) {
        node.childNodes.forEach(this.annotate.bind(this));
        node.contentNodes.forEach(this.annotate.bind(this));
        node.addAnnotation(this.domain, this.func(node));
    }
}
export class SemanticVisitor {
    constructor(domain, name, func, def = {}) {
        this.domain = domain;
        this.name = name;
        this.func = func;
        this.def = def;
        this.active = false;
    }
    visit(node, info) {
        let result = this.func(node, info);
        node.addAnnotation(this.domain, result[0]);
        for (let i = 0, child; (child = node.childNodes[i]); i++) {
            result = this.visit(child, result[1]);
        }
        for (let i = 0, content; (content = node.contentNodes[i]); i++) {
            result = this.visit(content, result[1]);
        }
        return result;
    }
}
