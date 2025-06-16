"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.factory = void 0;
exports.getCase = getCase;
function getCase(node) {
    for (let i = 0, enrich; (enrich = exports.factory[i]); i++) {
        if (enrich.test(node)) {
            return enrich.constr(node);
        }
    }
    return null;
}
exports.factory = [];
