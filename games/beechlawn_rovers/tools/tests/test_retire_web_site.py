"""Protect the wrestling site while removing the retired football deployment."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('retire_web_site', Path(__file__).parents[1]/'retire_web_site.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class RetirementTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.parent = Path(self.temporary.name)
        self.site = self.parent/'site'
        self.site.mkdir()
        for name in ('index.html','index.js','index.pck'):
            (self.site/name).write_bytes(b'wrestling retained '+name.encode())
        (self.site/'index.wasm').write_bytes(b'\0asmretained')
        self.proof = self.parent/'proof.json'

    def test_removes_only_football_and_is_idempotent(self):
        football = self.site/'beechlawn-rovers'
        football.mkdir()
        (football/'index.pck').write_bytes(b'football')
        nested = self.site/'wrestling-screenshots'
        nested.mkdir()
        (nested/'portrait.png').write_bytes(b'preserved')
        before = module.inventory(self.site)
        module.retire(self.site,self.proof)
        self.assertFalse(football.exists())
        self.assertEqual(module.inventory(self.site),before)
        self.assertEqual(json.loads(self.proof.read_text())['retained_sha256'],before)
        module.retire(self.site,self.proof)
        self.assertEqual(module.inventory(self.site),before)

    def test_missing_wrestling_export_refuses_before_deleting(self):
        (self.site/'index.pck').unlink()
        football = self.site/'beechlawn-rovers'
        football.mkdir()
        with self.assertRaises(RuntimeError):
            module.retire(self.site,self.proof)
        self.assertTrue(football.exists())

    def test_retired_symlink_is_not_followed(self):
        target = self.parent/'keep-this'
        target.mkdir()
        (target/'file').write_bytes(b'keep')
        (self.site/'beechlawn-rovers').symlink_to(target,target_is_directory=True)
        module.retire(self.site,self.proof)
        self.assertEqual((target/'file').read_bytes(),b'keep')
        self.assertFalse((self.site/'beechlawn-rovers').exists())

    def test_report_cannot_modify_preserved_site(self):
        with self.assertRaises(ValueError):
            module.retire(self.site,self.site/'proof.json')


if __name__ == '__main__':
    unittest.main()
