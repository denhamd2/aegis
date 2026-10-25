#!/usr/bin/env python3
"""A reported assertion must fail immediately, even if its process idles."""
import os
import subprocess
import sys
import time
from run_smoke_tests import monitor_process

def run(source, timeout):
    started = time.monotonic()
    process = subprocess.Popen([sys.executable, '-u', '-c', source], stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, start_new_session=os.name == 'posix')
    output, status = monitor_process(process, timeout)
    return output, status, time.monotonic()-started

output, status, elapsed = run("import time;print('SCRIPT ERROR: Assertion failed.');time.sleep(30)", 10)
assert status == 'error' and elapsed < 3 and 'Assertion failed' in output
output, status, elapsed = run("import time;time.sleep(30)", .25)
assert status == 'timeout' and elapsed < 3
output, status, elapsed = run("print('PASS')", 2)
assert status == 'complete' and output.strip() == 'PASS'
print('SMOKE_MONITOR PASS: immediate assertion failure, bounded timeout, normal completion')
