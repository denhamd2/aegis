"""A completed native readback gets its separately bounded cleanup window."""
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import capture_native


class CaptureDeadlineTest(unittest.TestCase):
    def test_saved_capture_finishes_cleanup_after_render_deadline(self):
        with tempfile.TemporaryDirectory() as folder:
            image=Path(folder)/'frame.png'; report=Path(folder)/'frame.json'
            clock=[0.0]
            class Process:
                returncode=None
                def __init__(self,*args,**kwargs): self.stream=kwargs['stdout']
                def poll(self): return self.returncode
                def wait(self,timeout):
                    clock[0]+=.6
                    if not image.exists():
                        image.write_bytes(b'saved');report.write_text('{}')
                        self.stream.write(b'BEECHLAWN_NATIVE_CAPTURE saved\n');self.stream.flush()
                    raise subprocess.TimeoutExpired('fixture',timeout)
            def stop(process): process.returncode=-15
            with patch.object(capture_native.subprocess,'Popen',Process),patch.object(capture_native.time,'monotonic',lambda:clock[0]),patch.object(capture_native,'stop',stop):
                result=capture_native.run_bounded(['fixture'],{},1.0,Path(folder)/'capture.log',(image,report))
            self.assertEqual(result,'terminated_after_saved_capture')
            self.assertLess(clock[0],12)


if __name__=='__main__': unittest.main()
