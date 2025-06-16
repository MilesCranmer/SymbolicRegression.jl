"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.baselineVerbose = baselineVerbose;
exports.baselineBrief = baselineBrief;
exports.leftSuperscriptVerbose = leftSuperscriptVerbose;
exports.leftSubscriptVerbose = leftSubscriptVerbose;
exports.leftSuperscriptBrief = leftSuperscriptBrief;
exports.leftSubscriptBrief = leftSubscriptBrief;
const MathspeakUtil = require("./mathspeak_util.js");
function baselineVerbose(node) {
    const baseline = MathspeakUtil.baselineVerbose(node);
    baseline[0].speech = baseline[0].speech.replace(/-$/, '');
    return baseline;
}
function baselineBrief(node) {
    const baseline = MathspeakUtil.baselineBrief(node);
    baseline[0].speech = baseline[0].speech.replace(/-$/, '');
    return baseline;
}
function leftSuperscriptVerbose(node) {
    const leftIndex = MathspeakUtil.superscriptVerbose(node);
    leftIndex[0].speech = leftIndex[0].speech.replace(/^exposant/, 'exposant gauche');
    return leftIndex;
}
function leftSubscriptVerbose(node) {
    const leftIndex = MathspeakUtil.subscriptVerbose(node);
    leftIndex[0].speech = leftIndex[0].speech.replace(/^indice/, 'indice gauche');
    return leftIndex;
}
function leftSuperscriptBrief(node) {
    const leftIndex = MathspeakUtil.superscriptBrief(node);
    leftIndex[0].speech = leftIndex[0].speech.replace(/^sup/, 'sup gauche');
    return leftIndex;
}
function leftSubscriptBrief(node) {
    const leftIndex = MathspeakUtil.subscriptBrief(node);
    leftIndex[0].speech = leftIndex[0].speech.replace(/^sub/, 'sub gauche');
    return leftIndex;
}
