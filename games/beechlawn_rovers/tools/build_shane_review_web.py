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
import time

PROJECT=Path(__file__).resolve().parents[1]


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output",type=Path)
    parser.add_argument("--scene",default="res://scenes/review/shane_asset_review.tscn")
    parser.add_argument("--reuse-imports",action="store_true",
                        help="Copy validated import cache; Godot still checks changed source files")
    args=parser.parse_args()
    output=args.output.resolve(); output.mkdir(parents=True,exist_ok=True)
    # /tmp is a separate small filesystem in the cloud runner. Keep large
    # import-cache copies on the project volume and hide them from Godot.
    scratch_parent=PROJECT/"build"/"review-scratch"
    scratch_parent.mkdir(parents=True,exist_ok=True)
    (scratch_parent/".gdignore").touch()
    scratch=Path(tempfile.mkdtemp(prefix="beechlawn-shane-review-",dir=scratch_parent))
    try:
        shutil.copytree(PROJECT,scratch,dirs_exist_ok=True,
                        ignore=shutil.ignore_patterns(".godot",".agents","build","references","docs","tools"))
        if args.reuse_imports and (PROJECT/".godot/imported").is_dir():
            cache=scratch/".godot/imported"
            cache.mkdir(parents=True,exist_ok=True)
            # Importers atomically rename temporary *.ctex-<random> files.
            # Cache reuse is optional: only copy completed files, and let
            # Godot rebuild anything that disappeared during a source import.
            suffixes={".ctex",".md5",".scn",".res",".sample",".oggstr",".mp3str",".fontdata"}
            for source in (PROJECT/".godot/imported").iterdir():
                if source.suffix not in suffixes:
                    continue
                try:
                    shutil.copy2(source,cache/source.name)
                except FileNotFoundError:
                    pass
        config=scratch/"project.godot"
        text=config.read_text()
        assert (PROJECT/args.scene.removeprefix('res://')).is_file(),args.scene
        text,count=re.subn(r'^run/main_scene="[^"]+"',lambda _: 'run/main_scene="'+args.scene+'"',text,count=1,flags=re.M)
        assert count==1,'Missing main scene setting'
        config.write_text(text)
        for command,seconds in ((["godot","--headless","--editor","--path",str(scratch),"--import"],180),
                                (["godot","--headless","--path",str(scratch),"--export-debug","Web",str(output/"index.html")],90)):
            started=time.monotonic()
            print("REVIEW_STAGE",command[-1],"deadline",seconds,"seconds",flush=True)
            try:
                result=subprocess.run(command,timeout=seconds,capture_output=True,text=True)
            except subprocess.TimeoutExpired as error:
                tail=((error.stdout or b"")+(error.stderr or b""))[-10000:]
                raise RuntimeError("Review stage timed out; final Godot output:\n"+tail.decode(errors="replace")) from error
            print("REVIEW_STAGE_DONE",command[-1],round(time.monotonic()-started,1),"seconds",flush=True)
            if result.returncode:
                raise RuntimeError((result.stdout+result.stderr)[-10000:])
            errors=[line for line in (result.stdout+result.stderr).splitlines()
                    if "SCRIPT ERROR:" in line or "Parse Error:" in line]
            if errors: raise RuntimeError("\n".join(errors))
        print("SHANE_REVIEW_WEB_EXPORT",output/"index.html")
    finally:
        shutil.rmtree(scratch)


if __name__=="__main__": main()
