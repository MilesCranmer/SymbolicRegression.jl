onfail(f, ::Test.Fail) = f()
onfail(_, ::Test.Pass) = nothing
