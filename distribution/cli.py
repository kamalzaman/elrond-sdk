import logging
import os
import shutil
import sys
import pathlib
from argparse import ArgumentParser
from git import Repo
from os import path
import subprocess

logger = logging.getLogger("cli")


def main():
    logging.basicConfig(level=logging.DEBUG)

    parser = setup_parser()
    args = parser.parse_args()

    if not hasattr(args, "func"):
        parser.print_help()
    else:
        args.func(args)


def setup_parser():
    parser = ArgumentParser()
    subparsers = parser.add_subparsers()

    parser.add_argument("--workspace", required=True)

    prepare_nodedebug_parser = subparsers.add_parser("prepare-nodedebug")
    prepare_nodedebug_parser.set_defaults(func=prepare_nodedebug)

    return parser


def prepare_nodedebug(args):
    workspace = args.workspace

    nodedebug_folder = path.join(workspace, "nodedebug", "cmd", "nodedebug")
    nodedebug_exe = path.join(nodedebug_folder, "nodedebug")
    get_source_code(workspace, "nodedebug", "git@github.com:ElrondNetwork/elrond-go-node-debug.git")
    go_build(nodedebug_folder)
    fix_libwasmer_reference(nodedebug_exe)

    # todo: prepare archive: exe, config, .so, .dylib
    # todo: upload to S3


def get_source_code(workspace, folder, url):
    ensure_folder(workspace)
    folder = path.join(workspace, folder)

    if not repository_exists(folder):
        Repo.clone_from(url, folder)

    repository = Repo(folder)
    repository.heads.master.checkout()
    origin = repository.remotes.origin
    origin.pull()


def ensure_folder(folder):
    pathlib.Path(folder).mkdir(parents=True, exist_ok=True)


def repository_exists(folder):
    try:
        Repo(folder)
        return True
    except Exception:
        return False


def go_build(folder):
    subprocess.check_output(["go", "clean"], cwd=folder)
    output = subprocess.check_output(["go", "build"], cwd=folder)
    print(output.decode("utf-8"))


def fix_libwasmer_reference(executable_path):
    platform = get_platform()
    executable_folder = pathlib.Path(executable_path).parent

    if platform == "linux":
        ldd_output = subprocess.check_output(["ldd", executable_path])
        ldd_output = ldd_output.decode("utf-8")
        ldd_output_lines = split_to_lines(ldd_output)
        libwasmer_line = next(line for line in ldd_output_lines if line.startswith("libwasmer_runtime_c_api.so"))
        libwasmer_path = split_get_part(libwasmer_line, "=>", 1)
        libwasmer_path = split_get_part(libwasmer_path, " ", 0)
        libwasmer_copy_path = path.join(executable_folder, "libwasmer_runtime_c_api.so")
        shutil.copy(libwasmer_path, libwasmer_copy_path)
        os.chmod(libwasmer_copy_path, 0o755)
        subprocess.check_output(["patchelf", "--set-rpath", "$ORIGIN", "nodedebug"], cwd=executable_folder)


def get_platform():
    platforms = {
        "linux": "linux",
        "linux1": "linux",
        "linux2": "linux",
        "darwin": "osx",
        "win32": "windows",
        "cygwin": "windows",
        "msys": "windows"
    }

    platform = platforms.get(sys.platform)
    if platform is None:
        raise Exception(f"Unknown platform: {sys.platform}")

    return platform


def split_to_lines(input):
    lines = input.split("\n")
    lines = [line.strip() for line in lines]
    lines = [line for line in lines if line]
    return lines


def split_get_part(input, delimiter, index):
    parts = input.split(delimiter)
    parts = [part.strip() for part in parts]
    parts = [part for part in parts if part]
    return parts[index]


if __name__ == "__main__":
    main()
