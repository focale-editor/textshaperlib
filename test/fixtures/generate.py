"""Build an original tiny CFF font with cubic counters and a real GSUB ligature."""
from pathlib import Path
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.t2CharStringPen import T2CharStringPen
from fontTools.feaLib.builder import addOpenTypeFeaturesFromString

glyphs = ['.notdef', 'space', 'O', 'f', 'i', 'fi']
programs = {}
for name in glyphs:
    pen = T2CharStringPen(700, None)
    if name == 'O':
        pen.moveTo((100, 350))
        pen.curveTo((100, 800), (600, 800), (600, 350))
        pen.curveTo((600, -100), (100, -100), (100, 350))
        pen.closePath()
        pen.moveTo((220, 350))
        pen.curveTo((220, 80), (480, 80), (480, 350))
        pen.curveTo((480, 620), (220, 620), (220, 350))
        pen.closePath()
    elif name in ('f', 'i', 'fi'):
        # The ligature is deliberately different from separate f/i outlines.
        points = [(80, 0), (160, 0), (160, 650), (80, 650)] if name != 'fi' else [(80, 0), (520, 0), (300, 650)]
        pen.moveTo(points[0])
        for point in points[1:]:
            pen.lineTo(point)
        pen.closePath()
    programs[name] = pen.getCharString()
font = FontBuilder(1000, isTTF=False)
font.setupGlyphOrder(glyphs)
font.setupCharacterMap({32: 'space', 79: 'O', 102: 'f', 105: 'i'})
font.setupCFF('FocaleOutlineFixture', {'FullName': 'Focale Outline Fixture', 'FamilyName': 'Focale Outline Fixture', 'Weight': 'Regular'}, programs, {})
font.setupHorizontalMetrics({name: (300 if name == 'fi' else 700, 0) for name in glyphs})
font.setupHorizontalHeader(ascent=800, descent=-200)
font.setupNameTable({'familyName': 'Focale Outline Fixture', 'styleName': 'Regular', 'uniqueFontIdentifier': 'FocaleOutlineFixture', 'fullName': 'Focale Outline Fixture', 'psName': 'FocaleOutlineFixture'})
font.setupOS2(sTypoAscender=800, sTypoDescender=-200, usWinAscent=800, usWinDescent=200)
font.setupPost()
font.font['head'].created = font.font['head'].modified = 2082844800
addOpenTypeFeaturesFromString(font.font, 'feature liga { sub f i by fi; } liga;')
font.save(Path(__file__).with_name('curves.otf'))


# A separate system fallback: no glyph art is copied from installed fonts.
fallback_glyphs = ['.notdef', 'space', 'alpha', 'beta', 'alphabeta', 'O', 'acute', 'Oacute', 'supplementary']
fallback_programs = {}
for name in fallback_glyphs:
    pen = T2CharStringPen(700, None)
    if name not in ('.notdef', 'space'):
        if name == 'acute':
            points = [(180, 720), (280, 720), (380, 820), (280, 820)]
        elif name in ('alpha', 'O', 'Oacute'):
            points = [(80, 0), (500, 0), (500, 600), (80, 600)]
        elif name in ('alphabeta', 'supplementary'):
            points = [(60, 0), (600, 0), (350, 700)]
        else:
            points = [(100, 0), (300, 0), (300, 500), (100, 500)]
        pen.moveTo(points[0])
        for point in points[1:]:
            pen.lineTo(point)
        pen.closePath()
        if name == 'Oacute':
            pen.moveTo((180, 720))
            pen.lineTo((280, 720))
            pen.lineTo((380, 820))
            pen.lineTo((280, 820))
            pen.closePath()
    fallback_programs[name] = pen.getCharString()
fallback = FontBuilder(1000, isTTF=False)
fallback.setupGlyphOrder(fallback_glyphs)
fallback.setupCharacterMap({32: 'space', 0x3b1: 'alpha', 0x3b2: 'beta', 0x5d0: 'alpha', 0x5d1: 'beta', 79: 'O', 0x301: 'acute', 0xd3: 'Oacute', 0x10400: 'supplementary'})
fallback.setupCFF('FocaleFallbackFixture', {'FullName': 'Focale Fallback Fixture', 'FamilyName': 'Focale Fallback Fixture', 'Weight': 'Regular'}, fallback_programs, {})
fallback.setupHorizontalMetrics({name: (900 if name == 'alphabeta' else 0 if name == 'acute' else 700, 0) for name in fallback_glyphs})
fallback.setupHorizontalHeader(ascent=900, descent=-200)
fallback.setupNameTable({'familyName': 'Focale Fallback Fixture', 'styleName': 'Regular', 'uniqueFontIdentifier': 'FocaleFallbackFixture', 'fullName': 'Focale Fallback Fixture', 'psName': 'FocaleFallbackFixture'})
fallback.setupOS2(sTypoAscender=900, sTypoDescender=-200, usWinAscent=900, usWinDescent=200)
fallback.setupPost()
fallback.font['head'].created = fallback.font['head'].modified = 2082844800
addOpenTypeFeaturesFromString(fallback.font, 'feature liga { sub alpha beta by alphabeta; } liga;')
fallback.save(Path(__file__).with_name('fallback.otf'))
