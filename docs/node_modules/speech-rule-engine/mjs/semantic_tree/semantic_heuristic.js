class SemanticAbstractHeuristic {
    constructor(name, method, predicate = (_x) => false) {
        this.name = name;
        this.apply = method;
        this.applicable = predicate;
    }
}
export class SemanticTreeHeuristic extends SemanticAbstractHeuristic {
}
export class SemanticMultiHeuristic extends SemanticAbstractHeuristic {
}
export class SemanticMmlHeuristic extends SemanticAbstractHeuristic {
}
