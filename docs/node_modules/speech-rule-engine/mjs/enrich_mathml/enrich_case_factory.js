import { CaseBinomial } from './case_binomial.js';
import { CaseDoubleScript } from './case_double_script.js';
import { CaseEmbellished } from './case_embellished.js';
import { CaseEmpheq } from './case_empheq.js';
import { CaseLimit } from './case_limit.js';
import { CaseLine } from './case_line.js';
import { CaseMultiscripts } from './case_multiscripts.js';
import { CaseProof } from './case_proof.js';
import { CaseTable } from './case_table.js';
import { CaseTensor } from './case_tensor.js';
import { CaseText } from './case_text.js';
import { factory } from './enrich_case.js';
factory.push(...[
    {
        test: CaseLimit.test,
        constr: (node) => new CaseLimit(node)
    },
    {
        test: CaseEmbellished.test,
        constr: (node) => new CaseEmbellished(node)
    },
    {
        test: CaseDoubleScript.test,
        constr: (node) => new CaseDoubleScript(node)
    },
    {
        test: CaseTensor.test,
        constr: (node) => new CaseTensor(node)
    },
    {
        test: CaseMultiscripts.test,
        constr: (node) => new CaseMultiscripts(node)
    },
    { test: CaseLine.test, constr: (node) => new CaseLine(node) },
    {
        test: CaseBinomial.test,
        constr: (node) => new CaseBinomial(node)
    },
    {
        test: CaseProof.test,
        constr: (node) => new CaseProof(node)
    },
    {
        test: CaseEmpheq.test,
        constr: (node) => new CaseEmpheq(node)
    },
    {
        test: CaseTable.test,
        constr: (node) => new CaseTable(node)
    },
    { test: CaseText.test, constr: (node) => new CaseText(node) }
]);
