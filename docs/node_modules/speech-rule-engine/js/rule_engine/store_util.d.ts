import { AuditoryDescription } from '../audio/auditory_description.js';
export declare function nodeCounter(nodes: Element[], context: string | null): () => string;
export declare function pauseSeparator(_nodes: Element[], context: string): () => AuditoryDescription[];
export declare function contentIterator(nodes: Element[], context: string): () => AuditoryDescription[];
