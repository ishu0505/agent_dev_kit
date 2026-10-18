"""Build guide/agent-context-kit.html: the template plus BOOTSTRAP.md's prompt.

Usage: python3 guide/build.py   (from the kit root)
"""

import html
from pathlib import Path

KIT = Path(__file__).resolve().parents[1]
template = (KIT / "guide" / "template.html").read_text()
prompt = (KIT / "BOOTSTRAP.md").read_text().split("\n---\n", 1)[1].strip()
version = (KIT / "VERSION").read_text().strip()
page = template.replace("__PROMPT__", html.escape(prompt)).replace("__VERSION__", version)
(KIT / "guide" / "agent-context-kit.html").write_text(page)
print("wrote guide/agent-context-kit.html")
