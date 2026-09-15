#!/usr/bin/env python3
"""Create concurrent SSH sessions through an existing Boundary SSH target."""
import argparse
import signal
import subprocess
import sys
import time


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target-id", required=True, help="Boundary SSH target ID (tssh_...).")
    parser.add_argument("--sessions", type=int, default=2, help="Concurrent sessions to open.")
    parser.add_argument("--duration", type=int, default=300, help="Seconds each session remains open.")
    parser.add_argument("--delay", type=float, default=1, help="Seconds between session launches.")
    parser.add_argument("--username", default="ubuntu", help="Linux target username.")
    return parser.parse_args()


def stop(processes):
    for process in processes:
        if process.poll() is None:
            process.terminate()
    for process in processes:
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()


def main():
    args = parse_args()
    if not args.target_id.startswith("tssh_"):
        sys.exit("This test requires an SSH target ID beginning with tssh_.")
    if args.sessions < 1 or args.duration < 1 or args.delay < 0:
        sys.exit("sessions and duration must be positive; delay cannot be negative.")

    processes = []
    print(f"Opening {args.sessions} Boundary SSH sessions for {args.duration}s.")
    try:
        for number in range(1, args.sessions + 1):
            command = [
                "boundary", "connect", "ssh", f"-target-id={args.target_id}", "--",
                "-l", args.username, "sleep", str(args.duration),
            ]
            processes.append(subprocess.Popen(command))
            print(f"Started session {number}/{args.sessions}.")
            time.sleep(args.delay)
        for process in processes:
            process.wait()
    except KeyboardInterrupt:
        print("Stopping sessions...")
        stop(processes)
        return 130
    finally:
        stop(processes)
    print("Load test completed.")
    return 0


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(130))
    sys.exit(main())
