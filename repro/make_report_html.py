"""Render repro/REPORT.md as a self-contained HTML page.

A deliberately small Markdown subset is supported: headings, paragraphs,
bullet and numbered lists, pipe tables, fenced code, bold/italic/inline code,
and images. Images are inlined as base64 so the page is a single file.
"""
import base64
import html
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "repro", "REPORT.md")
DST = os.path.join(ROOT, "repro", "report.html")

TEMPLATE = """<!DOCTYPE html>
<html lang="zh"><head><meta charset="utf-8">
<title>{title}</title>
<style>
:root {{ --ink:#1b1f24; --muted:#5b6572; --line:#d8dee6; --bg:#ffffff;
        --accent:#1f4e79; --band:#f4f7fa; }}
* {{ box-sizing:border-box; }}
body {{ margin:0; background:#eef1f5; color:var(--ink);
  font-family:"Segoe UI","Source Han Sans SC","Microsoft YaHei",system-ui,sans-serif;
  line-height:1.72; font-size:16px; }}
.page {{ max-width:980px; margin:32px auto; background:var(--bg); padding:56px 64px 72px;
  box-shadow:0 2px 18px rgba(20,30,50,.10); border-radius:10px; }}
h1 {{ font-size:30px; line-height:1.3; margin:0 0 6px; color:var(--accent);
  letter-spacing:.2px; }}
h2 {{ font-size:22px; margin:44px 0 14px; padding-bottom:8px;
  border-bottom:2px solid var(--line); color:var(--accent); }}
h3 {{ font-size:17.5px; margin:28px 0 10px; }}
p, li {{ font-size:15.6px; }}
blockquote {{ margin:18px 0; padding:12px 18px; background:var(--band);
  border-left:4px solid #9fb6cc; color:#33404e; border-radius:0 6px 6px 0; }}
code {{ background:#eef2f7; padding:1px 6px; border-radius:4px;
  font-family:Consolas,"SF Mono",monospace; font-size:13.6px; color:#0f3f6b; }}
pre {{ background:#f6f8fa; border:1px solid var(--line); border-radius:8px;
  padding:14px 16px; overflow:auto; }}
pre code {{ background:none; padding:0; color:#1b1f24; }}
table {{ border-collapse:collapse; width:100%; margin:18px 0;
  font-size:14.6px; font-variant-numeric:tabular-nums; }}
th, td {{ border:1px solid var(--line); padding:8px 12px; text-align:left; }}
th {{ background:var(--band); font-weight:600; color:#243447; }}
tbody tr:nth-child(even) {{ background:#fafbfd; }}
img {{ max-width:100%; display:block; margin:22px auto; border:1px solid var(--line);
  border-radius:8px; background:#fff; }}
hr {{ border:none; border-top:1px solid var(--line); margin:36px 0; }}
.meta {{ color:var(--muted); font-size:14px; }}
</style></head><body><div class="page">
{body}
</div></body></html>"""


def inline(t: str) -> str:
    t = html.escape(t)
    t = re.sub(r"`([^`]+)`", r"<code>\1</code>", t)
    t = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", t)
    t = re.sub(r"(?<![\w*])\*([^*\n]+)\*(?![\w*])", r"<em>\1</em>", t)
    return t


def image_tag(alt: str, path: str) -> str:
    full = os.path.join(os.path.dirname(SRC), path.lstrip("./"))
    if not os.path.isfile(full):
        return f'<p class="meta">[missing figure: {html.escape(path)}]</p>'
    ext = os.path.splitext(full)[1].lower().lstrip(".")
    mime = "image/png" if ext == "png" else f"image/{ext}"
    with open(full, "rb") as fh:
        b64 = base64.b64encode(fh.read()).decode()
    return f'<img alt="{html.escape(alt)}" src="data:{mime};base64,{b64}">'


def convert(md: str) -> str:
    lines = md.split("\n")
    out, i = [], 0
    title = "Report"
    while i < len(lines):
        ln = lines[i]
        if ln.startswith("```"):
            j = i + 1
            buf = []
            while j < len(lines) and not lines[j].startswith("```"):
                buf.append(html.escape(lines[j]))
                j += 1
            out.append("<pre><code>" + "\n".join(buf) + "</code></pre>")
            i = j + 1
            continue
        m = re.match(r"^(#{1,4})\s+(.*)$", ln)
        if m:
            lvl = len(m.group(1))
            txt = m.group(2)
            if lvl == 1:
                title = txt
            out.append(f"<h{lvl}>{inline(txt)}</h{lvl}>")
            i += 1
            continue
        if re.match(r"^\s*---+\s*$", ln):
            out.append("<hr>")
            i += 1
            continue
        m = re.match(r"^!\[([^\]]*)\]\(([^)]+)\)", ln.strip())
        if m:
            out.append(image_tag(m.group(1), m.group(2)))
            i += 1
            continue
        m = re.match(r"^>\s?(.*)$", ln)
        if m:
            buf = []
            while i < len(lines) and re.match(r"^>\s?", lines[i]):
                buf.append(re.match(r"^>\s?(.*)$", lines[i]).group(1))
                i += 1
            out.append("<blockquote>" + inline(" ".join(buf)) + "</blockquote>")
            continue
        if ln.strip().startswith("|") and i + 1 < len(lines) and \
                re.match(r"^\s*\|[\s:\-|]+\|\s*$", lines[i + 1]):
            header = [c.strip() for c in ln.strip().strip("|").split("|")]
            i += 2
            rows = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                rows.append([c.strip() for c in lines[i].strip().strip("|").split("|")])
                i += 1
            th = "".join(f"<th>{inline(c)}</th>" for c in header)
            tb = "".join("<tr>" + "".join(f"<td>{inline(c)}</td>" for c in r) + "</tr>"
                         for r in rows)
            out.append(f"<table><thead><tr>{th}</tr></thead><tbody>{tb}</tbody></table>")
            continue
        if re.match(r"^\s*[-*]\s+", ln):
            buf = []
            while i < len(lines) and re.match(r"^\s*[-*]\s+", lines[i]):
                buf.append(re.sub(r"^\s*[-*]\s+", "", lines[i]))
                i += 1
            out.append("<ul>" + "".join(f"<li>{inline(b)}</li>" for b in buf) + "</ul>")
            continue
        if re.match(r"^\s*\d+\.\s+", ln):
            buf = []
            while i < len(lines) and re.match(r"^\s*\d+\.\s+", lines[i]):
                buf.append(re.sub(r"^\s*\d+\.\s+", "", lines[i]))
                i += 1
            out.append("<ol>" + "".join(f"<li>{inline(b)}</li>" for b in buf) + "</ol>")
            continue
        if not ln.strip():
            i += 1
            continue
        buf = []
        while i < len(lines) and lines[i].strip() and not re.match(
                r"^(#{1,4}\s|\||>|```|\s*[-*]\s|\s*\d+\.\s|---)", lines[i]):
            buf.append(lines[i].strip())
            i += 1
        out.append("<p>" + inline(" ".join(buf)) + "</p>")
    return title, "\n".join(out)


def main():
    with open(SRC, encoding="utf-8") as fh:
        md = fh.read()
    title, body = convert(md)
    with open(DST, "w", encoding="utf-8") as fh:
        fh.write(TEMPLATE.format(title=html.escape(title), body=body))
    print("wrote", DST, f"({os.path.getsize(DST)/1024:.0f} kB)")


if __name__ == "__main__":
    main()
