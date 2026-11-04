// Audio recording and Web Speech recognition helper

export interface SpeechRecognitionResult {
  transcript: string;
  confidence: number;
}

export class SpeechHelper {
  private static recognition: any = null;

  // Speak target text using Web SpeechSynthesis
  public static speakText(text: string, voiceType: 'US' | 'UK' = 'US', rate = 0.9) {
    if (!('speechSynthesis' in window)) {
      console.warn('Speech synthesis not supported in this browser.');
      return;
    }

    window.speechSynthesis.cancel();
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.rate = rate;
    utterance.pitch = 1.0;

    const voices = window.speechSynthesis.getVoices();
    if (voiceType === 'UK') {
      const ukVoice = voices.find(v => v.lang.includes('en-GB') || v.name.includes('British') || v.name.includes('UK'));
      if (ukVoice) utterance.voice = ukVoice;
      else utterance.lang = 'en-GB';
    } else {
      const usVoice = voices.find(v => v.lang.includes('en-US') || v.name.includes('US') || v.name.includes('American'));
      if (usVoice) utterance.voice = usVoice;
      else utterance.lang = 'en-US';
    }

    window.speechSynthesis.speak(utterance);
  }

  // Check if browser speech recognition is supported
  public static isRecognitionSupported(): boolean {
    return 'webkitSpeechRecognition' in window || 'SpeechRecognition' in window;
  }

  // Create recognition instance
  public static startSpeechRecognition(
    onResult: (transcript: string) => void,
    onError: (err: any) => void,
    onEnd: () => void
  ) {
    const SpeechRecognitionClass = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;
    if (!SpeechRecognitionClass) {
      onError(new Error('Trình duyệt không hỗ trợ Web Speech API.'));
      return null;
    }

    try {
      const rec = new SpeechRecognitionClass();
      rec.continuous = true;
      rec.interimResults = true;
      rec.lang = 'en-US';

      rec.onresult = (event: any) => {
        let finalTranscript = '';
        for (let i = 0; i < event.results.length; i++) {
          finalTranscript += event.results[i][0].transcript + ' ';
        }
        onResult(finalTranscript.trim());
      };

      rec.onerror = (event: any) => {
        onError(event.error);
      };

      rec.onend = () => {
        onEnd();
      };

      rec.start();
      this.recognition = rec;
      return rec;
    } catch (e) {
      onError(e);
      return null;
    }
  }

  public static stopSpeechRecognition() {
    if (this.recognition) {
      try {
        this.recognition.stop();
      } catch (e) {
        // ignore
      }
      this.recognition = null;
    }
  }
}

// MediaRecorder audio capture
export class AudioRecorder {
  private mediaRecorder: MediaRecorder | null = null;
  private audioChunks: Blob[] = [];
  private stream: MediaStream | null = null;

  async start(): Promise<MediaStream> {
    this.audioChunks = [];
    this.stream = await navigator.mediaDevices.getUserMedia({
      audio: {
        echoCancellation: true,
        noiseSuppression: true,
        autoGainControl: true
      }
    });

    const mimeType = MediaRecorder.isTypeSupported('audio/webm;codecs=opus')
      ? 'audio/webm;codecs=opus'
      : MediaRecorder.isTypeSupported('audio/webm')
      ? 'audio/webm'
      : 'audio/ogg';

    this.mediaRecorder = new MediaRecorder(this.stream, { mimeType });
    this.mediaRecorder.ondataavailable = (event) => {
      if (event.data && event.data.size > 0) {
        this.audioChunks.push(event.data);
      }
    };

    this.mediaRecorder.start(100);
    return this.stream;
  }

  async stop(): Promise<{ blob: Blob; base64: string; url: string; mimeType: string }> {
    return new Promise((resolve, reject) => {
      if (!this.mediaRecorder) {
        return reject(new Error('Recorder not started'));
      }

      this.mediaRecorder.onstop = async () => {
        const mimeType = this.mediaRecorder?.mimeType || 'audio/webm';
        const audioBlob = new Blob(this.audioChunks, { type: mimeType });
        const audioUrl = URL.createObjectURL(audioBlob);

        // Convert to base64
        const reader = new FileReader();
        reader.onloadend = () => {
          const base64String = reader.result as string;
          this.cleanup();
          resolve({
            blob: audioBlob,
            base64: base64String,
            url: audioUrl,
            mimeType
          });
        };
        reader.onerror = () => {
          this.cleanup();
          reject(new Error('Failed to convert audio to base64'));
        };
        reader.readAsDataURL(audioBlob);
      };

      this.mediaRecorder.stop();
    });
  }

  cleanup() {
    if (this.stream) {
      this.stream.getTracks().forEach((track) => track.stop());
      this.stream = null;
    }
    this.mediaRecorder = null;
  }
}
