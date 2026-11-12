#!/usr/bin/env python3
"""Port the TB323FU-specific TWRP fixes into an OrangeFox (fox_16.0) recovery tree.

These three changes exist in the validated TB323FU TWRP baseline
(isrgish/TB323FU-TWRP -> polygraphene/android_bootable_recovery @ twrp-16.0-TB322FC,
which is upstream TWRP-Test/android_bootable_recovery twrp-16.0 + exactly 3 commits).
OrangeFox's fork never got them, so they have to be re-applied here.

Source patches (kept for provenance in patches/):
  0002-tb323fu-wait-module-handler-done.patch   321f5cff "Wait for the execution of module loaded handler."
  0003-tb323fu-dynamic-thermal-zone.patch       4be98e1c "Dynamic thermal_zone number detection."

The third upstream commit (ced4ad75 "Fix broken screen layout.") only edits TWRP's
theme XML, which OrangeFox replaces with its own theme, so it is intentionally not
ported.

Why a script instead of plain `git apply`: OrangeFox's files drifted slightly
(extra OrangeFox features and different indentation), so the upstream hunks do not
apply verbatim. Each edit below is anchored semantically and verified afterwards.

Usage:
    python3 port_tb323fu_fixes.py /path/to/bootable/recovery

Idempotent: re-running on an already-patched tree reports OK and changes nothing.
Exit code is non-zero if anything could not be applied or verified.
"""

import re
import sys
from pathlib import Path

COND_START = re.compile(r'^\s*#\s*(if|ifdef|ifndef)\b')
COND_END = re.compile(r'^\s*#\s*endif\b')


def find_if_block(lines, start):
    """Return the index of the #endif matching the conditional opening at `start`."""
    depth = 0
    for i in range(start, len(lines)):
        if COND_START.match(lines[i]):
            depth += 1
        elif COND_END.match(lines[i]):
            depth -= 1
            if depth == 0:
                return i
    raise SystemExit(f"ERROR: unterminated conditional starting at line {start + 1}")


def body_indent_of(lines, start, end):
    """Leading whitespace of the first non-blank line inside a conditional block."""
    for i in range(start + 1, end):
        if lines[i].strip():
            return re.match(r'(\s*)', lines[i]).group(1)
    return ""


def line_of(lines, pattern, what, occurrence=1):
    """Return the 0-based index of the n-th line matching `pattern` (a compiled regex)."""
    seen = 0
    for i, line in enumerate(lines):
        if pattern.search(line):
            seen += 1
            if seen == occurrence:
                return i
    raise SystemExit(f"ERROR: could not locate {what}")


def patch_module_handler_wait(recovery: Path):
    """kernel_module_loader.cpp: wait for init.rc's twrp.module.handler_done."""
    path = recovery / "kernel_module_loader.cpp"
    text = path.read_text()

    if "twrp.module.handler_done" in text:
        return "kernel_module_loader.cpp: already patched"

    lines = text.splitlines(keepends=True)
    idx = line_of(lines, re.compile(r'SetProperty\(TW_MODULES_MOUNTED_PROP,\s*"true"\)'),
                  'the TW_MODULES_MOUNTED_PROP setter')
    if idx + 2 >= len(lines) or "return true;" not in lines[idx + 2]:
        raise SystemExit(
            "ERROR: kernel_module_loader.cpp: unexpected code after the "
            "TW_MODULES_MOUNTED_PROP setter - inspect before patching"
        )
    if "return true;" not in lines[idx + 2]:
        raise SystemExit("ERROR: kernel_module_loader.cpp: cannot find the return statement anchor")

    block = [
        "\t// TB323FU: wait for the init.rc module handler to finish before returning.\n"
        "\t// init.recovery.qcom.rc sets twrp.module.handler_done=true after mounting\n"
        "\t// firmware/persist and starting the vendor crypto services; without this wait\n"
        "\t// /vendor stays busy and the next step cannot unmount it (breaks data wipe).\n"
        "\tLOGINFO(\"Waiting for twrp.module.handler_done\\n\");\n"
        "\tandroid::base::WaitForProperty(\"twrp.module.handler_done\", \"true\");\n"
        "\tLOGINFO(\"Waiting done twrp.module.handler_done\\n\");\n"
        "\n",
    ]
    lines[idx + 1:idx + 1] = block
    path.write_text("".join(lines))
    return "kernel_module_loader.cpp: added wait for twrp.module.handler_done"


