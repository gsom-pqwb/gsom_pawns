"""Run isolated lifecycle regressions using a caller-provided Godot wrapper."""
import argparse
from pathlib import Path
import shutil
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument("--godot-wrapper", type=Path, required=True)
parser.add_argument("--output", type=Path, required=True)
parser.add_argument("--addon-source", type=Path)
args = parser.parse_args()
output = args.output.resolve()
output.mkdir(parents=True, exist_ok=False)
source = args.addon_source or Path(__file__).resolve().parents[2] / "addons/gsom_pawns"
shutil.copytree(source, output / "addons/gsom_pawns")
shutil.copytree(Path(__file__).parent, output / "tests/environments",
                ignore=shutil.ignore_patterns(".gdignore", "__pycache__"))
shutil.copyfile(Path(__file__).parent / "project.godot.template", output / "project.godot")
for label, flags in (("import", ["--editor", "--import"]), ("run", ["--quit-after", "300"])):
    result = subprocess.run(["bash", str(args.godot_wrapper.resolve()), "--headless", "--path", str(output), *flags],
                            capture_output=True, text=True, encoding="utf-8", timeout=90)
    log = result.stdout + result.stderr
    (output.parent / (output.name + "-" + label + ".log")).write_text(log, encoding="utf-8")
    print(log)
    if result.returncode or "ERROR:" in log or "WARNING:" in log:
        raise SystemExit(1)
    if label == "run" and "PAWNS_REGRESSION failures=0" not in log:
        raise SystemExit(1)
