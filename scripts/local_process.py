"""Run one local provider call and release its owned process tree. No daemon."""

import ctypes
import json
import os
from pathlib import Path
import signal
import subprocess
import sys


class WindowsJob:
    def __init__(self):
        from ctypes import wintypes as w

        class BasicLimits(ctypes.Structure):
            _fields_ = [("process_time", ctypes.c_int64), ("job_time", ctypes.c_int64),
                        ("flags", w.DWORD), ("min_working_set", ctypes.c_size_t),
                        ("max_working_set", ctypes.c_size_t), ("active_processes", w.DWORD),
                        ("affinity", ctypes.c_size_t), ("priority", w.DWORD), ("scheduling", w.DWORD)]

        class IoCounters(ctypes.Structure):
            _fields_ = [(name, ctypes.c_uint64) for name in
                        ("read_ops", "write_ops", "other_ops", "read_bytes", "write_bytes", "other_bytes")]

        class ExtendedLimits(ctypes.Structure):
            _fields_ = [("basic", BasicLimits), ("io", IoCounters),
                        ("process_memory", ctypes.c_size_t), ("job_memory", ctypes.c_size_t),
                        ("peak_process_memory", ctypes.c_size_t), ("peak_job_memory", ctypes.c_size_t)]

        self.api = ctypes.WinDLL("kernel32", use_last_error=True)
        declarations = {
            "CreateJobObjectW": ([ctypes.c_void_p, w.LPCWSTR], w.HANDLE),
            "SetInformationJobObject": ([w.HANDLE, ctypes.c_int, ctypes.c_void_p, w.DWORD], w.BOOL),
            "AssignProcessToJobObject": ([w.HANDLE, w.HANDLE], w.BOOL),
            "OpenProcess": ([w.DWORD, w.BOOL, w.DWORD], w.HANDLE),
            "CloseHandle": ([w.HANDLE], w.BOOL),
        }
        for name, (args, result) in declarations.items():
            fn = getattr(self.api, name)
            fn.argtypes, fn.restype = args, result
        self.handle = self.api.CreateJobObjectW(None, None)
        if not self.handle:
            raise ctypes.WinError(ctypes.get_last_error())
        limits = ExtendedLimits()
        limits.basic.flags = 0x2000  # JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE, no breakaway.
        if not self.api.SetInformationJobObject(self.handle, 9, ctypes.byref(limits), ctypes.sizeof(limits)):
            error = ctypes.WinError(ctypes.get_last_error())
            self.close()
            raise error

    def assign(self, pid):
        handle = self.api.OpenProcess(0x0100 | 0x0001, False, pid)  # SET_QUOTA | TERMINATE
        if not handle:
            raise ctypes.WinError(ctypes.get_last_error())
        try:
            if not self.api.AssignProcessToJobObject(self.handle, handle):
                raise ctypes.WinError(ctypes.get_last_error())
        finally:
            self.api.CloseHandle(handle)

    def close(self):
        if self.handle:
            if not self.api.CloseHandle(self.handle):
                raise ctypes.WinError(ctypes.get_last_error())
            self.handle = None


def run(command, *, stdin=None, timeout=30, env=None):
    """No shell; Windows child cannot start the provider until job assignment."""
    job = WindowsJob() if os.name == "nt" else None
    process = None
    try:
        process = subprocess.Popen(
            [sys.executable, "-B", str(Path(__file__).resolve()), "--worker"],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            text=True, encoding="utf-8", env=env,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
            start_new_session=os.name != "nt")
        if job:
            job.assign(process.pid)
        # Worker blocks on stdin. No provider can escape before ownership is set.
        payload = json.dumps({"command": command, "stdin": stdin}, ensure_ascii=True)
        stdout, stderr = process.communicate(payload, timeout=timeout)
        return subprocess.CompletedProcess(command, process.returncode, stdout, stderr)
    finally:
        try:
            if job:
                job.close()
            elif process:
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
        finally:
            if process:
                if process.poll() is None:
                    process.kill()
                # Closing the owned tree releases inherited pipe handles too.
                process.communicate(timeout=5)


def worker():
    sys.stdin.reconfigure(encoding="utf-8")
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    payload = json.load(sys.stdin)
    command = payload["command"]
    if not isinstance(command, list) or not command or any(not isinstance(x, str) for x in command):
        return 2
    result = subprocess.run(command, input=payload["stdin"] or "", stdout=sys.stdout,
                            stderr=sys.stderr, text=True, encoding="utf-8",
                            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
    return result.returncode


if __name__ == "__main__":
    if sys.argv[1:] != ["--worker"]:
        raise SystemExit("Internal local-process worker only")
    raise SystemExit(worker())
