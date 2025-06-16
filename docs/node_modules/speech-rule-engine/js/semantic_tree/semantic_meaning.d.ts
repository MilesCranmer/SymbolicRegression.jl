import * as Alphabet from '../speech_rules/alphabet.js';
export interface SemanticMeaning {
    type: SemanticType;
    role: SemanticRole;
    font: SemanticFont;
}
declare enum Types {
    PUNCTUATION = "punctuation",
    FENCE = "fence",
    NUMBER = "number",
    IDENTIFIER = "identifier",
    TEXT = "text",
    OPERATOR = "operator",
    RELATION = "relation",
    LARGEOP = "largeop",
    FUNCTION = "function",
    ACCENT = "accent",
    FENCED = "fenced",
    FRACTION = "fraction",
    PUNCTUATED = "punctuated",
    RELSEQ = "relseq",
    MULTIREL = "multirel",
    INFIXOP = "infixop",
    PREFIXOP = "prefixop",
    POSTFIXOP = "postfixop",
    APPL = "appl",
    INTEGRAL = "integral",
    BIGOP = "bigop",
    SQRT = "sqrt",
    ROOT = "root",
    LIMUPPER = "limupper",
    LIMLOWER = "limlower",
    LIMBOTH = "limboth",
    SUBSCRIPT = "subscript",
    SUPERSCRIPT = "superscript",
    UNDERSCORE = "underscore",
    OVERSCORE = "overscore",
    TENSOR = "tensor",
    TABLE = "table",
    MULTILINE = "multiline",
    MATRIX = "matrix",
    VECTOR = "vector",
    CASES = "cases",
    ROW = "row",
    LINE = "line",
    CELL = "cell",
    ENCLOSE = "enclose",
    INFERENCE = "inference",
    RULELABEL = "rulelabel",
    CONCLUSION = "conclusion",
    PREMISES = "premises",
    UNKNOWN = "unknown",
    EMPTY = "empty"
}
export type SemanticType = Types;
export declare const SemanticType: {
    PUNCTUATION: Types.PUNCTUATION;
    FENCE: Types.FENCE;
    NUMBER: Types.NUMBER;
    IDENTIFIER: Types.IDENTIFIER;
    TEXT: Types.TEXT;
    OPERATOR: Types.OPERATOR;
    RELATION: Types.RELATION;
    LARGEOP: Types.LARGEOP;
    FUNCTION: Types.FUNCTION;
    ACCENT: Types.ACCENT;
    FENCED: Types.FENCED;
    FRACTION: Types.FRACTION;
    PUNCTUATED: Types.PUNCTUATED;
    RELSEQ: Types.RELSEQ;
    MULTIREL: Types.MULTIREL;
    INFIXOP: Types.INFIXOP;
    PREFIXOP: Types.PREFIXOP;
    POSTFIXOP: Types.POSTFIXOP;
    APPL: Types.APPL;
    INTEGRAL: Types.INTEGRAL;
    BIGOP: Types.BIGOP;
    SQRT: Types.SQRT;
    ROOT: Types.ROOT;
    LIMUPPER: Types.LIMUPPER;
    LIMLOWER: Types.LIMLOWER;
    LIMBOTH: Types.LIMBOTH;
    SUBSCRIPT: Types.SUBSCRIPT;
    SUPERSCRIPT: Types.SUPERSCRIPT;
    UNDERSCORE: Types.UNDERSCORE;
    OVERSCORE: Types.OVERSCORE;
    TENSOR: Types.TENSOR;
    TABLE: Types.TABLE;
    MULTILINE: Types.MULTILINE;
    MATRIX: Types.MATRIX;
    VECTOR: Types.VECTOR;
    CASES: Types.CASES;
    ROW: Types.ROW;
    LINE: Types.LINE;
    CELL: Types.CELL;
    ENCLOSE: Types.ENCLOSE;
    INFERENCE: Types.INFERENCE;
    RULELABEL: Types.RULELABEL;
    CONCLUSION: Types.CONCLUSION;
    PREMISES: Types.PREMISES;
    UNKNOWN: Types.UNKNOWN;
    EMPTY: Types.EMPTY;
};
declare enum Roles {
    COMMA = "comma",
    SEMICOLON = "semicolon",
    ELLIPSIS = "ellipsis",
    FULLSTOP = "fullstop",
    QUESTION = "question",
    EXCLAMATION = "exclamation",
    QUOTES = "quotes",
    DASH = "dash",
    TILDE = "tilde",
    PRIME = "prime",
    DEGREE = "degree",
    VBAR = "vbar",
    COLON = "colon",
    OPENFENCE = "openfence",
    CLOSEFENCE = "closefence",
    APPLICATION = "application",
    DUMMY = "dummy",
    UNIT = "unit",
    LABEL = "label",
    OPEN = "open",
    CLOSE = "close",
    TOP = "top",
    BOTTOM = "bottom",
    NEUTRAL = "neutral",
    METRIC = "metric",
    LATINLETTER = "latinletter",
    GREEKLETTER = "greekletter",
    OTHERLETTER = "otherletter",
    NUMBERSET = "numbersetletter",
    INTEGER = "integer",
    FLOAT = "float",
    OTHERNUMBER = "othernumber",
    INFTY = "infty",
    MIXED = "mixed",
    MULTIACCENT = "multiaccent",
    OVERACCENT = "overaccent",
    UNDERACCENT = "underaccent",
    UNDEROVER = "underover",
    SUBSUP = "subsup",
    LEFTSUB = "leftsub",
    LEFTSUPER = "leftsuper",
    RIGHTSUB = "rightsub",
    RIGHTSUPER = "rightsuper",
    LEFTRIGHT = "leftright",
    ABOVEBELOW = "abovebelow",
    SETEMPTY = "set empty",
    SETEXT = "set extended",
    SETSINGLE = "set singleton",
    SETCOLLECT = "set collection",
    STRING = "string",
    SPACE = "space",
    ANNOTATION = "annotation",
    TEXT = "text",
    SEQUENCE = "sequence",
    ENDPUNCT = "endpunct",
    STARTPUNCT = "startpunct",
    NEGATIVE = "negative",
    POSITIVE = "positive",
    NEGATION = "negation",
    MULTIOP = "multiop",
    PREFIXOP = "prefix operator",
    POSTFIXOP = "postfix operator",
    LIMFUNC = "limit function",
    INFIXFUNC = "infix function",
    PREFIXFUNC = "prefix function",
    POSTFIXFUNC = "postfix function",
    SIMPLEFUNC = "simple function",
    COMPFUNC = "composed function",
    SUM = "sum",
    INTEGRAL = "integral",
    GEOMETRY = "geometry",
    BOX = "box",
    BLOCK = "block",
    ADDITION = "addition",
    MULTIPLICATION = "multiplication",
    SUBTRACTION = "subtraction",
    IMPLICIT = "implicit",
    DIVISION = "division",
    VULGAR = "vulgar",
    EQUALITY = "equality",
    INEQUALITY = "inequality",
    ARROW = "arrow",
    ELEMENT = "element",
    NONELEMENT = "nonelement",
    REELEMENT = "reelement",
    RENONELEMENT = "renonelement",
    SET = "set",
    DETERMINANT = "determinant",
    ROWVECTOR = "rowvector",
    BINOMIAL = "binomial",
    SQUAREMATRIX = "squarematrix",
    CYCLE = "cycle",
    MULTILINE = "multiline",
    MATRIX = "matrix",
    VECTOR = "vector",
    CASES = "cases",
    TABLE = "table",
    CAYLEY = "cayley",
    PROOF = "proof",
    LEFT = "left",
    RIGHT = "right",
    UP = "up",
    DOWN = "down",
    FINAL = "final",
    SINGLE = "single",
    HYP = "hyp",
    AXIOM = "axiom",
    LOGIC = "logic",
    UNKNOWN = "unknown",
    MGLYPH = "mglyph"
}
export type SemanticRole = Roles;
export declare const SemanticRole: {
    COMMA: Roles.COMMA;
    SEMICOLON: Roles.SEMICOLON;
    ELLIPSIS: Roles.ELLIPSIS;
    FULLSTOP: Roles.FULLSTOP;
    QUESTION: Roles.QUESTION;
    EXCLAMATION: Roles.EXCLAMATION;
    QUOTES: Roles.QUOTES;
    DASH: Roles.DASH;
    TILDE: Roles.TILDE;
    PRIME: Roles.PRIME;
    DEGREE: Roles.DEGREE;
    VBAR: Roles.VBAR;
    COLON: Roles.COLON;
    OPENFENCE: Roles.OPENFENCE;
    CLOSEFENCE: Roles.CLOSEFENCE;
    APPLICATION: Roles.APPLICATION;
    DUMMY: Roles.DUMMY;
    UNIT: Roles.UNIT;
    LABEL: Roles.LABEL;
    OPEN: Roles.OPEN;
    CLOSE: Roles.CLOSE;
    TOP: Roles.TOP;
    BOTTOM: Roles.BOTTOM;
    NEUTRAL: Roles.NEUTRAL;
    METRIC: Roles.METRIC;
    LATINLETTER: Roles.LATINLETTER;
    GREEKLETTER: Roles.GREEKLETTER;
    OTHERLETTER: Roles.OTHERLETTER;
    NUMBERSET: Roles.NUMBERSET;
    INTEGER: Roles.INTEGER;
    FLOAT: Roles.FLOAT;
    OTHERNUMBER: Roles.OTHERNUMBER;
    INFTY: Roles.INFTY;
    MIXED: Roles.MIXED;
    MULTIACCENT: Roles.MULTIACCENT;
    OVERACCENT: Roles.OVERACCENT;
    UNDERACCENT: Roles.UNDERACCENT;
    UNDEROVER: Roles.UNDEROVER;
    SUBSUP: Roles.SUBSUP;
    LEFTSUB: Roles.LEFTSUB;
    LEFTSUPER: Roles.LEFTSUPER;
    RIGHTSUB: Roles.RIGHTSUB;
    RIGHTSUPER: Roles.RIGHTSUPER;
    LEFTRIGHT: Roles.LEFTRIGHT;
    ABOVEBELOW: Roles.ABOVEBELOW;
    SETEMPTY: Roles.SETEMPTY;
    SETEXT: Roles.SETEXT;
    SETSINGLE: Roles.SETSINGLE;
    SETCOLLECT: Roles.SETCOLLECT;
    STRING: Roles.STRING;
    SPACE: Roles.SPACE;
    ANNOTATION: Roles.ANNOTATION;
    TEXT: Roles.TEXT;
    SEQUENCE: Roles.SEQUENCE;
    ENDPUNCT: Roles.ENDPUNCT;
    STARTPUNCT: Roles.STARTPUNCT;
    NEGATIVE: Roles.NEGATIVE;
    POSITIVE: Roles.POSITIVE;
    NEGATION: Roles.NEGATION;
    MULTIOP: Roles.MULTIOP;
    PREFIXOP: Roles.PREFIXOP;
    POSTFIXOP: Roles.POSTFIXOP;
    LIMFUNC: Roles.LIMFUNC;
    INFIXFUNC: Roles.INFIXFUNC;
    PREFIXFUNC: Roles.PREFIXFUNC;
    POSTFIXFUNC: Roles.POSTFIXFUNC;
    SIMPLEFUNC: Roles.SIMPLEFUNC;
    COMPFUNC: Roles.COMPFUNC;
    SUM: Roles.SUM;
    INTEGRAL: Roles.INTEGRAL;
    GEOMETRY: Roles.GEOMETRY;
    BOX: Roles.BOX;
    BLOCK: Roles.BLOCK;
    ADDITION: Roles.ADDITION;
    MULTIPLICATION: Roles.MULTIPLICATION;
    SUBTRACTION: Roles.SUBTRACTION;
    IMPLICIT: Roles.IMPLICIT;
    DIVISION: Roles.DIVISION;
    VULGAR: Roles.VULGAR;
    EQUALITY: Roles.EQUALITY;
    INEQUALITY: Roles.INEQUALITY;
    ARROW: Roles.ARROW;
    ELEMENT: Roles.ELEMENT;
    NONELEMENT: Roles.NONELEMENT;
    REELEMENT: Roles.REELEMENT;
    RENONELEMENT: Roles.RENONELEMENT;
    SET: Roles.SET;
    DETERMINANT: Roles.DETERMINANT;
    ROWVECTOR: Roles.ROWVECTOR;
    BINOMIAL: Roles.BINOMIAL;
    SQUAREMATRIX: Roles.SQUAREMATRIX;
    CYCLE: Roles.CYCLE;
    MULTILINE: Roles.MULTILINE;
    MATRIX: Roles.MATRIX;
    VECTOR: Roles.VECTOR;
    CASES: Roles.CASES;
    TABLE: Roles.TABLE;
    CAYLEY: Roles.CAYLEY;
    PROOF: Roles.PROOF;
    LEFT: Roles.LEFT;
    RIGHT: Roles.RIGHT;
    UP: Roles.UP;
    DOWN: Roles.DOWN;
    FINAL: Roles.FINAL;
    SINGLE: Roles.SINGLE;
    HYP: Roles.HYP;
    AXIOM: Roles.AXIOM;
    LOGIC: Roles.LOGIC;
    UNKNOWN: Roles.UNKNOWN;
    MGLYPH: Roles.MGLYPH;
};
declare enum ExtraFont {
    CALIGRAPHIC = "caligraphic",
    CALIGRAPHICBOLD = "caligraphic-bold",
    OLDSTYLE = "oldstyle",
    OLDSTYLEBOLD = "oldstyle-bold",
    UNKNOWN = "unknown"
}
export type SemanticFont = Alphabet.Font | ExtraFont | Alphabet.Embellish;
export declare const SemanticFont: {
    SUPER: Alphabet.Embellish.SUPER;
    SUB: Alphabet.Embellish.SUB;
    CIRCLED: Alphabet.Embellish.CIRCLED;
    PARENTHESIZED: Alphabet.Embellish.PARENTHESIZED;
    PERIOD: Alphabet.Embellish.PERIOD;
    NEGATIVECIRCLED: Alphabet.Embellish.NEGATIVECIRCLED;
    DOUBLECIRCLED: Alphabet.Embellish.DOUBLECIRCLED;
    CIRCLEDSANSSERIF: Alphabet.Embellish.CIRCLEDSANSSERIF;
    NEGATIVECIRCLEDSANSSERIF: Alphabet.Embellish.NEGATIVECIRCLEDSANSSERIF;
    COMMA: Alphabet.Embellish.COMMA;
    SQUARED: Alphabet.Embellish.SQUARED;
    NEGATIVESQUARED: Alphabet.Embellish.NEGATIVESQUARED;
    CALIGRAPHIC: ExtraFont.CALIGRAPHIC;
    CALIGRAPHICBOLD: ExtraFont.CALIGRAPHICBOLD;
    OLDSTYLE: ExtraFont.OLDSTYLE;
    OLDSTYLEBOLD: ExtraFont.OLDSTYLEBOLD;
    UNKNOWN: ExtraFont.UNKNOWN;
    BOLD: Alphabet.Font.BOLD;
    BOLDFRAKTUR: Alphabet.Font.BOLDFRAKTUR;
    BOLDITALIC: Alphabet.Font.BOLDITALIC;
    BOLDSCRIPT: Alphabet.Font.BOLDSCRIPT;
    DOUBLESTRUCK: Alphabet.Font.DOUBLESTRUCK;
    DOUBLESTRUCKITALIC: Alphabet.Font.DOUBLESTRUCKITALIC;
    FULLWIDTH: Alphabet.Font.FULLWIDTH;
    FRAKTUR: Alphabet.Font.FRAKTUR;
    ITALIC: Alphabet.Font.ITALIC;
    MONOSPACE: Alphabet.Font.MONOSPACE;
    NORMAL: Alphabet.Font.NORMAL;
    SCRIPT: Alphabet.Font.SCRIPT;
    SANSSERIF: Alphabet.Font.SANSSERIF;
    SANSSERIFITALIC: Alphabet.Font.SANSSERIFITALIC;
    SANSSERIFBOLD: Alphabet.Font.SANSSERIFBOLD;
    SANSSERIFBOLDITALIC: Alphabet.Font.SANSSERIFBOLDITALIC;
};
declare enum SecondaryEnum {
    ALLLETTERS = "allLetters",
    D = "d",
    BAR = "bar",
    TILDE = "tilde"
}
export type SemanticSecondary = Alphabet.Base | SecondaryEnum;
export declare const SemanticSecondary: {
    ALLLETTERS: SecondaryEnum.ALLLETTERS;
    D: SecondaryEnum.D;
    BAR: SecondaryEnum.BAR;
    TILDE: SecondaryEnum.TILDE;
    LATINCAP: Alphabet.Base.LATINCAP;
    LATINSMALL: Alphabet.Base.LATINSMALL;
    GREEKCAP: Alphabet.Base.GREEKCAP;
    GREEKSMALL: Alphabet.Base.GREEKSMALL;
    DIGIT: Alphabet.Base.DIGIT;
};
export {};
