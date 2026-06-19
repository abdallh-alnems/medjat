#!/usr/bin/env python3
"""
يحوّل اللقطات الخام (raw/ar, raw/en) إلى لقطات Google Play مصمّمة (عربي + إنجليزي).
المصدر هنا لقطات iPhone الخام (1320×2868) المُعاد استخدامها — والإطار يحافظ على
نسبة اللقطة دون أي قص.
  screenshots/raw/ar/  -> screenshots/phone/ar/
  screenshots/raw/en/  -> screenshots/phone/en/
ثم: python3 make_screenshots.py   (المخرجات 1080×1920)
أسماء الملفات يجب أن تحوي أحد المفاتيح:
  dashboard / employees / attendance / payroll / more / reports / company / profile
"""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import arabic_reshaper
from bidi.algorithm import get_display

HERE = os.path.dirname(os.path.abspath(__file__))
FB = os.path.join(HERE, "..", "..", "assets", "fonts", "IBMPlexSansArabic-Bold.ttf")
FM = os.path.join(HERE, "..", "..", "assets", "fonts", "IBMPlexSansArabic-Medium.ttf")
# خطوط Geist المرفقة تالفة (مؤشّرات LFS)، لذا نستخدم Avenir Next النظامي للإنجليزية.
GE = "/System/Library/Fonts/Avenir Next.ttc"   # 0=Bold, 5=Medium

W, H = 1080, 1920
C1, C2 = (94,175,155), (25,80,68)
GOLD = (255,214,120)

# key -> (output name, AR title, AR sub, EN title, EN sub)  — نفس عناوين App Store
SLIDES = [
    ("dashboard",  "01_dashboard",  "تابع شركتك في لمحة",   "حضور مباشر وأهم المؤشرات",
                                     "Your company at a glance",      "Live attendance & key metrics"),
    ("employees",  "02_employees",  "أدِر كل موظفيك",       "فروع وأقسام ومستندات",
                                     "Manage all your employees",     "Branches, categories & documents"),
    ("attendance", "03_attendance", "حضور وانصراف دقيق",    "سجلّات وتسجيل يدوي و QR",
                                     "Accurate attendance",           "Records, manual entry & QR"),
    ("payroll",    "04_payroll",    "رواتب وكشوف أجر",      "بدلات وخصومات واعتماد",
                                     "Payroll & payslips",            "Allowances, deductions & approval"),
    ("more",       "05_more",       "كل أدواتك في مكان",    "إجازات · سلف · عُهد · تقارير",
                                     "Every tool in one place",       "Leaves · advances · assets · reports"),
    ("reports",    "06_reports",    "تقارير جاهزة",         "حضور ورواتب وموظفون",
                                     "Ready-made reports",            "Attendance, payroll & employees"),
    ("company",    "07_company",    "تحكّم كامل بإعداداتك",  "تأمينات · فروع · صلاحيات · شِفتات",
                                     "Full control of your setup",    "Insurance · branches · roles · shifts"),
    ("profile",    "08_profile",    "ملف موظف متكامل",      "بيانات ورواتب ومستندات",
                                     "A complete employee profile",   "Details, payroll & documents"),
]

def ar(t): return get_display(arabic_reshaper.reshape(t))

_BG = None
def base_bg():
    global _BG
    if _BG is not None:
        return _BG.copy()
    img = Image.new("RGB",(W,H)); px=img.load(); m=W+H
    for y in range(H):
        for x in range(W):
            t=(x+y)/m
            px[x,y]=tuple(int(C1[i]+(C2[i]-C1[i])*t) for i in range(3))
    img = img.convert("RGBA")
    d = ImageDraw.Draw(img,"RGBA")
    for r in (320,500,720):
        d.ellipse([W-160-r,-240-r,W-160+r,-240+r], outline=(255,255,255,18), width=4)
    _BG = img
    return _BG.copy()

def frame(shot, fh):
    """يحافظ على نسبة اللقطة الأصلية (دون قص) ويبني إطار هاتف بارتفاع fh."""
    radius=80; border=13
    shot = shot.convert("RGB")
    sw, sh = shot.size
    ih = fh-2*border
    iw = int(ih*(sw/sh))          # العرض يتبع نسبة اللقطة → لا قص
    fw = iw+2*border
    shot = shot.resize((iw,ih), Image.LANCZOS).convert("RGBA")
    smask=Image.new("L",(iw,ih),0)
    ImageDraw.Draw(smask).rounded_rectangle([0,0,iw,ih], radius=radius-border, fill=255)
    phone=Image.new("RGBA",(fw,fh),(0,0,0,0))
    fmask=Image.new("L",(fw,fh),0)
    ImageDraw.Draw(fmask).rounded_rectangle([0,0,fw,fh], radius=radius, fill=255)
    black=Image.new("RGBA",(fw,fh),(12,14,18,255))
    phone.paste(black,(0,0),fmask)
    phone.paste(shot,(border,border),smask)
    return phone,fw,fh

def build(out_path, title, sub, raw_path, lang):
    bg=base_bg(); d=ImageDraw.Draw(bg,"RGBA")
    if lang=="ar":
        tf=ImageFont.truetype(FB,72); sf=ImageFont.truetype(FM,40); tt=ar(title); st=ar(sub)
    else:
        tf=ImageFont.truetype(GE,64,index=0); sf=ImageFont.truetype(GE,36,index=5); tt=title; st=sub
    tb=d.textbbox((0,0),tt,font=tf); tw=tb[2]-tb[0]
    d.text(((W-tw)//2,96),tt,font=tf,fill=(255,255,255,255))
    uy=96+(tb[3]-tb[1])+28
    d.rounded_rectangle([(W-tw)//2,uy,(W-tw)//2+tw,uy+10],radius=5,fill=GOLD+(255,))
    sb=d.textbbox((0,0),st,font=sf); sw=sb[2]-sb[0]
    d.text(((W-sw)//2,uy+26),st,font=sf,fill=(225,240,236,255))
    py=350; fh=1470
    phone,fw,fh=frame(Image.open(raw_path), fh)
    px=(W-fw)//2
    sh=Image.new("RGBA",(W,H),(0,0,0,0))
    ImageDraw.Draw(sh).rounded_rectangle([px+12,py+24,px+fw+12,py+fh+24],radius=80,fill=(0,0,0,110))
    sh=sh.filter(ImageFilter.GaussianBlur(28))
    bg=Image.alpha_composite(bg,sh); bg.alpha_composite(phone,(px,py))
    bg.convert("RGB").save(out_path,"PNG")

def run_lang(lang):
    raw=os.path.join(HERE,"screenshots","raw",lang)
    out=os.path.join(HERE,"screenshots","phone",lang); os.makedirs(out,exist_ok=True)
    if not os.path.isdir(raw): print(f"[{lang}] no raw dir"); return
    raws=[r for r in sorted(os.listdir(raw)) if r.lower().endswith((".png",".jpg",".jpeg"))]
    for key,name,at,asub,et,esub in SLIDES:
        m=[r for r in raws if key in r.lower()]
        if not m: print(f"[{lang}] · skip {key}"); continue
        title,sub = (at,asub) if lang=="ar" else (et,esub)
        build(os.path.join(out,name+".png"), title, sub, os.path.join(raw,m[0]), lang)
        print(f"[{lang}] ✓ {name}.png")

if __name__=="__main__":
    for lang in ("ar","en"):
        run_lang(lang)
