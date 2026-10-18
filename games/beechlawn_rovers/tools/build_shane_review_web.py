#!/usr/bin/env python3
"""Export an isolated art review without changing the game's main scene.

Official Godot Web templates disable command-line scene-path overrides. Set
the review scene in a disposable project copy before import/export instead.
"""
from pathlib import Path
import argparse
import shutil
import subprocess
import tempfile
import re

PROJECT=Path(__file__).resolve().parents[1]


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output",type=Path)
    parser.add_argument("--scene",default="res://scenes/review/shane_asset_review.tscn")
    args=parser.parse_args()
    output=args.output.resolve(); output.mkdir(parents=True,exist_ok=True)
    scratch=Path(tempfile.mkdtemp(prefix="beechlawn-shane-review-"))
    try:
        shutil.copytree(PROJECT,scratch,dirs_exist_ok=True,
                        ignore=shutil.ignore_patterns(".godot",".agents","build","references","docs","tools"))
        config=scratch/"project.godot"
        text=config.read_text()
        assert (PROJECT/args.scene.removeprefix('res://')).is_file(),args.scene
        text,count=re.subn(r'^run/main_scene="[^"]+"',lambda _: 'run/main_scene="'+args.scene+'"',text,count=1,flags=re.M)
        assert count==1,'Missing main scene setting'
        config.write_text(text)
        for command,seconds in ((["godot","--headless","--editor","--path",str(scratch),"--import"],90),
                                (["godot","--headless","--path",str(scratch),"--export-debug","Web",str(output/"index.html")],90)):
            result=subprocess.run(command,timeout=seconds,capture_output=True,text=True)
            if result.returncode:
                raise RuntimeError((result.stdout+result.stderr)[-10000:])
            errors=[line for line in (result.stdout+result.stderr).splitlines()
                    if "SCRIPT ERROR:" in line or "Parse Error:" in line]
            if errors: raise RuntimeError("\n".join(errors))
        print("SHANE_REVIEW_WEB_EXPORT",output/"index.html")
    finally:
        shutil.rmtree(scratch)


if __name__=="__main__": main()
