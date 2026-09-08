import argparse
import concurrent.futures
import glob
import hashlib
import json
import os
import shutil
import subprocess
import sys
import time
import urllib.request
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Optional

REPO_ROOT = Path(__file__).resolve().parent.parent
BUILD_DIR = Path(__file__).resolve().parent
LOG_DIR = BUILD_DIR / "logs"
REPORT_PATH = BUILD_DIR / "compile_report.json"
RELEASE_MANIFEST_PATH = BUILD_DIR / "release_manifest.json"

VALID_TARGETS = ["windows", "android", "ios", "html5", "linux", "mac"]

REQUIRED_TOOLS = ["haxe", "haxelib", "git"]

ARTIFACT_GLOBS = {
    "windows": ["export/{mode}/windows/bin/*.exe"],
    "linux": ["export/{mode}/linux/bin/*"],
    "mac": ["export/{mode}/mac/bin/*.app"],
    "html5": ["export/{mode}/html5/bin"],
    "android": ["export/{mode}/android/bin/app/build/outputs/**/*.apk", "export/{mode}/android/bin/app/build/outputs/**/*.aab"],
    "ios": ["export/{mode}/ios/build/*.ipa", "export/{mode}/ios/build/*.app"],
}


class AnsiColor:
    RESET = "\x1b[0m"
    RED = "\x1b[31m"
    GREEN = "\x1b[32m"
    YELLOW = "\x1b[33m"
    CYAN = "\x1b[36m"
    BOLD = "\x1b[1m"


def supports_color() -> bool:
    if os.environ.get("SHARK_NO_COLOR", "0") == "1":
        return False
    return sys.stdout.isatty()


def colorize(text: str, color: str) -> str:
    if not supports_color():
        return text
    return f"{color}{text}{AnsiColor.RESET}"


def log_info(message: str) -> None:
    print(colorize("[info] ", AnsiColor.CYAN) + message)


def log_ok(message: str) -> None:
    print(colorize("[ok]   ", AnsiColor.GREEN) + message)


def log_warn(message: str) -> None:
    print(colorize("[warn] ", AnsiColor.YELLOW) + message)


def log_error(message: str) -> None:
    print(colorize("[fail] ", AnsiColor.RED) + message)


@dataclass
class CompileResult:
    target: str
    mode: str
    success: bool
    duration_seconds: float
    artifact_path: Optional[str] = None
    checksum: Optional[str] = None
    log_path: Optional[str] = None
    error: Optional[str] = None


@dataclass
class BuildConfig:
    targets: list
    debug: bool
    parallel: bool
    skip_validation: bool
    extra_defines: list
    notify: bool


def read_env_file(path: Path) -> dict:
    values = {}

    if not path.exists():
        return values

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()

        if not line or line.startswith("#"):
            continue

        if "=" not in line:
            continue

        key, _, value = line.partition("=")
        key = key.strip()
        value = value.strip()

        if len(value) >= 2 and value.startswith('"') and value.endswith('"'):
            value = value[1:-1]

        values[key] = value

    return values


ENV_FILE_VALUES = read_env_file(REPO_ROOT / ".env")
ENV_FILE_VALUES.update(read_env_file(REPO_ROOT / ".env.local"))


def env_or(name: str, fallback: str) -> str:
    system_value = os.environ.get(name)

    if system_value:
        return system_value

    if name in ENV_FILE_VALUES and ENV_FILE_VALUES[name]:
        return ENV_FILE_VALUES[name]

    return fallback


def read_version() -> str:
    version_path = REPO_ROOT / "VERSION"

    if version_path.exists():
        content = version_path.read_text(encoding="utf-8").strip()

        if content:
            return content

    return "0.1.0"


def check_tool(name: str) -> bool:
    return shutil.which(name) is not None


def run_command(args: list, cwd: Path) -> tuple:
    try:
        process = subprocess.run(args, cwd=str(cwd), capture_output=True, text=True, timeout=15)
        return process.returncode == 0, process.stdout.strip()
    except Exception:
        return False, ""


