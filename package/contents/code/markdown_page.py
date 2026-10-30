#!/usr/bin/env python3
"""Markdown as a page to read in a browser, for computers with no app that
shows Markdown rendered (jump.py: open_markdown). Standard library only.

It knows what Claude's plans and the widget's subagent runs use: headings,
paragraphs, **bold**, *italics*, `code`, fenced code blocks, lists (nested,
numbered, task lists), quotes, tables, rules and links. Everything is
escaped; links only go out when they're http(s), and images aren't loaded
(their text shows instead), so opening the page fetches nothing. The page
carries a Content-Security-Policy that blocks scripts and any loading.

    python3 -I markdown_page.py FILE.md > FILE.html
"""

import html
import re
import sys

# (a fence's info string: its language, and maybe more after a space)
FENCE = re.compile(r"^(\s*)(`{3,}|~{3,})\s*([^\s`]*)[^`]*$")
HEADING = re.compile(r"^(#{1,6})\s+(.*?)(?:\s+#+)?\s*$")  # (C#: a closing run has a space before it)
LIST_ITEM = re.compile(r"^(\s*)([-*+]|\d{1,9}[.)])\s+(.*)$")
RULE = re.compile(r"^\s*([-*_])(\s*\1){2,}\s*$")
TABLE_SEP = re.compile(r"^\s*\|?\s*:?-{2,}:?\s*(\|\s*:?-{2,}:?\s*)*\|?\s*$")
QUOTE = re.compile(r"^\s*>\s?(.*)$")

STYLE = """
:root { color-scheme: light dark; --fg: #1f2328; --bg: #ffffff; --muted: #59636e; --line: #d1d9e0; --code: #f6f8fa; --link: #0969da; }
@media (prefers-color-scheme: dark) {
  :root { --fg: #e6edf3; --bg: #0d1117; --muted: #9198a1; --line: #3d444d; --code: #151b23; --link: #4493f8; }
}
html { background: var(--bg); color: var(--fg); }
body { max-width: 52rem; margin: 2rem auto; padding: 0 1.25rem; font: 16px/1.6 system-ui, -apple-system, "Segoe UI", sans-serif; }
h1, h2, h3, h4, h5, h6 { line-height: 1.25; margin: 1.5em 0 0.5em; }
h1, h2 { padding-bottom: 0.3em; border-bottom: 1px solid var(--line); }
p, ul, ol, pre, table, blockquote { margin: 0 0 1em; }
li > ul, li > ol { margin: 0.25em 0; }
code { font: 0.9em ui-monospace, "SFMono-Regular", "DejaVu Sans Mono", monospace; background: var(--code); padding: 0.1em 0.35em; border-radius: 4px; }
pre { background: var(--code); padding: 0.9em 1em; border-radius: 6px; overflow-x: auto; line-height: 1.45; }
pre code { background: none; padding: 0; }
blockquote { color: var(--muted); border-left: 0.25em solid var(--line); padding: 0 1em; margin-left: 0; }
table { border-collapse: collapse; display: block; overflow-x: auto; }
th, td { border: 1px solid var(--line); padding: 0.35em 0.8em; }
th { background: var(--code); }
hr { border: 0; border-top: 1px solid var(--line); margin: 1.5em 0; }
a { color: var(--link); }
.task { list-style: none; margin-left: -1.3em; }
.image { color: var(--muted); font-style: italic; }
"""

CSP = "default-src 'none'; style-src 'unsafe-inline'"


def inline(text):
    """A line's inline markup as HTML: code spans first (nothing inside them
    counts), then images (their text only), links, bold and italics."""
    out, rest = [], text
    while rest:
        m = re.search(r"(`+)(.+?)\1", rest)
        if not m:
            out.append(spans(rest))
            break
        out.append(spans(rest[:m.start()]))
        out.append(f"<code>{html.escape(m.group(2).strip())}</code>")
        rest = rest[m.end():]
    return "".join(out)


def spans(text):
    t = html.escape(text.replace("\0", ""), quote=True)
    # ![alt](src): not loaded
    t = re.sub(r"!\[([^\]]*)\]\([^)\s]*(?:\s+&quot;[^&]*&quot;)?\)",
               lambda m: f'<span class="image">[image: {m.group(1) or "untitled"}]</span>', t)
    # [text](url): a link only to http(s). Links are set aside while bold
    # and italics are found, which never reach into an address (__init__.py)
    links = []

    def link(m):
        label, url = emphasis(m.group(1)), m.group(2)
        if re.match(r"https?://", url):
            links.append(f'<a href="{url}" rel="noreferrer noopener">{label}</a>')
        else:
            links.append(f"{label} ({url})" if url and url != m.group(1) else label)
        return f"\0{len(links) - 1}\0"
    t = emphasis(re.sub(r"\[([^\]]+)\]\(([^)\s]+)\)", link, t))
    return re.sub(r"\0(\d+)\0", lambda m: links[int(m.group(1))], t)


def emphasis(t):
    """**Bold**, *italics* and ~~struck~~ text of escaped text."""
    t = re.sub(r"(?<![\w*])(\*\*|__)(?=\S)(.+?)(?<=\S)\1(?![\w*])", r"<strong>\2</strong>", t)
    t = re.sub(r"(?<![\w*])\*(?=\S)(.+?)(?<=\S)\*(?![\w*])", r"<em>\1</em>", t)
    t = re.sub(r"(?<![\w_])_(?=\S)(.+?)(?<=\S)_(?![\w_])", r"<em>\1</em>", t)
    t = re.sub(r"~~(?=\S)(.+?)(?<=\S)~~", r"<del>\1</del>", t)
    return t


