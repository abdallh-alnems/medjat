#!/usr/bin/env python3
"""
يحوّل لقطات Android الخام (1080×1920) إلى لقطات Google Play مصمّمة (عربي + إنجليزي).
ضع اللقطات في:
  screenshots/raw/ar/   (واجهة عربية)   -> screenshots/phone/ar/
  screenshots/raw/en/   (واجهة إنجليزية) -> screenshots/phone/en/
ثم: python3 make_screenshots.py
أسماء الملفات يجب أن تحوي أحد المفاتيح:
  attendance / profile / salary / leave / documents / advance / assets / settings
"""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import arabic_reshaper
from bidi.algorithm import get_display

HERE = os.path.dirname(os.path.abspath(__file__))
FB   = os.path.join(HERE, "..", "..", "assets", "fonts", "IBMPlexSansArabic-Bold.ttf")
FM   = os.path.join(HERE, "..", "..", "assets", "fonts", "IBMPlexSansArabic-Medium.ttf")
# خطوط Geist المرفقة تالفة (مؤشّرات LFS)، لذا نستخدم Avenir Next النظامي للإنجليزية.
GE   = "/System/Library/Fonts/Avenir Next.ttc"   # 0=Bold, 5=Medium

W, H = 1080, 1920
C1, C2 = (94,175,155), (25,80,68)
GOLD = (255,214,120)

# key -> (output name, AR title, AR sub, EN title, EN sub)  — نفس ترتيب لقطات App Store
SLIDES = [
    ("attendance", "01_attendance", "سجّل حضورك بنقرة",     "بالموقع أو رمز QR",
                                     "Clock in with one tap",         "By location or QR code"),
    ("profile",    "02_profile",    "ملفك الوظيفي",         "بياناتك ورصيد إجازاتك",
                                     "Your work profile",             "Your data & leave balance"),
    ("salary",     "03_salary",     "راتبك وكشف الأجر",     "تفاصيل واستحقاقات وخصومات",
                                     "Your salary & payslip",         "Earnings, allowances & deductions"),
    ("leave",      "04_leave",      "اطلب إجازتك بسهولة",   "وتابع رصيدك وحالة طلبك",
                                     "Request leave easily",          "Track your balance & status"),
    ("documents",  "05_documents",  "مستنداتك في مكان",     "ارفعها واطّلع عليها أي وقت",
                                     "All your documents",            "Upload and access anytime"),
    ("advance",    "06_advance",    "اطلب سلفة على راتبك",  "وتابع موافقة الإدارة",
                                     "Request a salary advance",      "Follow your manager's approval"),
    ("assets",     "07_assets",     "عُهدك ومستلزماتك",     "ما استلمته من الشركة",
                                     "Your assigned assets",          "Items handed to you by work"),
    ("settings",   "08_settings",   "إشعارات وإعدادات",     "تنبيهات فورية وتحكّم كامل",
                                     "Notifications & settings",      "Instant alerts & full control"),
]

def ar(t): return get_display(arabic_reshaper.reshape(t))

_BG = None
def base_bg():
    """تدرّج الخلفية مع الدوائر — يُحسب مرة واحدة ويُعاد استخدامه."""
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

def frame(shot):
    fh=1360; radius=90; border=14
    ih = fh-2*border
    iw = int(ih*(W/H))            # 9:16 — نفس نسبة اللقطة فلا يحدث أي قص
    fw = iw+2*border
    shot = shot.convert("RGB")
    target=iw/ih; sw,sh=shot.size
    if sw/sh>target:
        nw=int(sh*target); shot=shot.crop(((sw-nw)//2,0,(sw-nw)//2+nw,sh))
    else:
        nh=int(sw/target); shot=shot.crop((0,0,sw,nh))
    shot=shot.resize((iw,ih), Image.LANCZOS).convert("RGBA")
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
    d.text(((W-tw)//2,100),tt,font=tf,fill=(255,255,255,255))
    uy=100+(tb[3]-tb[1])+30
    d.rounded_rectangle([(W-tw)//2,uy,(W-tw)//2+tw,uy+10],radius=5,fill=GOLD+(255,))
    sb=d.textbbox((0,0),st,font=sf); sw=sb[2]-sb[0]
    d.text(((W-sw)//2,uy+28),st,font=sf,fill=(225,240,236,255))
    phone,fw,fh=frame(Image.open(raw_path))
    px=(W-fw)//2; py=346
    sh=Image.new("RGBA",(W,H),(0,0,0,0))
    ImageDraw.Draw(sh).rounded_rectangle([px+12,py+24,px+fw+12,py+fh+24],radius=90,fill=(0,0,0,110))
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
