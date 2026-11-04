<div align="center">
<img width="1200" height="475" alt="GHBanner" src="https://ai.google.dev/static/site-assets/images/share-ais-513315318.png" />
</div>

# Run and deploy your AI Studio app

This contains everything you need to run your app locally.

View your app in AI Studio: https://ai.studio/apps/7c3c690c-95a1-4851-951e-4badcd8a2288

## Run Locally

**Prerequisites:**  Node.js


1. Install dependencies:
   `npm install`
2. Set the `GEMINI_API_KEY` in [.env.local](.env.local) to your Gemini API key
3. Run the app:
   `npm run dev`

## App Flutter: M4 – AI Pronunciation

App Flutter (`lib/`) chấm phát âm trên audio thật bằng Pronunciation API
([LearnEnglish-vs-AI-pronun](https://github.com/tugduong57/LearnEnglish-vs-AI-pronun)),
Gemini chỉ dùng làm dự phòng. Cách chạy và kiến trúc: [`docs/M4_AI_PRONUNCIATION.md`](docs/M4_AI_PRONUNCIATION.md).

```bash
flutter run --dart-define=PRONUN_API_BASE=http://10.0.2.2:8000
```
