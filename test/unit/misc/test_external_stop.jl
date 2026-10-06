@testitem "ExternalStop drains and filters trigger bytes" begin
    using SymbolicRegression
    using SymbolicRegression.SearchModule.SearchUtilsModule:
        check_stop_fd, check_external_stop

    @test @inferred(check_external_stop(nothing)) === false

    direct_stop = ExternalStop()
    @test !check_external_stop(direct_stop)
    direct_stop.requested[] = true
    @test check_external_stop(direct_stop)

    @static if Sys.iswindows()
        socks = Vector{UInt}(undef, 2)
        @test ccall(
            :uv_socketpair, Cint, (Cint, Cint, Ptr{UInt}, Cint, Cint), 1, 0, socks, 0, 0
        ) == 0
        read_sock, write_sock = socks
        function write_byte(byte)
            return ccall(
                (:send, "ws2_32"),
                stdcall,
                Cint,
                (UInt, Ref{UInt8}, Cint, Cint),
                write_sock,
                Ref(UInt8(byte)),
                1,
                0,
            )
        end

        try
            stop = ExternalStop(read_sock, 2)
            @test !check_stop_fd(stop)

            write_byte(14)
            write_byte(14)
            @test !check_stop_fd(stop)

            write_byte(14)
            write_byte(2)
            write_byte(14)
            @test check_stop_fd(stop)
            @test !check_stop_fd(stop)
        finally
            ccall((:closesocket, "ws2_32"), stdcall, Cint, (UInt,), read_sock)
            ccall((:closesocket, "ws2_32"), stdcall, Cint, (UInt,), write_sock)
        end
    else
        fds = Vector{Cint}(undef, 2)
        @test ccall(:pipe, Cint, (Ptr{Cint},), fds) == 0
        read_fd, write_fd = fds
        function write_byte(byte)
            return ccall(
                :write, Cssize_t, (Cint, Ref{UInt8}, Csize_t), write_fd, Ref(UInt8(byte)), 1
            )
        end

        try
            flags = ccall(:fcntl, Cint, (Cint, Cint), read_fd, Cint(3))
            nonblocking = Sys.isbsd() ? Cint(0x0004) : Cint(0x0800)
            @test flags >= 0
            @test ccall(
                :fcntl, Cint, (Cint, Cint, Cint), read_fd, Cint(4), flags | nonblocking
            ) == 0

            stop = ExternalStop(read_fd, 2)
            @test !check_stop_fd(stop)

            write_byte(14)
            write_byte(14)
            @test !check_stop_fd(stop)

            write_byte(14)
            write_byte(2)
            write_byte(14)
            @test check_stop_fd(stop)
            @test !check_stop_fd(stop)
        finally
            ccall(:close, Cint, (Cint,), read_fd)
            ccall(:close, Cint, (Cint,), write_fd)
        end
    end
end

@testitem "Teardown drains notifications queued for a finished search" begin
    using DynamicExpressions: AbstractExpression, Node
    using SymbolicRegression
    using SymbolicRegression.SearchModule.SearchUtilsModule:
        AbstractRuntimeOptions, AbstractSearchState, check_stop_fd, drain_external_stop!
    import SymbolicRegression.SearchModule.SearchUtilsModule: close_reader!, external_stop

    @test drain_external_stop!(nothing) === nothing

    struct DrainProbeExpression <: AbstractExpression{Float64,Node{Float64}} end
    struct DrainProbeReader end
    close_reader!(::DrainProbeReader) = nothing
    struct DrainProbeRuntimeOptions <: AbstractRuntimeOptions
        parallelism::Symbol
        external_stop::ExternalStop
    end
    external_stop(ropt::DrainProbeRuntimeOptions) = ropt.external_stop
    struct DrainProbeSearchState <:
           AbstractSearchState{Float64,Float64,DrainProbeExpression}
        plugin_states::Vector{Tuple{}}
        stdin_reader::DrainProbeReader
    end

    if !Sys.iswindows()
        fds = Vector{Cint}(undef, 2)
        @test ccall(:pipe, Cint, (Ptr{Cint},), fds) == 0
        read_fd, write_fd = fds
        try
            flags = ccall(:fcntl, Cint, (Cint, Cint), read_fd, Cint(3))
            nonblocking = Sys.isbsd() ? Cint(0x0004) : Cint(0x0800)
            @test flags >= 0
            @test ccall(
                :fcntl, Cint, (Cint, Cint, Cint), read_fd, Cint(4), flags | nonblocking
            ) == 0

            options = Options(;
                binary_operators=[+, *], save_to_file=false, plugins=(), default_plugins=()
            )
            ropt = DrainProbeRuntimeOptions(:serial, ExternalStop(read_fd, 0))
            state = DrainProbeSearchState([()], DrainProbeReader())

            # A notification lands during search N's teardown window:
            @test ccall(
                :write, Cssize_t, (Cint, Ref{UInt8}, Csize_t), write_fd, Ref(UInt8(0)), 1
            ) == 1
            SymbolicRegression._tear_down!(state, [nothing], ropt, options)

            # Search N+1 reusing the descriptor must not observe it:
            next_search_stop = ExternalStop(read_fd, 0)
            @test !check_stop_fd(next_search_stop)
        finally
            ccall(:close, Cint, (Cint,), read_fd)
            ccall(:close, Cint, (Cint,), write_fd)
        end
    end
