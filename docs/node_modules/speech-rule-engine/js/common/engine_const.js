"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.DOMAIN_TO_STYLES = exports.Markup = exports.Speech = exports.personalityPropList = exports.personalityProps = exports.Mode = void 0;
var Mode;
(function (Mode) {
    Mode["SYNC"] = "sync";
    Mode["ASYNC"] = "async";
    Mode["HTTP"] = "http";
})(Mode || (exports.Mode = Mode = {}));
var personalityProps;
(function (personalityProps) {
    personalityProps["PITCH"] = "pitch";
    personalityProps["RATE"] = "rate";
    personalityProps["VOLUME"] = "volume";
    personalityProps["PAUSE"] = "pause";
    personalityProps["JOIN"] = "join";
    personalityProps["LAYOUT"] = "layout";
})(personalityProps || (exports.personalityProps = personalityProps = {}));
exports.personalityPropList = [
    personalityProps.PITCH,
    personalityProps.RATE,
    personalityProps.VOLUME,
    personalityProps.PAUSE,
    personalityProps.JOIN
];
var Speech;
(function (Speech) {
    Speech["NONE"] = "none";
    Speech["SHALLOW"] = "shallow";
    Speech["DEEP"] = "deep";
})(Speech || (exports.Speech = Speech = {}));
var Markup;
(function (Markup) {
    Markup["NONE"] = "none";
    Markup["LAYOUT"] = "layout";
    Markup["COUNTING"] = "counting";
    Markup["PUNCTUATION"] = "punctuation";
    Markup["SSML"] = "ssml";
    Markup["ACSS"] = "acss";
    Markup["SABLE"] = "sable";
    Markup["VOICEXML"] = "voicexml";
})(Markup || (exports.Markup = Markup = {}));
exports.DOMAIN_TO_STYLES = {
    mathspeak: 'default',
    clearspeak: 'default'
};
