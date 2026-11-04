import express from 'express';
import { createServer as createViteServer } from 'vite';
import path from 'path';
import dotenv from 'dotenv';
import { GoogleGenAI } from '@google/genai';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;
const isProd = process.env.NODE_ENV === 'production';

app.use(express.json({ limit: '15mb' }));

const rawApiKey = process.env.GEMINI_API_KEY || '';
const apiKey = (rawApiKey && rawApiKey !== 'MY_GEMINI_API_KEY') ? rawApiKey : '';
const ai = apiKey ? new GoogleGenAI({ apiKey }) : null;

// Built-in intelligent phonetic fallback engine if Gemini is not reachable
function fallbackPhoneticAnalysis(targetText: string, spokenText: string) {
  const targetWords = targetText.trim().split(/\s+/);
  const spokenWords = (spokenText || '').trim().split(/\s+/);
  
  // Basic mock IPA mappings for common words
  const sampleIpaMap: Record<string, string> = {
    'hello': 'həˈloʊ',
    'world': 'wɜːrld',
    'english': 'ˈɪŋɡlɪʃ',
    'pronunciation': 'prəˌnʌnsiˈeɪʃən',
    'comfortable': 'ˈkʌmftərbəl',
    'schedule': 'ˈskɛdʒuːl',
    'thoroughly': 'ˈθɜːroʊli',
    'vocabulary': 'voʊˈkæbjəˌlɛri',
    'practice': 'ˈpræktɪs',
    'makes': 'meɪks',
    'perfect': 'ˈpɜːrfɪkt',
    'she': 'ʃiː',
    'sells': 'sɛlz',
    'seashells': 'ˈsiːʃɛlz',
    'by': 'baɪ',
    'the': 'ðə',
    'seashore': 'ˈsiːʃɔːr',
    'opportunity': 'ˌɑːpərˈtuːnəti',
    'development': 'dɪˈvɛləpmənt',
    'student': 'ˈstuːdənt',
    'university': 'ˌjuːnɪˈvɜːrsəti'
  };

  let totalWordScore = 0;
  const wordAnalysis = targetWords.map((tWord, index) => {
    const cleanT = tWord.replace(/[^a-zA-Z]/g, '').toLowerCase();
    const cleanS = (spokenWords[index] || '').replace(/[^a-zA-Z]/g, '').toLowerCase();
    
    let score = 95;
    let status: 'correct' | 'warning' | 'incorrect' = 'correct';
    let errorType = 'none';
    let specificError = 'Phát âm chuẩn xác';

    if (!cleanS) {
      score = 25;
      status = 'incorrect';
      errorType = 'omitted';
      specificError = 'Chưa nghe thấy từ này, hãy phát âm to và rõ hơn';
    } else if (cleanT !== cleanS) {
      if (cleanT.length > 3 && cleanT.slice(0, -1) === cleanS) {
        score = 65;
        status = 'warning';
        errorType = 'missing_ending_sound';
        specificError = `Thiếu âm đuôi /${cleanT.slice(-1)}/`;
      } else {
        score = 45;
        status = 'incorrect';
        errorType = 'sound_distortion';
        specificError = `Phát âm thành "${cleanS}", cần chú ý nguyên âm và phụ âm`;
      }
    }

    totalWordScore += score;
    const expectedIpa = sampleIpaMap[cleanT] || `/${cleanT}/`;
    
    return {
      word: tWord,
      expectedIpa,
      detectedIpa: status === 'correct' ? expectedIpa : `/${cleanS || '...'}/`,
      score,
      status,
      errorType,
      phonemes: expectedIpa.replace(/\//g, '').split('').map(p => ({
        symbol: p,
        status: status === 'incorrect' && Math.random() > 0.5 ? 'incorrect' : status === 'warning' ? 'warning' : 'correct',
        tip: p === 'θ' ? 'Đặt lưỡi giữa hai răng' : p === 's' ? 'Răng khép nhẹ, đẩy hơi xì' : undefined
      })),
      specificError
    };
  });

  const overall = Math.round(totalWordScore / Math.max(1, targetWords.length));
  
  return {
    overallScore: Math.min(100, Math.max(20, overall)),
    accuracyScore: Math.min(100, Math.max(15, overall - 2)),
    fluencyScore: Math.min(100, Math.max(25, overall + 3)),
    completenessScore: Math.min(100, Math.max(30, Math.round((spokenWords.length / targetWords.length) * 100))),
    expectedIpa: wordAnalysis.map(w => w.expectedIpa).join(' '),
    wordAnalysis,
    vietnameseSummary: overall >= 85 
      ? 'Tuyệt vời! Phát âm của bạn rất tự nhiên, âm vị rõ ràng và ngữ điệu chuẩn.' 
      : overall >= 70 
      ? 'Khá tốt! Bạn đã phát âm đúng phần lớn các từ, cần chú ý thêm âm đuôi (ending sounds) và trọng âm.' 
      : 'Cần luyện tập thêm! Một số từ bị nuốt âm đuôi hoặc sai khẩu hình. Hãy nghe lại âm mẫu và thử lại nhé.',
    tongueMouthAdvice: 'Chú ý thả lỏng cơ hàm, mở rộng khẩu hình khi phát âm nguyên âm dài và đặt đầu lưỡi đúng vị trí cho phụ âm xát.',
    recommendedDrills: [
      `Luyện tập chậm từng từ: ${targetWords.slice(0, 2).join(', ')}`,
      'Tập thổi luồng hơi nhẹ cho các phụ âm cuối',
      'Đọc theo phương pháp Shadowing với audio chuẩn'
    ]
  };
}

