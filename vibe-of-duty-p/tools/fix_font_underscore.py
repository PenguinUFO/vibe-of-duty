"""Makes Science-Gothic-Variable-Fixed.ttf (the game font) from the original Science-Gothic-Variable.ttf.

The original font classes the underscore as a combining mark (GDEF class 3, and it sits in GPOS mark-attachment
lookups), so text shapers give it no width and hang it on a neighbouring letter: "a_b" draws the line under or over
the "a". Here it becomes an ordinary base glyph and is taken out of the mark lookups. The font is OFL with no Reserved
Font Name, so a modified copy may keep the name.

Run from the Godot project folder (needs fontTools: pip install fonttools):
    python tools/fix_font_underscore.py
"""
from fontTools.ttLib import TTFont

SRC = "assets/fonts/science-gothic/Science-Gothic-Variable.ttf"
DST = "assets/fonts/science-gothic/Science-Gothic-Variable-Fixed.ttf"

font = TTFont(SRC)
font["GDEF"].table.GlyphClassDef.classDefs["underscore"] = 1  # base glyph
removed = 0
for lookup in font["GPOS"].table.LookupList.Lookup:
    for sub in lookup.SubTable:
        sub = getattr(sub, "ExtSubTable", None) or sub
        if sub.LookupType not in (4, 6):  # mark-to-base, mark-to-mark
            continue
        coverage = getattr(sub, "MarkCoverage", None) or getattr(sub, "Mark1Coverage", None)
        marks = getattr(sub, "MarkArray", None) or getattr(sub, "Mark1Array", None)
        if coverage is not None and "underscore" in coverage.glyphs:
            i = coverage.glyphs.index("underscore")
            coverage.glyphs.pop(i)
            marks.MarkRecord.pop(i)
            removed += 1
font.save(DST)
print("underscore made a base glyph, removed from %d mark lookups -> %s" % (removed, DST))
