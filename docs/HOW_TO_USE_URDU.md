# Alex AI — استعمال کا طریقہ

## 1) فائلیں تیار کریں
1. اس ZIP کو کھولیں (ZArchiver وغیرہ سے)۔ آپ کو `alex_ai` فولڈر ملے گا۔
2. اس فولڈر میں `lib`، `assets`، `tool`، `pubspec.yaml` اور چھپا ہوا فولڈر `.github` ہے۔ **ان سب کو** GitHub پر جانا ہے۔

## 2) GitHub پر اپ لوڈ (ریپو Private رکھیں)
### Termux سے (آسان، چھپا ہوا `.github` فولڈر بھی چلا جاتا ہے)
```
pkg install git unzip -y
unzip alex_ai_complete.zip
cd alex_ai
git init -b main
git add -A
git commit -m "Alex AI"
git remote add origin https://github.com/آپ_کا_نام/ریپو_کا_نام.git
git push -u origin main
```
(پاس ورڈ کی جگہ GitHub کا Personal Access Token استعمال ہوتا ہے۔)

اگر آپ کی ریپو کی برانچ `master` ہے تو بھی ٹھیک ہے، ورک فلو `main` اور `master` دونوں پر خودکار چلتا ہے۔

## 3) کیز (Secrets) ڈالیں
ریپو میں: Settings ← Secrets and variables ← Actions ← New repository secret

| Secret کا نام | اس میں کیا لکھیں |
|---|---|
| GROQ_KEYS | Groq کی کیز، کاما سے الگ |
| SERP_KEYS | SerpAPI کی کیز |
| TAVILY_KEYS | Tavily کی کیز |
| NEWSDATA_KEYS | NewsData کی کیز |
| WEATHER_KEYS | OpenWeather کی کیز |

مثال: `gsk_aaa,gsk_bbb,gsk_ccc`

Secrets نہ ڈالیں تو بھی ایپ بنے گی، پھر کیز ایپ کی Settings میں خود ڈالنی ہوں گی۔

## 4) APK بنائیں
1. ریپو میں Actions ← "Build Alex AI APK" ← Run workflow (یا پش کرنے پر خود چلتا ہے)۔
2. بلڈ ختم ہو تو نیچے Artifacts میں `Alex-AI-APK` ڈاؤن لوڈ کریں۔
3. یہ ایک ZIP ہوتی ہے، اسے ZArchiver سے کھول کر `app-release.apk` انسٹال کریں۔

## 5) پہلی بار ایپ میں
- نام لکھیں، پھر چیٹ شروع۔
- مائک، لوکیشن، کانٹیکٹس، کال، نوٹیفکیشن کی اجازت ہر فیچر کے پہلے استعمال پر مانگی جاتی ہے۔
- Settings میں: تھیم/رنگ، مائک کی زبان، WhatsApp کنٹری کوڈ، اور ہر پروائیڈر کی کیز (شامل/آن آف/حذف)۔

## 6) اگر بلڈ میں ایرر آئے
GitHub Actions کے ناکام رن میں ایرر کی وہ لائنیں کاپی کریں جہاں `Error:` لکھا ہو (فائل کا نام اور لائن نمبر سمیت) اور Claude یا دوسرے AI کو بھیجیں، ساتھ `AI_HANDOFF_PROMPT.md` بھی۔

## حفاظت
- ریپو Private رکھیں۔
- کیز کوڈ، اسکرین شاٹ یا چیٹ میں پبلک نہ کریں۔
- APK صرف قابلِ اعتماد لوگوں کو دیں (کیز APK کے اندر ہوتی ہیں)۔