// POST /api/analyze-pronunciation
app.post('/api/analyze-pronunciation', async (req, res) => {
  try {
    const { targetText, userSpokenText, audioBase64, mimeType = 'audio/webm', category, difficulty } = req.body;

    if (!targetText) {
      return res.status(400).json({ error: 'targetText is required' });
    }

    if (!ai) {
      // Fallback if no API key provided
      const fallbackResult = fallbackPhoneticAnalysis(targetText, userSpokenText || '');
      return res.json({ ...fallbackResult, engine: 'phonetic-rule-engine' });
    }

    const systemInstruction = `
You are an expert English Phonetician, Speech-Language Pathologist, and Pronunciation Coach specialized in helping Vietnamese students achieve native-like American/British English pronunciation.
Your task is to analyze the user's spoken audio or recognized text against the target text: "${targetText}".
Target text: "${targetText}"
Recognized transcript: "${userSpokenText || 'No transcript text available'}"
Category: "${category || 'General'}"
Difficulty: "${difficulty || 'Intermediate'}"

Analyze:
1. Overall pronunciation quality, phoneme accuracy (IPA), fluency, completeness.
2. Word-by-word evaluation: identify correct sounds, missed ending sounds (e.g., omitting final /s/, /t/, /d/, /ks/), incorrect vowels (e.g., confusing /iː/ and /ɪ/, /e/ and /æ/), stress mistakes, and interdental sounds like /θ/ vs /t/, /ð/ vs /d/.
3. Specific mouth & tongue placement instructions (Khẩu hình miệng & vị trí đặt lưỡi) in Vietnamese to help the learner correct their pronunciation.
4. Specific recommendations for follow-up drills.

Output strictly valid JSON with this exact schema:
{
  "overallScore": number (0-100),
  "accuracyScore": number (0-100),
  "fluencyScore": number (0-100),
  "completenessScore": number (0-100),
  "expectedIpa": string (standard IPA of target sentence),
  "detectedIpa": string (approximate IPA of what user spoke),
  "vietnameseSummary": string (encouraging and precise feedback in Vietnamese, 2-3 sentences),
  "tongueMouthAdvice": string (concrete guidance on tongue, lips, and airflow in Vietnamese),
  "wordAnalysis": [
    {
      "word": string,
      "expectedIpa": string,
      "detectedIpa": string,
      "score": number (0-100),
      "status": "correct" | "warning" | "incorrect",
      "errorType": "none" | "missing_ending_sound" | "vowel_distortion" | "consonant_substitution" | "stress_error" | "omitted",
      "phonemes": [
        {
          "symbol": string,
          "status": "correct" | "warning" | "incorrect",
          "tip": string (optional short tip in Vietnamese)
        }
      ],
      "specificError": string (concise explanation in Vietnamese)
    }
  ],
  "recommendedDrills": [
    string (specific drill 1 in Vietnamese),
    string (specific drill 2 in Vietnamese),
    string (specific drill 3 in Vietnamese)
  ]
}
`;

    const contents: any[] = [];
    if (audioBase64) {
      contents.push({
        inlineData: {
          mimeType: mimeType.split(';')[0] || 'audio/webm',
          data: audioBase64.replace(/^data:[^;]+;base64,/, '')
        }
      });
    }
    contents.push({
      text: `Please evaluate user's pronunciation for the target sentence: "${targetText}". Speech transcript received: "${userSpokenText || 'None'}". Provide accurate phonetic scores, phoneme breakdown, and Vietnamese coaching guidance.`
    });

    const timeoutPromise = new Promise((_, reject) =>
      setTimeout(() => reject(new Error('AI generation timed out')), 7000)
    );

    const generatePromise = ai.models.generateContent({
      model: 'gemini-3.8-flash',
      contents: contents,
      config: {
        systemInstruction,
        responseMimeType: 'application/json',
        temperature: 0.2
      }
    });

    const response: any = await Promise.race([generatePromise, timeoutPromise]);

    if (response.text) {
      const parsed = JSON.parse(response.text);
      return res.json({ ...parsed, engine: 'gemini-3.8-flash' });
    } else {
      const fallback = fallbackPhoneticAnalysis(targetText, userSpokenText || '');
      return res.json({ ...fallback, engine: 'fallback' });
    }
  } catch (error: any) {
    console.error('Error analyzing pronunciation with Gemini:', error?.message || error);
    // On any API error, provide graceful phonetic fallback
    const fallback = fallbackPhoneticAnalysis(req.body.targetText || '', req.body.userSpokenText || '');
    return res.json({ ...fallback, engine: 'phonetic-fallback-engine', notice: 'Analyzed with local phonetic engine' });
  }
});

