"""Real process-lifecycle tests. No provider, model, network, or private data."""

import ctypes
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

import local_process


def alive(pid):
    if os.name == "nt":
        from ctypes import wintypes
        api = ctypes.WinDLL("kernel32", use_last_error=True)
        api.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
        api.OpenProcess.restype = wintypes.HANDLE
        api.GetExitCodeProcess.argtypes = [wintypes.HANDLE, ctypes.POINTER(wintypes.DWORD)]
        api.CloseHandle.argtypes = [wintypes.HANDLE]
        handle = api.OpenProcess(0x1000, False, pid)
        if not handle:
            return False
        try:
            code = wintypes.DWORD()
            return bool(api.GetExitCodeProcess(handle, ctypes.byref(code))) and code.value == 259
        finally:
            api.CloseHandle(handle)
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False


class ProcessTests(unittest.TestCase):
    @unittest.skipUnless(os.name == "nt", "Windows fail-closed job assignment")
    def test_ownership_failure_does_not_start_provider(self):
        with tempfile.TemporaryDirectory() as folder:
            marker = Path(folder) / "must-not-exist"
            command = [sys.executable, "-c", "from pathlib import Path;import sys;Path(sys.argv[1]).touch()", str(marker)]
            with patch.object(local_process.WindowsJob, "assign", side_effect=OSError("injected")):
                with self.assertRaisesRegex(OSError, "injected"):
                    local_process.run(command, timeout=10)
            self.assertFalse(marker.exists())

    def test_json_stdin_stdout_and_error_code(self):
        for code in (0, 7):
            result = local_process.run([sys.executable, "-c",
                "import sys;print(sys.stdin.read());sys.exit(" + str(code) + ")"],
                stdin='{"content":"test"}', timeout=10)
            self.assertEqual(json.loads(result.stdout), {"content": "test"})
            self.assertEqual(result.returncode, code)

    @unittest.skipUnless(os.name == "nt", "Windows job ownership test")
    def test_descendant_closed_on_success_failure_and_timeout_without_killing_peer(self):
        peer = subprocess.Popen([sys.executable, "-c", "import time;time.sleep(60)"],
                                creationflags=subprocess.CREATE_NO_WINDOW)
        try:
            for mode in ("success", "failure", "timeout"):
                with self.subTest(mode=mode), tempfile.TemporaryDirectory() as folder:
                    pidfile = Path(folder) / "child.json"
                    code = ("import subprocess,sys,json,time;from pathlib import Path;"
                            "p=subprocess.Popen([sys.executable,'-c','import time;time.sleep(60)'],"
                            "stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL);"
                            "Path(sys.argv[1]).write_text(json.dumps(p.pid));")
                    code += "time.sleep(60)" if mode == "timeout" else "sys.exit(" + ("7" if mode == "failure" else "0") + ")"
                    command = [sys.executable, "-c", code, str(pidfile)]
                    if mode == "timeout":
                        with self.assertRaises(subprocess.TimeoutExpired):
                            local_process.run(command, timeout=2)
                    else:
                        result = local_process.run(command, timeout=10)
                        self.assertEqual(result.returncode, 7 if mode == "failure" else 0)
                    self.assertTrue(pidfile.exists(), "provider must actually have started")
                    pid = json.loads(pidfile.read_text())
                    deadline = time.monotonic() + 3
                    while alive(pid) and time.monotonic() < deadline:
                        time.sleep(0.02)
                    self.assertFalse(alive(pid), "owned descendant leaked")
                    self.assertIsNone(peer.poll(), "unrelated process was terminated")
        finally:
            peer.kill()
            peer.wait(timeout=5)

    def test_repeated_calls_are_reaped(self):
        for _ in range(8):
            result = local_process.run([sys.executable, "-c", "import os;print(os.getpid())"], timeout=10)
            self.assertEqual(result.returncode, 0)
            self.assertFalse(alive(int(result.stdout)))


if __name__ == "__main__":
    unittest.main(verbosity=2)
