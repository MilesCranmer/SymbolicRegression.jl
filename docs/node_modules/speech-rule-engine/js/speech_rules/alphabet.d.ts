export declare enum Font {
    BOLD = "bold",
    BOLDFRAKTUR = "bold-fraktur",
    BOLDITALIC = "bold-italic",
    BOLDSCRIPT = "bold-script",
    DOUBLESTRUCK = "double-struck",
    DOUBLESTRUCKITALIC = "double-struck-italic",
    FULLWIDTH = "fullwidth",
    FRAKTUR = "fraktur",
    ITALIC = "italic",
    MONOSPACE = "monospace",
    NORMAL = "normal",
    SCRIPT = "script",
    SANSSERIF = "sans-serif",
    SANSSERIFITALIC = "sans-serif-italic",
    SANSSERIFBOLD = "sans-serif-bold",
    SANSSERIFBOLDITALIC = "sans-serif-bold-italic"
}
export declare enum Embellish {
    SUPER = "super",
    SUB = "sub",
    CIRCLED = "circled",
    PARENTHESIZED = "parenthesized",
    PERIOD = "period",
    NEGATIVECIRCLED = "negative-circled",
    DOUBLECIRCLED = "double-circled",
    CIRCLEDSANSSERIF = "circled-sans-serif",
    NEGATIVECIRCLEDSANSSERIF = "negative-circled-sans-serif",
    COMMA = "comma",
    SQUARED = "squared",
    NEGATIVESQUARED = "negative-squared"
}
export declare enum Base {
    LATINCAP = "latinCap",
    LATINSMALL = "latinSmall",
    GREEKCAP = "greekCap",
    GREEKSMALL = "greekSmall",
    DIGIT = "digit"
}
export declare function makeInterval([a, b]: [string, string], subst: {
    [key: string]: string | boolean;
}): string[];
export declare function makeMultiInterval(ints: (string | [string, string])[]): string[];
export declare function makeCodeInterval(ints: (string | [string, string])[]): number[];
export declare interface ProtoAlphabet {
    interval: [string, string];
    base: Base;
    subst: {
        [key: string]: string | boolean;
    };
    category: string;
    font: Font | Embellish;
    capital?: boolean;
    offset?: number;
}
export declare interface Alphabet extends ProtoAlphabet {
    unicode: string[];
}
export declare const INTERVALS: Map<string, Alphabet>;
export declare function alphabetName(base: string, font: string): string;
