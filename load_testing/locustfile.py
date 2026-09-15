"""Locust users each hold one SSH session through Boundary."""
import os
import subprocess

from locust import User, between, task


TARGET_ID = os.environ.get("BOUNDARY_TARGET_ID", "")
USERNAME = os.environ.get("BOUNDARY_USERNAME", "ubuntu")
SESSION_DURATION = os.environ.get("BOUNDARY_SESSION_DURATION", "600")


class BoundaryUser(User):
    wait_time = between(1, 2)

    def on_start(self):
        if not TARGET_ID.startswith("tssh_"):
            raise RuntimeError("Set BOUNDARY_TARGET_ID to an SSH target ID beginning with tssh_.")
        self.process = subprocess.Popen([
            "boundary", "connect", "ssh", f"-target-id={TARGET_ID}", "--",
            "-l", USERNAME, "sleep", SESSION_DURATION,
        ])

    @task
    def keep_session_alive(self):
        if self.process.poll() is not None:
            raise RuntimeError("Boundary SSH session ended unexpectedly.")

    def on_stop(self):
        if self.process.poll() is None:
            self.process.terminate()
            try:
                self.process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                self.process.kill()
