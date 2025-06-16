export function removeEmpty(strs) {
    return strs.filter((str) => str);
}
export function interleaveLists(list1, list2) {
    const result = [];
    while (list1.length || list2.length) {
        if (list1.length) {
            result.push(list1.shift());
        }
        if (list2.length) {
            result.push(list2.shift());
        }
    }
    return result;
}
export function setdifference(a, b) {
    if (!a) {
        return [];
    }
    if (!b) {
        return a;
    }
    return a.filter((x) => b.indexOf(x) < 0);
}
