"""Collects every piece of player-facing text into localization/messages.pot.

Translators copy messages.pot to a language file (for example fr.po), fill in
the translations with a PO editor such as Poedit, and save it in the
localization folder. The game loads every .po file there by itself.

Run from the project folder:  python3 tools/extract_strings.py

Text is picked up from:
  - scripts: strings passed to tr() or TranslationServer.translate(), and any
    other string literal that reads like words (names, labels, messages);
  - scenes and data files: text, title, description and similar properties,
    and radio message lists.
"""

import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "localization" / "messages.pot"

# Scene / resource properties that hold text the player reads.
TEXT_PROPERTIES = {
    "text", "title", "description", "display_name", "briefing", "summary", "intro",
    "ok_button_text", "cancel_button_text", "dialog_text", "tooltip_text", "placeholder_text",
    "leader_name", "pilot_name", "name_text",
}
TEXT_LIST_PROPERTIES = {"radio_on_complete", "intro_radio", "radio_on_start"}

STRING = re.compile(r'"((?:[^"\\]|\\.)*)"')
TRANSLATED = re.compile(r'(?:\btr|TranslationServer\.translate)\(\s*"((?:[^"\\]|\\.)*)"')
# Lines whose strings are for developers, not players.
SKIP_LINE = re.compile(
    r"push_error|push_warning|print\(|printerr|get_node|has_node|find_child|is_action|InputMap|"
    r"add_to_group|is_in_group|get_nodes_in_group|call_group|has_method|connect\(|emit_signal|"
    r"load\(|preload\(|get_setting|set_meta|get_meta|has_meta|theme_|_override|get_theme|"
    r"\bbus\b|BUSES|get_bus_index|play_ui|play_at|play_music|play_sting|SFX\[|MUSIC\[|"
    r"\bmatch\b|^\s*#|\.has\(|\.get\(\"|class_name|extends|@export_group|@export_category|\.name = "
)
WORD = re.compile(r"[A-Za-z]{2,}")


def looks_like_words(text: str) -> bool:
    """True for "Fire guns" or "Back"; false for "ui_cancel", "res://x", "%d m" or "#f2cc80"."""
    if not WORD.search(re.sub(r"%[0-9.]*[dsf]|\[/?[a-z]+(=[^\]]*)?\]|\\n", " ", text)):
        return False
    if re.search(r"^(res|user)://|^[%$^]|^#|\.(gd|tscn|tres|png|wav|ogg|json|cfg|po)$", text):
        return False
    if re.fullmatch(r"[a-z0-9_./:&-]+", text):  # identifiers, actions, ids, paths
        return False
    if re.fullmatch(r"[A-Z]{1,3}", text):
        return False  # short ids like "SFX", "UI"
    return True


def from_script(path: pathlib.Path, found: dict) -> None:
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        for text in TRANSLATED.findall(line):
            add(found, text, path, number)
        if SKIP_LINE.search(line):
            continue
        # Plain literals that read like words, e.g. button.text = "Back".
        for text in STRING.findall(line):
            if looks_like_words(text) and not re.fullmatch(r"[A-Z][a-z]+[A-Z]\w*", text):
                add(found, text, path, number)


# A property and its value, which may be a string running over several lines.
PROPERTY = re.compile(r'^(\w+) = ("(?:[^"\\]|\\.)*"|PackedStringArray\(.*?\)|Array\[String\]\(\[.*?\]\))', re.M | re.S)


def from_resource(path: pathlib.Path, found: dict) -> None:
    content = path.read_text(encoding="utf-8")
    for match in PROPERTY.finditer(content):
        key, value = match.groups()
        if key in TEXT_PROPERTIES or key in TEXT_LIST_PROPERTIES:
            number = content.count("\n", 0, match.start()) + 1
            for text in STRING.findall(value):
                # Scene files keep real line breaks inside strings; PO files spell them \n.
                text = text.replace("\n", "\\n")
                if looks_like_words(text):
                    add(found, text, path, number)


def add(found: dict, text: str, path: pathlib.Path, number: int) -> None:
    found.setdefault(text, []).append("%s:%d" % (path.relative_to(ROOT).as_posix(), number))


def main() -> None:
    found: dict = {}
    for path in sorted((ROOT / "scripts").rglob("*.gd")):
        from_script(path, found)
    for folder in ("scenes", "data"):
        for suffix in ("*.tscn", "*.tres"):
            for path in sorted((ROOT / folder).rglob(suffix)):
                from_resource(path, found)
    lines = [
        "# Player-facing text for the game. Copy this file to <language>.po",
        "# (for example fr.po) to start a translation.",
        'msgid ""',
        'msgstr ""',
        '"Content-Type: text/plain; charset=UTF-8\\n"',
        "",
    ]
    for text in sorted(found, key=lambda t: found[t][0]):
        lines.append("#: " + " ".join(found[text][:4]))
        if re.search(r"%[0-9.]*[dsf]", text):
            lines.append("#, c-format")
        lines.append('msgid "%s"' % text)
        lines.append('msgstr ""')
        lines.append("")
    OUTPUT.write_text("\n".join(lines), encoding="utf-8")
    print("Wrote %d strings to %s" % (len(found), OUTPUT.relative_to(ROOT)))


if __name__ == "__main__":
    main()