def cells(line):
    line = line.strip()
    if line.startswith("|"):
        line = line[1:]
    if line.endswith("|") and not line.endswith("\\|"):
        line = line[:-1]
    return [c.strip().replace("\\|", "|") for c in re.split(r"(?<!\\)\|", line)]


def render_list(items):
    """HTML of list items [(indent, marker, text, blocks: HTML under it)], nested by their indent."""
    out, stack = [], []  # stack: (indent, tag)
    for indent, marker, text, blocks in items:
        tag = "ol" if marker[0].isdigit() else "ul"
        while stack and indent < stack[-1][0]:
            out.append(f"</li></{stack.pop()[1]}>")
        if stack and indent == stack[-1][0] and tag != stack[-1][1]:
            out.append(f"</li></{stack.pop()[1]}>")
        if not stack or indent > stack[-1][0]:
            start = int(marker[:-1]) if tag == "ol" and marker[:-1].isdigit() and int(marker[:-1]) != 1 else None
            out.append(f'<{tag}{f" start={start}" if start else ""}>')
            stack.append((indent, tag))
        else:
            out.append("</li>")
        task = re.match(r"\[([ xX])\]\s+(.*)$", text)
        if task:
            box = "☑" if task.group(1) in "xX" else "☐"
            out.append(f'<li class="task">{box} {inline(task.group(2))}')
        else:
            out.append(f"<li>{inline(text)}")
        out.extend(blocks)
    while stack:
        out.append(f"</li></{stack.pop()[1]}>")
    return "".join(out)


def fenced(lines, i):
    """(HTML of the fenced code block that starts at lines[i], the line after
    it). A fence indented under a list item drops that much of each line."""
    fence = FENCE.match(lines[i])
    indent, mark, lang, code = len(fence.group(1)), fence.group(2), fence.group(3), []
    i += 1
    # (it ends at a line of its own mark alone: ```py inside a ``` block doesn't)
    while i < len(lines) and not re.fullmatch(re.escape(mark[0]) + "{%d,}" % len(mark), lines[i].strip()):
        line = lines[i]
        code.append(line[min(indent, len(line) - len(line.lstrip(" "))):])
        i += 1
    cls = f' class="language-{html.escape(lang)}"' if lang else ""
    return f"<pre><code{cls}>{html.escape(chr(10).join(code))}</code></pre>", i + 1


def body(markdown):
    """The HTML body of a Markdown text."""
    lines = markdown.replace("\r\n", "\n").replace("\t", "    ").split("\n")
    out, i, para = [], 0, []

    def flush():
        if para:
            out.append("<p>" + "<br>".join(inline(p) for p in para) + "</p>")
            para.clear()

    while i < len(lines):
        line = lines[i]
        if FENCE.match(line):
            flush()
            block, i = fenced(lines, i)
            out.append(block)
            continue
        if not line.strip():
            flush()
            i += 1
            continue
        heading = HEADING.match(line)
        if heading:
            flush()
            n = len(heading.group(1))
            out.append(f"<h{n}>{inline(heading.group(2))}</h{n}>")
            i += 1
            continue
        if RULE.match(line):
            flush()
            out.append("<hr>")
            i += 1
            continue
        if "|" in line and i + 1 < len(lines) and TABLE_SEP.match(lines[i + 1]):
            flush()
            head = cells(line)
            rows = []
            i += 2
            while i < len(lines) and "|" in lines[i] and lines[i].strip():
                rows.append(cells(lines[i]))
                i += 1
            out.append("<table><thead><tr>" + "".join(f"<th>{inline(c)}</th>" for c in head) + "</tr></thead><tbody>"
                       + "".join("<tr>" + "".join(f"<td>{inline(c)}</td>" for c in r) + "</tr>" for r in rows)
                       + "</tbody></table>")
            continue
        if QUOTE.match(line):
            flush()
            quoted = []
            while i < len(lines) and QUOTE.match(lines[i]):
                quoted.append(QUOTE.match(lines[i]).group(1))
                i += 1
            out.append(f"<blockquote>{body(chr(10).join(quoted))}</blockquote>")
            continue
        item = LIST_ITEM.match(line)
        # (a numbered list breaks into a paragraph only when it starts at 1, as in CommonMark)
        if item and not (para and item.group(2)[0].isdigit() and item.group(2)[:-1] != "1"):
            flush()
            items = []
            while i < len(lines):
                m = LIST_ITEM.match(lines[i])
                if m:
                    items.append([len(m.group(1)), m.group(2), m.group(3), []])
                elif items and lines[i].startswith(" ") and FENCE.match(lines[i]):  # code under the item
                    block, i = fenced(lines, i)
                    items[-1][3].append(block)
                    continue
                elif lines[i].strip() and items and lines[i].startswith(" "):
                    items[-1][2] += " " + lines[i].strip()  # the item goes on
                else:
                    break
                i += 1
            out.append(render_list(items))
            continue
        para.append(line.strip())
        i += 1
    flush()
    return "\n".join(out)


def page(markdown, title=""):
    """A whole HTML page of a Markdown text."""
    if not title:
        first = next((HEADING.match(l) for l in markdown.splitlines() if HEADING.match(l)), None)
        title = first.group(2) if first else "Markdown"
    return (f'<!DOCTYPE html>\n<html><head><meta charset="utf-8">\n'
            f'<meta http-equiv="Content-Security-Policy" content="{CSP}">\n'
            f'<meta name="viewport" content="width=device-width, initial-scale=1">\n'
            f"<title>{html.escape(re.sub(r'[`*_]', '', title))}</title>\n<style>{STYLE}</style></head>\n"
            f"<body>\n{body(markdown)}\n</body></html>\n")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: markdown_page.py FILE.md")
    with open(sys.argv[1], encoding="utf-8", errors="replace") as f:
        sys.stdout.write(page(f.read()))
