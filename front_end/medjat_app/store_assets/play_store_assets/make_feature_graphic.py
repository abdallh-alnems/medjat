#!/usr/bin/env python3
"""
يولّد الرسم المميز (Feature Graphic 1024×500) لمتجر Google Play — نسخة عربية وإنجليزية.
المخرجات:
  feature_graphic/ar/feature_graphic_1024x500.png
  feature_graphic/en/feature_graphic_1024x500.png
  feature_graphic/feature_graphic_1024x500.png   (نسخة افتراضية = عربية)
"""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import arabic_reshaper
from bidi.algorithm import get_display

HERE = os.path.dirname(os.path.abspath(__file__))
FONTS = os.path.join(HERE, "..", "..", "assets", "fonts")
FB = os.path.join(FONTS, "IBMPlexSansArabic-Bold.ttf")
FS = os.path.join(FONTS, "IBMPlexSansArabic-SemiBold.ttf")
FM = os.path.join(FONTS, "IBMPlexSansArabic-Medium.ttf")
GE = "/System/Library/Fonts/Avenir Next.ttc"   # 0=Bold, 2=DemiBold, 5=Medium, 7=Regular
ICON = os.path.join(HERE, "icon", "app_icon_512.png")

W, H = 1024, 500
C1, C2 = (94,175,155), (25,80,68)
GOLD = (255,214,120)

def ar(t): return get_display(arabic_reshaper.reshape(t))

def gradient():
    img = Image.new("RGB",(W,H)); px=img.load(); m=W+H
    for y in range(H):
        for x in range(W):
            t=(x+y)/m
            px[x,y]=tuple(int(C1[i]+(C2[i]-C1[i])*t) for i in range(3))
    img = img.convert("RGBA")
    d = ImageDraw.Draw(img,"RGBA")
    for r in (150,250,360,480):
        d.ellipse([W-120-r,-80-r,W-120+r,-80+r], outline=(255,255,255,20), width=3)
    return img

def rounded_icon(size, radius):
    ic = Image.open(ICON).convert("RGBA").resize((size,size), Image.LANCZOS)
    mask = Image.new("L",(size,size),0)
    ImageDraw.Draw(mask).rounded_rectangle([0,0,size,size], radius=radius, fill=255)
    out = Image.new("RGBA",(size,size),(0,0,0,0))
    out.paste(ic,(0,0),mask)
    return out

def build(out_path, lang):
    bg = gradient(); d = ImageDraw.Draw(bg,"RGBA")

    # --- الأيقونة على اليسار مع ظل ناعم ---
    isz = 300; ix = 78; iy = (H-isz)//2
    icon = rounded_icon(isz, 70)
    sh = Image.new("RGBA",(W,H),(0,0,0,0))
    ImageDraw.Draw(sh).rounded_rectangle([ix+10,iy+18,ix+isz+10,iy+isz+18], radius=70, fill=(0,0,0,120))
    sh = sh.filter(ImageFilter.GaussianBlur(26))
    bg = Image.alpha_composite(bg, sh); bg.alpha_composite(icon,(ix,iy))
    d = ImageDraw.Draw(bg,"RGBA")

    # --- النصوص ---
    if lang=="ar":
        brand = ar("ميدجات"); sub = ar("الحضور والموارد البشرية")
        tag   = ar("حضور بالموقع · رواتب · إجازات · مستندات")
        bf = ImageFont.truetype(FB, 96); sf = ImageFont.truetype(FS, 40); tf = ImageFont.truetype(FM, 27)
        anchor_right = W - 70                # محاذاة لليمين
    else:
        brand = "Medjat"; sub = "HR & Attendance"
        tag   = "GPS attendance · Payslips · Leaves · Documents"
        bf = ImageFont.truetype(GE, 92, index=0); sf = ImageFont.truetype(GE, 38, index=2); tf = ImageFont.truetype(GE, 25, index=5)
        anchor_left = ix + isz + 56          # محاذاة لليسار بعد الأيقونة

    def measure(txt, font):
        b = d.textbbox((0,0), txt, font=font); return b[2]-b[0], b[3]-b[1], b[1]

    bw, bh, boff = measure(brand, bf)
    sw, shh, soff = measure(sub, sf)
    tw, thh, toff = measure(tag, tf)

    gap1, gap2, gap3 = 26, 30, 26
    underline_h = 11
    block_h = bh + gap1 + underline_h + gap2 + shh + gap3 + thh
    top = (H - block_h)//2

    def x_of(width):
        return (anchor_right - width) if lang=="ar" else anchor_left

    # العلامة
    by = top
    d.text((x_of(bw), by - boff), brand, font=bf, fill=(255,255,255,255))
    # الخط الذهبي تحت العلامة
    uy = by + bh + gap1
    ux = x_of(bw)
    d.rounded_rectangle([ux, uy, ux+bw, uy+underline_h], radius=underline_h//2, fill=GOLD+(255,))
    # العنوان الفرعي
    sy = uy + underline_h + gap2
    d.text((x_of(sw), sy - soff), sub, font=sf, fill=(232,244,240,255))
    # الوسم
    ty = sy + shh + gap3
    d.text((x_of(tw), ty - toff), tag, font=tf, fill=(198,224,216,255))

    bg.convert("RGB").save(out_path, "PNG")
    print("✓", os.path.relpath(out_path, HERE))

if __name__=="__main__":
    for lang in ("ar","en"):
        outdir = os.path.join(HERE,"feature_graphic",lang); os.makedirs(outdir, exist_ok=True)
        build(os.path.join(outdir,"feature_graphic_1024x500.png"), lang)
    # نسخة افتراضية في الجذر = العربية
    build(os.path.join(HERE,"feature_graphic","feature_graphic_1024x500.png"), "ar")