def run_doctor() -> bool:
    log_info("Running environment diagnostics")

    all_ok = True

    for tool in REQUIRED_TOOLS:
        found = check_tool(tool)

        if found:
            log_ok(f"{tool} found on PATH")
        else:
            log_error(f"{tool} not found on PATH")
            all_ok = False

    haxe_ok, haxe_version = run_command(["haxe", "-version"], REPO_ROOT)

    if haxe_ok:
        log_ok(f"haxe version: {haxe_version}")
    else:
        log_warn("could not read haxe version")

    lime_ok, _ = run_command(["haxelib", "list", "lime"], REPO_ROOT)

    if lime_ok:
        log_ok("lime haxelib is installed")
    else:
        log_error("lime haxelib is not installed - run `haxelib install lime`")
        all_ok = False

    android_home = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT")

    if android_home and Path(android_home).exists():
        log_ok(f"ANDROID_HOME set: {android_home}")
    else:
        log_warn("ANDROID_HOME/ANDROID_SDK_ROOT not set or invalid - android builds will fail")

    config_path = REPO_ROOT / "assets" / "data" / "config.json"

    if config_path.exists():
        try:
            json.loads(config_path.read_text(encoding="utf-8"))
            log_ok("assets/data/config.json is valid JSON")
        except json.JSONDecodeError as error:
            log_error(f"assets/data/config.json is not valid JSON: {error}")
            all_ok = False
    else:
        log_warn("assets/data/config.json not found - chat/image API will be unconfigured")

    hmm_path = REPO_ROOT / "hmm.json"

    if hmm_path.exists():
        log_ok("hmm.json present")
    else:
        log_warn("hmm.json not found - dependency pinning is not active")

    git_ok, git_branch = run_command(["git", "rev-parse", "--abbrev-ref", "HEAD"], REPO_ROOT)

    if git_ok:
        log_ok(f"git branch: {git_branch}")
    else:
        log_warn("not a git repository or git not available")

    return all_ok


def mode_folder(debug: bool) -> str:
    return "debug" if debug else "release"


def locate_artifact(target: str, debug: bool) -> Optional[Path]:
    mode = mode_folder(debug)
    patterns = ARTIFACT_GLOBS.get(target, [])

    for pattern in patterns:
        resolved_pattern = str(REPO_ROOT / pattern.format(mode=mode))
        matches = sorted(glob.glob(resolved_pattern, recursive=True))

        if matches:
            return Path(matches[-1])

    return None


def compute_checksum(path: Path) -> str:
    digest = hashlib.sha256()

    if path.is_dir():
        for file_path in sorted(path.rglob("*")):
            if file_path.is_file():
                digest.update(file_path.read_bytes())
        return digest.hexdigest()

    digest.update(path.read_bytes())
    return digest.hexdigest()


def run_post_build_hook(target: str) -> bool:
    hook_dir = REPO_ROOT / "build_hooks"
    script_name = f"post_build_{target}.bat" if os.name == "nt" else f"post_build_{target}.sh"
    hook_path = hook_dir / script_name

    if not hook_path.exists():
        return False

    try:
        if os.name == "nt":
            subprocess.run([str(hook_path)], cwd=str(REPO_ROOT), check=True, shell=True)
        else:
            subprocess.run(["sh", str(hook_path)], cwd=str(REPO_ROOT), check=True)
        return True
    except subprocess.CalledProcessError:
        return False


def package_artifact_fallback(target: str, debug: bool) -> Optional[Path]:
    mode = mode_folder(debug)
    source_dir = REPO_ROOT / "export" / mode / target

    if not source_dir.exists():
        return None

    version = read_version()
    archive_base = BUILD_DIR / f"shark-{version}-{target}"
    archive_path = shutil.make_archive(str(archive_base), "zip", root_dir=str(source_dir))
    return Path(archive_path)


def run_lime_build(target: str, config: BuildConfig) -> CompileResult:
    LOG_DIR.mkdir(parents=True, exist_ok=True)

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_path = LOG_DIR / f"{target}_{timestamp}.log"

    args = ["haxelib", "run", "lime", "build", target]

    if config.debug:
        args.append("-debug")

    for define in config.extra_defines:
        args.append(f"-D{define}")

    if config.skip_validation:
        args.append("--skip-validation")

    log_info(f"Building target '{target}' ({'debug' if config.debug else 'release'})")

    start_time = time.time()

    try:
        with log_path.open("w", encoding="utf-8") as log_file:
            process = subprocess.Popen(args, cwd=str(REPO_ROOT), stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)

            for line in process.stdout:
                sys.stdout.write(line)
                log_file.write(line)

            process.wait()
            success = process.returncode == 0
    except FileNotFoundError:
        duration = time.time() - start_time
        return CompileResult(target=target, mode=mode_folder(config.debug), success=False, duration_seconds=duration, error="haxelib executable not found on PATH", log_path=str(log_path))

    duration = time.time() - start_time

    if not success:
        log_error(f"Build failed for target '{target}' after {duration:.1f}s - see {log_path}")
        return CompileResult(target=target, mode=mode_folder(config.debug), success=False, duration_seconds=duration, error="lime build returned non-zero exit code", log_path=str(log_path))

    log_ok(f"Build succeeded for target '{target}' in {duration:.1f}s")

    hook_ran = run_post_build_hook(target)
    artifact_path = locate_artifact(target, config.debug)

    if artifact_path is None and not hook_ran:
        artifact_path = package_artifact_fallback(target, config.debug)

    checksum = compute_checksum(artifact_path) if artifact_path and artifact_path.exists() else None

    if artifact_path:
        log_info(f"Artifact for '{target}': {artifact_path}")

    if checksum:
        log_info(f"Checksum (sha256): {checksum}")

    return CompileResult(
        target=target,
        mode=mode_folder(config.debug),
        success=True,
        duration_seconds=duration,
        artifact_path=str(artifact_path) if artifact_path else None,
        checksum=checksum,
        log_path=str(log_path),
    )