// GET /api/test-accent-samples
// Endpoint providing multi-speaker benchmark samples for testing
app.get('/api/test-accent-samples', (req, res) => {
  const samples = [
    {
      id: 'speaker_us_native',
      name: 'John D. (Native US - Standard American)',
      accent: 'American (Native)',
      targetText: 'She sells seashells by the seashore.',
      simulatedSpokenText: 'She sells seashells by the seashore.',
      expectedScore: 98,
      notes: 'Phát âm chuẩn xác cả âm /ʃ/ và /s/, ngữ điệu mượt mà.'
    },
    {
      id: 'speaker_uk_native',
      name: 'Emma W. (Native UK - Received Pronunciation)',
      accent: 'British (Native)',
      targetText: 'Practice makes perfect in every opportunity.',
      simulatedSpokenText: 'Practice makes perfect in every opportunity.',
      expectedScore: 96,
      notes: 'Trọng âm chính xác, không nhả âm r cuối (non-rhotic).'
    },
    {
      id: 'speaker_vn_beginner',
      name: 'Minh T. (Vietnamese Learner - Beginner)',
      accent: 'Vietnamese English (Beginner)',
      targetText: 'She sells seashells by the seashore.',
      simulatedSpokenText: 'She sell seashow by the seashow.',
      expectedScore: 58,
      notes: 'Thường nhầm âm /ʃ/ với /s/, thiếu âm đuôi /z/ ở "sells".'
    },
    {
      id: 'speaker_vn_intermediate',
      name: 'Lan Anh (Vietnamese Learner - Intermediate)',
      accent: 'Vietnamese English (Intermediate)',
      targetText: 'Comfortable schedule for university students.',
      simulatedSpokenText: 'Comfotable schedule for university student.',
      expectedScore: 78,
      notes: 'Từ "comfortable" đọc 4 âm tiết thay vì 3 âm tiết /ˈkʌmftərbəl/, thiếu đuôi /s/ ở "students".'
    }
  ];

  res.json({ samples });
});

async function startServer() {
  if (!isProd) {
    const vite = await createViteServer({
      server: { middlewareMode: true },
      appType: 'spa'
    });
    app.use(vite.middlewares);
  } else {
    const distPath = path.resolve(__dirname, 'dist');
    app.use(express.static(distPath));
    app.get('*', (req, res) => {
      res.sendFile(path.resolve(distPath, 'index.html'));
    });
  }

  app.listen(PORT, () => {
    console.log(`Server running at http://localhost:${PORT}`);
  });
}

startServer();
