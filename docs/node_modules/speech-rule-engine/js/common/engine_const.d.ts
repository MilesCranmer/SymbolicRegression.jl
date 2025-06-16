export declare enum Mode {
    SYNC = "sync",
    ASYNC = "async",
    HTTP = "http"
}
export declare enum personalityProps {
    PITCH = "pitch",
    RATE = "rate",
    VOLUME = "volume",
    PAUSE = "pause",
    JOIN = "join",
    LAYOUT = "layout"
}
export declare const personalityPropList: personalityProps[];
export declare enum Speech {
    NONE = "none",
    SHALLOW = "shallow",
    DEEP = "deep"
}
export declare enum Markup {
    NONE = "none",
    LAYOUT = "layout",
    COUNTING = "counting",
    PUNCTUATION = "punctuation",
    SSML = "ssml",
    ACSS = "acss",
    SABLE = "sable",
    VOICEXML = "voicexml"
}
export declare const DOMAIN_TO_STYLES: {
    [key: string]: string;
};