def build_targets(config: BuildConfig) -> list:
    results = []

    if config.parallel and len(config.targets) > 1:
        with concurrent.futures.ThreadPoolExecutor(max_workers=len(config.targets)) as executor:
            futures = {executor.submit(run_lime_build, target, config): target for target in config.targets}

            for future in concurrent.futures.as_completed(futures):
                results.append(future.result())
    else:
        for target in config.targets:
            results.append(run_lime_build(target, config))

    return results


def send_discord_notification(message: str) -> None:
    webhook_url = env_or("SHARK_DISCORD_WEBHOOK_URL", "")

    if not webhook_url or env_or("SHARK_NOTIFY_DISCORD", "0") != "1":
        return

    payload = json.dumps({"content": message}).encode("utf-8")
    request = urllib.request.Request(webhook_url, data=payload, headers={"Content-Type": "application/json"})

    try:
        urllib.request.urlopen(request, timeout=5)
        log_ok("Discord notification sent")
    except Exception as error:
        log_warn(f"Failed to send Discord notification: {error}")


def write_compile_report(results: list) -> None:
    report = {
        "generatedAt": datetime.now().isoformat(),
        "version": read_version(),
        "results": [result.__dict__ for result in results],
    }

    REPORT_PATH.write_text(json.dumps(report, indent="\t"), encoding="utf-8")
    log_info(f"Compile report written to {REPORT_PATH}")


def summarize_results(results: list) -> bool:
    succeeded = [result for result in results if result.success]
    failed = [result for result in results if not result.success]

    print("")
    print(colorize("Build summary", AnsiColor.BOLD))
    print(f"  succeeded: {len(succeeded)}")
    print(f"  failed:    {len(failed)}")

    for result in results:
        marker = colorize("OK", AnsiColor.GREEN) if result.success else colorize("FAIL", AnsiColor.RED)
        print(f"  [{marker}] {result.target} ({result.mode}) - {result.duration_seconds:.1f}s")

        if not result.success and result.error:
            print(f"        {result.error}")

    return len(failed) == 0


def clean_artifacts(targets: list, deep: bool) -> None:
    for target in targets:
        for mode in ["debug", "release"]:
            export_path = REPO_ROOT / "export" / mode / target

            if export_path.exists():
                log_info(f"Removing {export_path}")
                shutil.rmtree(export_path, ignore_errors=True)

    if deep:
        for stale_file in [".shark_asset_cache", ".build_number", "build_report.log", "THIRD_PARTY_NOTICES.txt"]:
            stale_path = REPO_ROOT / stale_file

            if stale_path.exists():
                log_info(f"Removing {stale_path}")
                stale_path.unlink()

        if LOG_DIR.exists():
            log_info(f"Removing {LOG_DIR}")
            shutil.rmtree(LOG_DIR, ignore_errors=True)


def write_release_manifest(results: list) -> None:
    manifest = {
        "version": read_version(),
        "generatedAt": datetime.now().isoformat(),
        "artifacts": [
            {
                "target": result.target,
                "mode": result.mode,
                "artifact": result.artifact_path,
                "checksum": result.checksum,
            }
            for result in results
            if result.success
        ],
    }

    RELEASE_MANIFEST_PATH.write_text(json.dumps(manifest, indent="\t"), encoding="utf-8")
    log_info(f"Release manifest written to {RELEASE_MANIFEST_PATH}")


