"""Regression for Xvfb's readiness digits/newline arriving in separate reads."""
import os, threading, time, unittest
from capture_native import read_display_number
class DisplayPipeTests(unittest.TestCase):
    def test_split_ready_line(self):
        read_fd,write_fd=os.pipe()
        errors=[]
        def writer():
            try:
                os.write(write_fd,b'12')
                time.sleep(.02)
                os.write(write_fd,b'\n')
            except OSError as error: errors.append(error)
            finally: os.close(write_fd)
        thread=threading.Thread(target=writer);thread.start()
        try: self.assertEqual(read_display_number(read_fd),':12')
        finally: os.close(read_fd);thread.join(timeout=1)
        self.assertFalse(errors,'Reader closed the pipe before the final newline')
    def test_premature_exit_fails_closed(self):
        read_fd,write_fd=os.pipe();os.write(write_fd,b'0');os.close(write_fd)
        try:
            with self.assertRaises(RuntimeError):read_display_number(read_fd)
        finally:os.close(read_fd)
if __name__=='__main__':unittest.main()
