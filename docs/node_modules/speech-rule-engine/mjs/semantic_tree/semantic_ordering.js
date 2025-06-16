import { SemanticRole, SemanticType } from './semantic_meaning.js';
const comparators = [];
function add(comparator) {
    comparators.push(comparator);
}
function apply(meaning1, meaning2) {
    for (let i = 0, comparator; (comparator = comparators[i]); i++) {
        const result = comparator.compare(meaning1, meaning2);
        if (result !== 0) {
            return result;
        }
    }
    return 0;
}
function sort(meanings) {
    meanings.sort(apply);
}
export function reduce(meanings) {
    if (meanings.length <= 1) {
        return meanings;
    }
    const copy = meanings.slice();
    sort(copy);
    const result = [];
    let last;
    do {
        last = copy.pop();
        result.push(last);
    } while (last && copy.length && apply(copy[copy.length - 1], last) === 0);
    return result;
}
class SemanticComparator {
    constructor(comparator, type = null) {
        this.comparator = comparator;
        this.type = type;
        add(this);
    }
    compare(meaning1, meaning2) {
        return this.type &&
            this.type === meaning1.type &&
            this.type === meaning2.type
            ? this.comparator(meaning1, meaning2)
            : 0;
    }
}
function simpleFunction(meaning1, meaning2) {
    if (meaning1.role === SemanticRole.SIMPLEFUNC) {
        return 1;
    }
    if (meaning2.role === SemanticRole.SIMPLEFUNC) {
        return -1;
    }
    return 0;
}
new SemanticComparator(simpleFunction, SemanticType.IDENTIFIER);