def patch_thermal_globals(recovery: Path):
    """data.cpp: runtime thermal_zone detection needs three globals."""
    path = recovery / "data.cpp"
    text = path.read_text()

    if "gThermalInitialized" in text:
        return "data.cpp globals: already patched"

    anchor = "extern bool datamedia;\n"
    if text.count(anchor) != 1:
        raise SystemExit(
            f"ERROR: data.cpp: expected exactly one '{anchor.strip()}' line, "
            f"found {text.count(anchor)}"
        )
    globals_block = (
        "// TB323FU: the thermal_zone index changes every reboot, so the CPU\n"
        "// temperature zone is detected at runtime (see GetMagicValue).\n"
        "bool gThermalError = false;\n"
        "bool gThermalInitialized = false;\n"
        "int gThermalZone = -1;\n"
        "\n"
    )
    path.write_text(text.replace(anchor, globals_block + anchor, 1))
    return "data.cpp globals: added gThermalError/gThermalInitialized/gThermalZone"


def patch_thermal_default(recovery: Path):
    """data.cpp SetDefaultValues(): always enable CPU temp (zone is detected later)."""
    path = recovery / "data.cpp"
    lines = path.read_text().splitlines(keepends=True)

    if any("the CPU temp zone is detected at runtime" in l for l in lines):
        return "data.cpp default: already patched"

    start = line_of(lines, re.compile(r'^\s*#\s*ifdef\s+TW_NO_CPU_TEMP\b'),
                    'the TW_NO_CPU_TEMP block')
    end = find_if_block(lines, start)
    block = lines[start:end + 1]
    if not any('tw_no_cpu_temp' in l for l in block):
        raise SystemExit("ERROR: data.cpp: TW_NO_CPU_TEMP block looks wrong")
    if not any(re.search(r'^\s*#\s*else\b', l) for l in block):
        raise SystemExit("ERROR: data.cpp: TW_NO_CPU_TEMP block has no #else branch")

    indent = re.match(r'(\s*)', lines[start]).group(1)
    body = body_indent_of(lines, start, end)
    new_block = [
        f"{indent}#ifdef TW_NO_CPU_TEMP\n",
        f'{body}printf("TW_NO_CPU_TEMP := true\\n");\n',
        f'{body}mConst.SetValue("tw_no_cpu_temp", "1");\n',
        f"{indent}#else\n",
        f"{body}// TB323FU: the CPU temp zone is detected at runtime in GetMagicValue()\n",
        f"{body}// because the thermal_zone index is not stable across boots.\n",
        f'{body}mConst.SetValue("tw_no_cpu_temp", "0");\n',
        f"{indent}#endif\n",
    ]
    lines[start:end + 1] = new_block
    path.write_text("".join(lines))
    return "data.cpp default: CPU temp always enabled (runtime zone detection)"


