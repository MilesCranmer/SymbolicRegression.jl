export var Mode;
(function (Mode) {
    Mode["SYNC"] = "sync";
    Mode["ASYNC"] = "async";
    Mode["HTTP"] = "http";
})(Mode || (Mode = {}));
export var personalityProps;
(function (personalityProps) {
    personalityProps["PITCH"] = "pitch";
    personalityProps["RATE"] = "rate";
    personalityProps["VOLUME"] = "volume";
    personalityProps["PAUSE"] = "pause";
    personalityProps["JOIN"] = "join";
    personalityProps["LAYOUT"] = "layout";
})(personalityProps || (personalityProps = {}));
export const personalityPropList = [
    personalityProps.PITCH,
    personalityProps.RATE,
    personalityProps.VOLUME,
    personalityProps.PAUSE,
    personalityProps.JOIN
];
export var Speech;
(function (Speech) {
    Speech["NONE"] = "none";
    Speech["SHALLOW"] = "shallow";
    Speech["DEEP"] = "deep";
})(Speech || (Speech = {}));
export var Markup;
(function (Markup) {
    Markup["NONE"] = "none";
    Markup["LAYOUT"] = "layout";
    Markup["COUNTING"] = "counting";
    Markup["PUNCTUATION"] = "punctuation";
    Markup["SSML"] = "ssml";
    Markup["ACSS"] = "acss";
    Markup["SABLE"] = "sable";
    Markup["VOICEXML"] = "voicexml";
})(Markup || (Markup = {}));
export const DOMAIN_TO_STYLES = {
    mathspeak: 'default',
    clearspeak: 'default'
};
