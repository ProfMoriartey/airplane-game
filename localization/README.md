# Translations

The game is written in English. To add another language:

1. Run `python3 tools/extract_strings.py` to refresh `messages.pot` with every piece of text in the game.
2. Copy `messages.pot` to a file named after the language code, such as `fr.po` (French), `de.po` (German) or `es.po` (Spanish).
3. Open it in a PO editor such as [Poedit](https://poedit.net) (free), set the language, and translate each line.
   - Keep markers like `%d`, `%s` and `{fire}` exactly as they are: the game fills them in with numbers, names and keys.
   - Keep tags like `[b]...[/b]` and `[color=...]...[/color]` around the matching words.
   - Lines left empty stay in English.
4. Save the `.po` file in this folder. The game finds it automatically, and it appears under Settings > Gameplay > Language.

When the game's text changes, run the script again and use Poedit's *Catalog > Update from POT file* to bring each translation up to date.
