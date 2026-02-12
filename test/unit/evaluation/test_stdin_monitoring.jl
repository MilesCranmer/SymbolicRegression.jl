@testitem "stdin monitoring avoids blocking and parses quit commands" begin
    using SymbolicRegression

    mutable struct FakeInputStream <: IO
        chunks::Vector{Vector{UInt8}}
        reported_bytes::Int
        read_delay_s::Float64
        read_calls::Int
        readavailable_calls::Int
    end

    function FakeInputStream(
        chunks::Vector{String}; reported_bytes::Int=0, read_delay_s::Float64=0.0
    )
        return FakeInputStream(
            [Vector{UInt8}(codeunits(c)) for c in chunks],
            reported_bytes,
            read_delay_s,
            0,
            0,
        )
    end

    Base.isreadable(::FakeInputStream) = true
    Base.start_reading(::FakeInputStream) = nothing
    Base.stop_reading(::FakeInputStream) = nothing

    Base.bytesavailable(stream::FakeInputStream) = isempty(stream.chunks) ? 0 : stream.reported_bytes

    function Base.read(stream::FakeInputStream, ::Integer)
        stream.read_calls += 1
        if stream.read_delay_s > 0
            sleep(stream.read_delay_s)
        end
        return isempty(stream.chunks) ? UInt8[] : popfirst!(stream.chunks)
    end

    function Base.readavailable(stream::FakeInputStream)
        stream.readavailable_calls += 1
        return isempty(stream.chunks) ? UInt8[] : popfirst!(stream.chunks)
    end

    function completes_quickly(f::Function; timeout_s::Float64=0.05)
        task = @async f()
        status = timedwait(() -> istaskdone(task), timeout_s)
        if status == :ok
            return true, fetch(task)
        end
        wait(task)
        return false, nothing
    end

    # Reproducer for freeze path in watch_stream: read(stream, bytes) can block
    # even when bytesavailable reports positive bytes.
    watch_stream_input = FakeInputStream(["x"]; reported_bytes=1, read_delay_s=0.2)
    quick_watch, _ = completes_quickly(() -> SymbolicRegression.watch_stream(watch_stream_input))
    @test quick_watch

    # Reproducer for freeze path in check_for_user_quit.
    slow_input = FakeInputStream(["x"]; reported_bytes=1, read_delay_s=0.2)
    slow_reader = SymbolicRegression.StdinReader(true, slow_input)
    quick_check, result = completes_quickly(() -> SymbolicRegression.check_for_user_quit(slow_reader))
    @test quick_check
    if quick_check
        @test result == false
    end

    # Parsing should handle CRLF line endings.
    crlf_reader = SymbolicRegression.StdinReader(
        true, FakeInputStream(["q\r\n"]; reported_bytes=3)
    )
    @test SymbolicRegression.check_for_user_quit(crlf_reader)

    # Parsing should handle chunked input where `q` and newline arrive separately.
    chunked_reader = SymbolicRegression.StdinReader(
        true, FakeInputStream(["q", "\n"]; reported_bytes=1)
    )
    @test !SymbolicRegression.check_for_user_quit(chunked_reader)
    @test SymbolicRegression.check_for_user_quit(chunked_reader)
end
