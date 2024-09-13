using LibraryAugmentedSymbolicRegression
using Aqua

Aqua.test_all(LibraryAugmentedSymbolicRegression; ambiguities=false)

VERSION >= v"1.9" && Aqua.test_ambiguities(LibraryAugmentedSymbolicRegression)
