export function getCase(node) {
    for (let i = 0, enrich; (enrich = factory[i]); i++) {
        if (enrich.test(node)) {
            return enrich.constr(node);
        }
    }
    return null;
}
export const factory = [];
