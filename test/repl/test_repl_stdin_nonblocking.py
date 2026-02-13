#!/usr/bin/env python3
import os
import pty
import select
import subprocess
import sys
import time

PROMPT = b"julia> "
WARMUP_TOKEN = b"__REPL_WARMUP_OK__"
WATCH_TOKEN = b"__REPL_WATCH_OK__"
CHECK_TOKEN = b"__REPL_CHECK_OK__"


def send_line(fd: int, line: str) -> None:
    os.write(fd, line.encode("utf-8") + b"\n")


def read_until(
    fd: int,
    proc: subprocess.Popen,
    needle: bytes,
    timeout_s: float,
    transcript: bytearray,
) -> None:
    deadline = time.monotonic() + timeout_s
    while time.monotonic() < deadline:
        if needle in transcript:
            return
        if proc.poll() is not None:
            raise RuntimeError(
                f"julia exited before seeing token {needle!r} (exit={proc.returncode})"
            )
        ready, _, _ = select.select([fd], [], [], 0.05)
        if not ready:
            continue
        chunk = os.read(fd, 4096)
        if chunk:
            transcript.extend(chunk)
    raise TimeoutError(f"timed out waiting for token {needle!r}")


def terminate(proc: subprocess.Popen) -> None:
    if proc.poll() is not None:
        return
    proc.terminate()
    try:
        proc.wait(timeout=2)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait(timeout=2)


def fail(message: str, transcript: bytearray, proc: subprocess.Popen) -> None:
    terminate(proc)
    tail = bytes(transcript[-4000:]).decode("utf-8", errors="replace")
    print(message, file=sys.stderr)
    print("\n--- PTY transcript tail ---\n", file=sys.stderr)
    print(tail, file=sys.stderr)
    sys.exit(1)


def main() -> int:
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    master_fd, slave_fd = pty.openpty()
    proc = subprocess.Popen(
        [
            os.environ.get("JULIA", "julia"),
            "--project=.",
            "--startup-file=no",
            "--history-file=no",
            "--color=no",
            "-q",
        ],
        stdin=slave_fd,
        stdout=slave_fd,
        stderr=slave_fd,
        cwd=repo_root,
        close_fds=True,
    )
    os.close(slave_fd)

    transcript = bytearray()
    try:
        read_until(master_fd, proc, PROMPT, timeout_s=30.0, transcript=transcript)

        send_line(master_fd, "using SymbolicRegression")
        read_until(master_fd, proc, PROMPT, timeout_s=180.0, transcript=transcript)

        send_line(
            master_fd,
            "SymbolicRegression.check_for_user_quit(SymbolicRegression.StdinReader(false, devnull)); println(\"__REPL_WARMUP_OK__\")",
        )
        read_until(master_fd, proc, WARMUP_TOKEN, timeout_s=20.0, transcript=transcript)
        read_until(master_fd, proc, PROMPT, timeout_s=20.0, transcript=transcript)

        # The key regression: with a real TTY (PTY), stdin monitoring should not block.
        send_line(
            master_fd,
            "SymbolicRegression.watch_stream(stdin); println(\"__REPL_WATCH_OK__\")",
        )
        read_until(master_fd, proc, WATCH_TOKEN, timeout_s=2.5, transcript=transcript)
        read_until(master_fd, proc, PROMPT, timeout_s=10.0, transcript=transcript)

        send_line(
            master_fd,
            "let reader = SymbolicRegression.watch_stream(stdin); SymbolicRegression.check_for_user_quit(reader); SymbolicRegression.close_reader!(reader); println(\"__REPL_CHECK_OK__\"); end",
        )
        read_until(master_fd, proc, CHECK_TOKEN, timeout_s=2.5, transcript=transcript)
        read_until(master_fd, proc, PROMPT, timeout_s=10.0, transcript=transcript)

        # Don't rely on graceful REPL shutdown (can be flaky if background tasks linger).
        # We already validated the behavior we care about once SUCCESS_TOKEN is observed.
        terminate(proc)
        os.close(master_fd)
        return 0
    except Exception as exc:
        fail(f"REPL stdin nonblocking test failed: {exc}", transcript, proc)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
