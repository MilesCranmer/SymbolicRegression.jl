export type Transformer = (p1: string | number) => string;
export type Combiner = (p1: string, p2: string, p3: string) => string;
export type SiCombiner = (p1: string, p2: string) => string;
export type GrammarCase = (p1: number, p2: boolean) => string;
export declare function pluralCase(num: number, _plural: boolean): string;
export declare function identityTransformer(input: string | number): string;
export declare function siCombiner(prefix: string, unit: string): string;
export declare const Combiners: Record<string, Combiner>;
interface Convertible {
    convertible: boolean;
    content?: string;
    denominator?: number;
    enumerator?: number;
}
export declare function convertVulgarFraction(node: Element, over?: string): Convertible;
export declare function vulgarFractionSmall(node: Element, enumer: number, denom: number): boolean;
export {};
