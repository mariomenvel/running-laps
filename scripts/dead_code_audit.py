"""Auditoría de código muerto — alcanzabilidad desde lib/main.dart + dependencias sin usar.

    python scripts/dead_code_audit.py

Qué comprueba:
  1. Ficheros .dart de lib/ NO alcanzables transitivamente desde main.dart
     (BFS sobre imports/exports). Sin `part`/`part of` ni imports condicionales
     en el repo, y como Dart no usa reflexión, no alcanzable == código muerto.
     El script avisa si aparece un `part` o un import condicional, porque eso
     invalidaría la garantía.
  2. Dependencias directas de pubspec.yaml sin un solo `package:<dep>/` en
     lib/, test/ o scripts/. Excepciones conocidas al final del fichero.

⚠️ Resolución de imports relativos (el detalle que hace mal un script ingenuo):
   se resuelven en el espacio de URIs de `package:`, donde lib/ es la raíz y los
   '..' que sobran se DESCARTAN (RFC 3986 clampea en la autoridad). Por eso
   '../../../../config/app_theme.dart' desde lib/features/admin/views/ apunta a
   lib/config/app_theme.dart y no a <repo>/config/. Usar os.path.normpath a
   secas descarta esas aristas y marca ficheros VIVOS como muertos.

Lo que este script NO ve: miembros privados muertos dentro de ficheros vivos
(métodos, campos). Para eso, `flutter analyze` y sus unused_element/unused_field.
"""

import os
import re
import sys
from collections import deque

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, "lib")
PKG = "running_laps"

# Ficheros no alcanzables que se conservan a propósito (tooling manual, etc.)
KEEP_UNREACHABLE = {
    os.path.join("lib", "scripts", "generate_test_workouts.dart"),
}
# Dependencias sin imports que son legítimas (assets, pins, plugins nativos)
KEEP_DEPS = {
    "cupertino_icons",                  # fuente de iconos, no se importa
    "firebase_core_platform_interface",  # pin exacto: ver nota en pubspec.yaml
}

IMPORT_RE = re.compile(r"""^\s*(?:import|export)\s+['"]([^'"]+)['"]""", re.M)
PART_RE = re.compile(r"""^\s*part\s+(?:of\s+)?['"]""", re.M)
COND_RE = re.compile(r"""\bif\s*\(\s*dart\.library""")

warnings: list[str] = []


def norm(p: str) -> str:
    return os.path.normcase(os.path.abspath(p))


def resolve(target: str, from_file: str) -> str | None:
    """Devuelve la ruta del import, o None si es dart:/package: de terceros."""
    if target.startswith(f"package:{PKG}/"):
        rest = target[len(f"package:{PKG}/"):]
        return os.path.join(LIB, rest.replace("/", os.sep))
    if target.startswith(("package:", "dart:")):
        return None
    base = os.path.relpath(os.path.dirname(from_file), LIB)
    stack = [] if base == "." else base.split(os.sep)
    for seg in target.split("/"):
        if seg in ("", "."):
            continue
        if seg == "..":
            if stack:            # '..' de más -> se descarta (clamp en lib/)
                stack.pop()
        else:
            stack.append(seg)
    return os.path.join(LIB, *stack)


def dart_files(root: str) -> list[str]:
    out = []
    for dirpath, dirs, names in os.walk(root):
        dirs[:] = [d for d in dirs if d not in {".dart_tool", "build"}]
        out += [os.path.join(dirpath, n) for n in names if n.endswith(".dart")]
    return out


def check_reachability() -> int:
    files = dart_files(LIB)
    graph = {}
    for f in files:
        src = open(f, encoding="utf-8", errors="replace").read()
        if PART_RE.search(src):
            warnings.append(f"part/part of en {os.path.relpath(f, ROOT)}")
        if COND_RE.search(src):
            warnings.append(f"import condicional en {os.path.relpath(f, ROOT)}")
        deps = set()
        for t in IMPORT_RE.findall(src):
            r = resolve(t, f)
            if r is None:
                continue
            if os.path.exists(r):
                deps.add(norm(r))
            else:
                warnings.append(
                    f"import sin resolver: {os.path.relpath(f, ROOT)} -> {t}")
        graph[norm(f)] = deps

    entry = norm(os.path.join(LIB, "main.dart"))
    seen, queue = {entry}, deque([entry])
    while queue:
        for dep in graph.get(queue.popleft(), ()):
            if dep not in seen:
                seen.add(dep)
                queue.append(dep)

    dead = sorted(
        rel for rel in (os.path.relpath(f, ROOT) for f in files)
        if norm(os.path.join(ROOT, rel)) not in seen and rel not in KEEP_UNREACHABLE
    )
    print(f"lib/: {len(files)} ficheros, {len(seen)} alcanzables desde main.dart")
    if dead:
        print(f"\n{len(dead)} NO alcanzables (código muerto):")
        for d in dead:
            print(f"  {d}")
    else:
        print("Sin ficheros muertos.")
    return len(dead)


def check_deps() -> int:
    pub = open(os.path.join(ROOT, "pubspec.yaml"), encoding="utf-8").read()
    block = pub.split("dependencies:", 1)[1].split("dev_dependencies:", 1)[0]
    deps = [m.group(1) for m in re.finditer(r"^  ([a-z0-9_]+):", block, re.M)]
    blob = "\n".join(
        open(p, encoding="utf-8", errors="replace").read()
        for sub in ("lib", "test", "scripts")
        for p in dart_files(os.path.join(ROOT, sub))
    )
    unused = [d for d in deps
              if d not in {"flutter"} | KEEP_DEPS and f"package:{d}/" not in blob]
    print(f"\npubspec: {len(deps)} dependencias directas")
    if unused:
        print(f"\n{len(unused)} sin ningún import:")
        for d in unused:
            print(f"  {d}")
    else:
        print("Todas las dependencias se usan.")
    return len(unused)


if __name__ == "__main__":
    problems = check_reachability() + check_deps()
    if warnings:
        print(f"\nAVISOS ({len(warnings)}) — invalidan la garantía, revisar:")
        for w in sorted(set(warnings)):
            print(f"  ! {w}")
    sys.exit(1 if problems else 0)