end

@testitem "Custom AbstractRuntimeOptions default to no external stop" begin
    using SymbolicRegression.SearchModule.SearchUtilsModule:
        AbstractRuntimeOptions, check_external_stop, external_stop, latch_external_stop!

    struct NoStopRuntimeOptions <: AbstractRuntimeOptions end

    ropt = NoStopRuntimeOptions()
    @test external_stop(ropt) === nothing
    @test !check_external_stop(ropt)
    @test !latch_external_stop!(ropt)
end

@testitem "ExternalStop preserves requests queued before search entry" begin
    using SymbolicRegression

    if !Sys.iswindows()
        mutable struct CycleLogger <: SymbolicRegression.AbstractSRLogger
            cycles_remaining::Vector{Vector{Int}}
        end
        function SymbolicRegression.logging_callback!(logger::CycleLogger; state, kws...)
            push!(logger.cycles_remaining, copy(state.cycles_remaining))
            return nothing
        end

        fds = Vector{Cint}(undef, 2)
        @test ccall(:pipe, Cint, (Ptr{Cint},), fds) == 0
        read_fd, write_fd = fds
        try
            stop = ExternalStop(read_fd, 2)
            for byte in (14, 2, 14)
                @test ccall(
                    :write,
                    Cssize_t,
                    (Cint, Ref{UInt8}, Csize_t),
                    write_fd,
                    Ref(UInt8(byte)),
                    1,
                ) == 1
            end

            logger = CycleLogger(Vector{Int}[])
            options = Options(;
                binary_operators=[+, *],
                population_size=20,
                populations=1,
                ncycles_per_iteration=1,
                verbosity=0,
                progress=false,
            )
            X = randn(Float32, 2, 32)
            y = X[1, :] .* X[2, :]

            populations, hof = equation_search(
                X,
                y;
                options,
                niterations=20,
                parallelism=:serial,
                return_state=true,
                logger,
                external_stop=stop,
            )

            @test populations isa Vector
            @test hof isa HallOfFame
            @test stop.requested[]
            @test only(logger.cycles_remaining) == [19]
        finally
            ccall(:close, Cint, (Cint,), read_fd)
            ccall(:close, Cint, (Cint,), write_fd)
        end
    end
end

@testitem "overlapping serial searches stop independently" begin
    using SymbolicRegression

    mutable struct CycleLogger <: SymbolicRegression.AbstractSRLogger
        cycles_remaining::Vector{Vector{Int}}
    end
    function SymbolicRegression.logging_callback!(logger::CycleLogger; state, kws...)
        push!(logger.cycles_remaining, copy(state.cycles_remaining))
        return nothing
    end

    X = randn(Float32, 2, 32)
    y = X[1, :] .* X[2, :]
    options = Options(;
        binary_operators=[+, *],
        population_size=20,
        populations=1,
        ncycles_per_iteration=1,
        verbosity=0,
        progress=false,
    )
    stop_a = ExternalStop()
    stop_b = ExternalStop()
    logger_a = CycleLogger(Vector{Int}[])
    logger_b = CycleLogger(Vector{Int}[])

    task_a = Threads.@spawn equation_search(
        X,
        y;
        options,
        niterations=1_000,
        parallelism=:serial,
        return_state=true,
        logger=logger_a,
        external_stop=stop_a,
    )
    task_b = Threads.@spawn equation_search(
        X,
        y;
        options,
        niterations=100,
        parallelism=:serial,
        return_state=true,
        logger=logger_b,
        external_stop=stop_b,
    )
    while isempty(logger_a.cycles_remaining) || isempty(logger_b.cycles_remaining)
        sleep(0.01)
    end

    @test !istaskdone(task_a)
    @test !istaskdone(task_b)
    stop_a.requested[] = true

    populations_a, hof_a = fetch(task_a)
    populations_b, hof_b = fetch(task_b)

    @test populations_a isa Vector
    @test hof_a isa HallOfFame
    @test populations_b isa Vector
    @test hof_b isa HallOfFame
    @test only(last(logger_a.cycles_remaining)) > 0
    @test last(logger_b.cycles_remaining) == [0]
    @test stop_a.requested[]
    @test !stop_b.requested[]
end
