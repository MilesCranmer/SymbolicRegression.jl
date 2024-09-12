using LaSR
using Aqua

Aqua.test_all(LaSR; ambiguities=false)

VERSION >= v"1.9" && Aqua.test_ambiguities(LaSR)
