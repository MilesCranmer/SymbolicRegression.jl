import * as MathspeakUtil from './mathspeak_util.js';
export function baselineVerbose(node) {
    const baseline = MathspeakUtil.baselineVerbose(node);
    baseline[0].speech = baseline[0].speech.replace(/-$/, '');
    return baseline;
}
export function baselineBrief(node) {
    const baseline = MathspeakUtil.baselineBrief(node);
    baseline[0].speech = baseline[0].speech.replace(/-$/, '');
    return baseline;
}
export function leftSuperscriptVerbose(node) {
    const leftIndex = MathspeakUtil.superscriptVerbose(node);
    leftIndex[0].speech = leftIndex[0].speech.replace(/^exposant/, 'exposant gauche');
    return leftIndex;
}
export function leftSubscriptVerbose(node) {
    const leftIndex = MathspeakUtil.subscriptVerbose(node);
    leftIndex[0].speech = leftIndex[0].speech.replace(/^indice/, 'indice gauche');
    return leftIndex;
}
export function leftSuperscriptBrief(node) {
    const leftIndex = MathspeakUtil.superscriptBrief(node);
    leftIndex[0].speech = leftIndex[0].speech.replace(/^sup/, 'sup gauche');
    return leftIndex;
}
export function leftSubscriptBrief(node) {
    const leftIndex = MathspeakUtil.subscriptBrief(node);
    leftIndex[0].speech = leftIndex[0].speech.replace(/^sub/, 'sub gauche');
    return leftIndex;
}