def patch_thermal_read(recovery: Path):
    """data.cpp GetMagicValue(): detect the cpu-0-0-0 thermal zone at runtime."""
    path = recovery / "data.cpp"
    lines = path.read_text().splitlines(keepends=True)

    if any("gThermalZone" in l and "thermal_zone" in l for l in lines):
        return "data.cpp read: already patched"

    temp_var = line_of(lines, re.compile(r'varName == "tw_cpu_temp"'), 'the tw_cpu_temp getter')
    start = None
    for i in range(temp_var, min(temp_var + 40, len(lines))):
        if COND_START.match(lines[i]) and "TW_CUSTOM_CPU_TEMP_PATH" in lines[i]:
            start = i
            break
    if start is None:
        raise SystemExit("ERROR: data.cpp: TW_CUSTOM_CPU_TEMP_PATH block not found in tw_cpu_temp getter")
    end = find_if_block(lines, start)
    body = body_indent_of(lines, start, end)
    t = body + "\t"

    new_block = [
        f"{body}// TB323FU: the thermal_zone index changes every reboot; find the\n",
        f"{body}// zone whose type is cpu-0-0-0 once, then read its temperature.\n",
        f"{body}if (!gThermalInitialized) {{\n",
        f"{t}gThermalInitialized = true;\n",
        f"{t}gThermalError = true;\n",
        f"{t}for (int i = 0;; i++) {{\n",
        f'{t}\tstring file = string("/sys/class/thermal/thermal_zone") + std::to_string(i) + "/type";\n',
        f"{t}\tstring type;\n",
        f"{t}\tif (TWFunc::read_file(file, type) != 0) {{\n",
        f"{t}\t\tbreak;\n",
        f"{t}\t}}\n",
        f'{t}\tif (type == "cpu-0-0-0") {{\n',
        f'{t}\t\tLOGINFO("Use thermal zone %d\\n", i);\n',
        f"{t}\t\tgThermalError = false;\n",
        f"{t}\t\tgThermalZone = i;\n",
        f"{t}\t\tbreak;\n",
        f"{t}\t}}\n",
        f"{t}}}\n",
        f"{t}if (gThermalError) {{\n",
        f'{t}\tLOGERR("Failed to find proper thermal zone.\\n");\n',
        f"{t}}}\n",
        f"{body}}}\n",
        f"{body}if (gThermalError) {{\n",
        f"{t}return -1;\n",
        f"{body}}}\n",
        f'{body}cpu_temp_file = string("/sys/class/thermal/thermal_zone") + std::to_string(gThermalZone) + "/temp";\n',
        f"{body}if (TWFunc::read_file(cpu_temp_file, results) != 0)\n",
        f"{t}return -1;\n",
    ]
    lines[start:end + 1] = new_block
    path.write_text("".join(lines))
    return "data.cpp read: runtime thermal zone detection installed"


def verify(recovery: Path):
    problems = []

    kml = (recovery / "kernel_module_loader.cpp").read_text()
    if kml.count('WaitForProperty("twrp.module.handler_done", "true")') != 1:
        problems.append("kernel_module_loader.cpp: handler wait missing or duplicated")
    if kml.count("TW_MODULES_MOUNTED_PROP") < 1:
        problems.append("kernel_module_loader.cpp: TW_MODULES_MOUNTED_PROP prop handling damaged")

    data = (recovery / "data.cpp").read_text()
    if data.count("gThermalInitialized") < 3:
        problems.append("data.cpp: thermal globals/detection incomplete")
    if '"/sys/class/thermal/thermal_zone0/temp"' in data:
        problems.append("data.cpp: hard-coded thermal_zone0 still present")
    if data.count('mConst.SetValue("tw_no_cpu_temp", "0")') != 1:
        problems.append("data.cpp: CPU temp enable default missing")
    if data.count('mConst.SetValue("tw_no_cpu_temp", "1")') != 1:
        problems.append("data.cpp: CPU temp disable default missing")
    if "varName == \"tw_cpu_temp\"" not in data:
        problems.append("data.cpp: tw_cpu_temp getter vanished")

    return problems


def main():
    if len(sys.argv) != 2:
        raise SystemExit(f"usage: {sys.argv[0]} /path/to/bootable/recovery")
    recovery = Path(sys.argv[1])
    if not (recovery / "twrp.cpp").is_file():
        raise SystemExit(f"ERROR: {recovery} does not look like a recovery tree")

    for report in (
        patch_module_handler_wait(recovery),
        patch_thermal_globals(recovery),
        patch_thermal_default(recovery),
        patch_thermal_read(recovery),
    ):
        print(f"  {report}")

    problems = verify(recovery)
    if problems:
        for p in problems:
            print(f"ERROR: {p}", file=sys.stderr)
        raise SystemExit(1)

    print("PASS: TB323FU device fixes ported and verified")
    return 0


if __name__ == "__main__":
    sys.exit(main())