def parse_targets(raw_targets: list) -> list:
    if not raw_targets or raw_targets == ["all"]:
        return list(VALID_TARGETS)

    resolved = []

    for target in raw_targets:
        if target not in VALID_TARGETS:
            log_error(f"Unknown target '{target}' - valid targets are: {', '.join(VALID_TARGETS)}")
            sys.exit(1)

        resolved.append(target)

    return resolved


def command_build(args: argparse.Namespace) -> None:
    targets = parse_targets(args.targets)

    config = BuildConfig(
        targets=targets,
        debug=args.debug,
        parallel=args.parallel,
        skip_validation=args.skip_validation,
        extra_defines=args.define or [],
        notify=args.notify,
    )

    results = build_targets(config)
    write_compile_report(results)
    all_ok = summarize_results(results)

    if config.notify:
        status = "succeeded" if all_ok else "had failures"
        send_discord_notification(f"Shark {read_version()} build {status} for targets: {', '.join(targets)}")

    sys.exit(0 if all_ok else 1)


def command_clean(args: argparse.Namespace) -> None:
    targets = parse_targets(args.targets)
    clean_artifacts(targets, args.deep)
    log_ok("Clean finished")


def command_doctor(args: argparse.Namespace) -> None:
    healthy = run_doctor()
    sys.exit(0 if healthy else 1)


def command_package(args: argparse.Namespace) -> None:
    targets = parse_targets(args.targets)
    results = []

    for target in targets:
        artifact_path = locate_artifact(target, args.debug)

        if artifact_path is None:
            artifact_path = package_artifact_fallback(target, args.debug)

        if artifact_path is None:
            log_warn(f"No build output found for target '{target}' - build it first")
            results.append(CompileResult(target=target, mode=mode_folder(args.debug), success=False, duration_seconds=0.0, error="no build output found"))
            continue

        checksum = compute_checksum(artifact_path)
        log_ok(f"Packaged '{target}': {artifact_path} ({checksum[:12]}...)")
        results.append(CompileResult(target=target, mode=mode_folder(args.debug), success=True, duration_seconds=0.0, artifact_path=str(artifact_path), checksum=checksum))

    write_compile_report(results)


def command_release(args: argparse.Namespace) -> None:
    targets = parse_targets(args.targets)

    os.environ["SHARK_ENV"] = "production"
    os.environ["SHARK_AUTO_TAG"] = "1"
    os.environ["SHARK_AUTO_CHANGELOG"] = "1"
    os.environ["SHARK_SYNC_README"] = "1"

    config = BuildConfig(
        targets=targets,
        debug=False,
        parallel=False,
        skip_validation=False,
        extra_defines=args.define or [],
        notify=True,
    )

    log_info(f"Starting release build for version {read_version()}")

    results = build_targets(config)
    write_compile_report(results)
    write_release_manifest(results)
    all_ok = summarize_results(results)

    status = "succeeded" if all_ok else "had failures"
    send_discord_notification(f"Shark {read_version()} release build {status} for targets: {', '.join(targets)}")

    sys.exit(0 if all_ok else 1)


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="Compile.py", description="Shark build orchestrator")
    subparsers = parser.add_subparsers(dest="command", required=True)

    build_parser = subparsers.add_parser("build", help="Build one or more targets")
    build_parser.add_argument("targets", nargs="*", default=["all"])
    build_parser.add_argument("--debug", action="store_true")
    build_parser.add_argument("--parallel", action="store_true")
    build_parser.add_argument("--skip-validation", action="store_true")
    build_parser.add_argument("--notify", action="store_true")
    build_parser.add_argument("--define", action="append")
    build_parser.set_defaults(func=command_build)

    clean_parser = subparsers.add_parser("clean", help="Remove build output for one or more targets")
    clean_parser.add_argument("targets", nargs="*", default=["all"])
    clean_parser.add_argument("--deep", action="store_true")
    clean_parser.set_defaults(func=command_clean)

    doctor_parser = subparsers.add_parser("doctor", help="Check the local toolchain")
    doctor_parser.set_defaults(func=command_doctor)

    package_parser = subparsers.add_parser("package", help="Package already-built artifacts without rebuilding")
    package_parser.add_argument("targets", nargs="*", default=["all"])
    package_parser.add_argument("--debug", action="store_true")
    package_parser.set_defaults(func=command_package)

    release_parser = subparsers.add_parser("release", help="Run a full production release build")
    release_parser.add_argument("targets", nargs="*", default=["all"])
    release_parser.add_argument("--define", action="append")
    release_parser.set_defaults(func=command_release)

    return parser


def main() -> None:
    parser = build_arg_parser()
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
