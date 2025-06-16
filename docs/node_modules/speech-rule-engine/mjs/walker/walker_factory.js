import { DummyWalker } from './dummy_walker.js';
import { SemanticWalker } from './semantic_walker.js';
import { SyntaxWalker } from './syntax_walker.js';
import { TableWalker } from './table_walker.js';
export function walker(type, node, generator, highlighter, xml) {
    const constructor = walkerMapping[type.toLowerCase()] || walkerMapping['dummy'];
    return constructor(node, generator, highlighter, xml);
}
const walkerMapping = {
    dummy: (p1, p2, p3, p4) => new DummyWalker(p1, p2, p3, p4),
    semantic: (p1, p2, p3, p4) => new SemanticWalker(p1, p2, p3, p4),
    syntax: (p1, p2, p3, p4) => new SyntaxWalker(p1, p2, p3, p4),
    table: (p1, p2, p3, p4) => new TableWalker(p1, p2, p3, p4)
};
