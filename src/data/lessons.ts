import { LessonSentence } from '../types';

export const LESSON_CATEGORIES = [
  { id: 'All', label: 'Tất cả bài học', icon: 'Sparkles' },
  { id: 'Daily', label: 'Giao tiếp hằng ngày', icon: 'MessageCircle' },
  { id: 'TongueTwister', label: 'Luyện âm & Lẹo lưỡi', icon: 'Flame' },
  { id: 'IELTS', label: 'Luyện thi IELTS Speaking', icon: 'GraduationCap' },
  { id: 'Business', label: 'Tiếng Anh Công sở', icon: 'Briefcase' },
  { id: 'JobInterview', label: 'Phỏng vấn Xin việc', icon: 'UserCheck' },
  { id: 'Academic', label: 'Thuyết trình Học thuật', icon: 'BookOpen' }
];

export const LESSON_SENTENCES: LessonSentence[] = [
  {
    id: 's1',
    text: 'She sells seashells by the seashore.',
    translation: 'Cô ấy bán vỏ sò bên bờ biển.',
    ipa: '/ʃiː sɛlz ˈsiːˌʃɛlz baɪ ðə ˈsiːˌʃɔːr/',
    category: 'TongueTwister',
    difficulty: 'Intermediate',
    focusSound: '/ʃ/ vs /s/',
    tips: 'Âm /ʃ/ cần chu môi tròn và đẩy luồng hơi dày; âm /s/ thì khóe miệng kéo ngang như cười, đẩy hơi xì qua kẽ răng.'
  },
  {
    id: 's2',
    text: 'I think that this is the best solution for our team.',
    translation: 'Tôi nghĩ rằng đây là giải pháp tốt nhất cho đội ngũ của chúng ta.',
    ipa: '/aɪ θɪŋk ðæt ðɪs ɪz ðə bɛst səˈluːʃən fɔːr ˈaʊər tiːm/',
    category: 'Daily',
    difficulty: 'Beginner',
    focusSound: '/θ/ & /ð/',
    tips: 'Đặt đầu lưỡi nhẹ nhàng giữa hai hàm răng khi phát âm "think" /θ/ (vô thanh) và "that/this" /ð/ (hữu thanh).'
  },
  {
    id: 's3',
    text: 'Working in a comfortable environment increases productivity significantly.',
    translation: 'Làm việc trong một môi trường thoải mái giúp gia tăng năng suất đáng kể.',
    ipa: '/ˈwɜːrkɪŋ ɪn ə ˈkʌmftərbəl ɪnˈvaɪrənmənt ɪnˈkriːsɪz ˌproʊdʌkˈtɪvəti sɪɡˈnɪfɪkəntli/',
    category: 'Business',
    difficulty: 'Advanced',
    focusSound: 'Trọng âm & Nuốt âm',
    tips: '"Comfortable" chỉ có 3 âm tiết /ˈkʌmftərbəl/, không phát âm là "com-for-ta-ble".'
  },
  {
    id: 's4',
    text: 'Could you please send me the updated project schedule by tomorrow morning?',
    translation: 'Bạn có thể vui lòng gửi cho tôi lịch trình dự án đã cập nhật trước sáng mai không?',
    ipa: '/kʊd juː pliːz sɛnd miː ðiː ʌpˈdeɪtɪd ˈprɒdʒɛkt ˈskɛdʒuːl baɪ təˈmɒroʊ ˈmɔːrnɪŋ/',
    category: 'Business',
    difficulty: 'Intermediate',
    focusSound: 'Âm nối & /dʒ/',
    tips: 'Chú ý âm đuôi /z/ ở "please", /d/ ở "send", và âm /dʒ/ tròn môi ở "schedule".'
  },
  {
    id: 's5',
    text: 'Technological advancements have thoroughly transformed modern education.',
    translation: 'Những tiến bộ công nghệ đã làm biến đổi hoàn toàn nền giáo dục hiện đại.',
    ipa: '/ˌtɛknəˈlɑːdʒɪkəl ədˈvænsmənts hæv ˈθɜːroʊli trænsˈfɔːrmd ˈmɑːdərn ˌɛdʒʊˈkeɪʃən/',
    category: 'IELTS',
    difficulty: 'Advanced',
    focusSound: '/θ/ & Cụm phụ âm cuối',
    tips: '"Thoroughly" bắt đầu bằng âm /θ/ vô thanh, chú ý trọng âm rơi vào âm tiết đầu tiên.'
  },
  {
    id: 's6',
    text: 'Practice makes perfect if you persevere every single day.',
    translation: 'Luyện tập tạo nên sự hoàn hảo nếu bạn kiên trì mỗi ngày.',
    ipa: '/ˈpræktɪs meɪks ˈpɜːrfɪkt ɪf juː ˌpɜːrsəˈvɪər ˈɛvri ˈsɪŋɡəl deɪ/',
    category: 'Daily',
    difficulty: 'Beginner',
    focusSound: 'Âm đuôi /s/ & /ks/',
    tips: 'Đừng quên âm đuôi /s/ ở "practice" và cụm /ks/ ở "makes". Người Việt hay nuốt phụ âm này.'
  },
  {
    id: 's7',
    text: 'I have three years of experience developing cross-platform mobile applications.',
    translation: 'Tôi có ba năm kinh nghiệm phát triển các ứng dụng di động đa nền tảng.',
    ipa: '/aɪ hæv θriː jɪərz əv ɪkˈspɪəriəns dɪˈvɛləpɪŋ krɒs ˈplætfɔːrm ˈmoʊbəl ˌæplɪˈkeɪʃənz/',
    category: 'JobInterview',
    difficulty: 'Intermediate',
    focusSound: '/θ/ & /v/',
    tips: '"Three" có âm /θ/ theo sau là /r/. "Have" cần chạm nhẹ răng trên vào môi dưới cho âm /v/.'
  },
  {
    id: 's8',
    text: 'Red lorry, yellow lorry, red lorry, yellow lorry.',
    translation: 'Xe tải đỏ, xe tải vàng, xe tải đỏ, xe tải vàng (câu luyện phát âm kinh điển).',
    ipa: '/rɛd ˈlɒri ˈjɛloʊ ˈlɒri rɛd ˈlɒri ˈjɛloʊ ˈlɒri/',
    category: 'TongueTwister',
    difficulty: 'Advanced',
    focusSound: '/l/ vs /r/',
    tips: 'Phân biệt rõ: Âm /l/ đầu lưỡi chạm chân răng trên; âm /r/ đầu lưỡi cuộn sâu vào vòm họng không chạm răng.'
  },
  {
    id: 's9',
    text: 'Global warming represents a critical threat to biodiversity across the planet.',
    translation: 'Sự nóng lên toàn cầu là một mối đe dọa nghiêm trọng đối với đa dạng sinh học.',
    ipa: '/ˈɡloʊbəl ˈwɔːrmɪŋ ˌrɛprɪˈzɛnts ə ˈkrɪtɪkəl θrɛt tuː ˌbaɪoʊdaɪˈvɜːrsəti əˈkrɒs ðə ˈplænɪt/',
    category: 'Academic',
    difficulty: 'Advanced',
    focusSound: 'Ngữ điệu học thuật & Trọng âm',
    tips: 'Ngắt nhịp tự nhiên sau "threat" và hạ giọng ở cuối câu khẳng định.'
  },
  {
    id: 's10',
    text: 'Would you mind introducing yourself and sharing your strengths with us?',
    translation: 'Bạn có phiền tự giới thiệu bản thân và chia sẻ điểm mạnh của mình với chúng tôi không?',
    ipa: '/wʊd juː maɪnd ˌɪntrəˈduːsɪŋ jʊərˈsɛlf ænd ˈʃɛərɪŋ jɔːr strɛŋkθs wɪð ʌs/',
    category: 'JobInterview',
    difficulty: 'Intermediate',
    focusSound: 'Nối âm "Would you" /wʊdʒuː/',
    tips: 'Hiện tượng đồng hóa âm: "Would you" nối thành /wʊdʒuː/. Chú ý âm đuôi phức tạp /ŋkθs/ ở "strengths".'
  }
];

export const COMMON_PHONEMES_GUIDE = [
  {
    symbol: '/θ/',
    example: 'think, thank, tooth',
    name: 'Voiceless dental fricative',
    guide: 'Đầu lưỡi đặt giữa 2 hàm răng, đẩy luồng hơi xì qua khe hở mà không rung thanh quản.'
  },
  {
    symbol: '/ð/',
    example: 'this, that, mother',
    name: 'Voiced dental fricative',
    guide: 'Vị trí lưỡi tương tự /θ/ nhưng cổ họng phải rung dây thanh quản rõ ràng.'
  },
  {
    symbol: '/ʃ/',
    example: 'she, shoe, national',
    name: 'Voiceless postalveolar fricative',
    guide: 'Chu môi tròn về phía trước, thân lưỡi nâng lên vòm họng cứng và đẩy hơi mạnh.'
  },
  {
    symbol: '/s/',
    example: 'see, ice, practice',
    name: 'Voiceless alveolar fricative',
    guide: 'Hai hàm răng khép hờ, mép kéo nhẹ sang 2 bên, luồng hơi lướt nhẹ qua đầu lưỡi.'
  },
  {
    symbol: '/dʒ/',
    example: 'job, judge, bridge',
    name: 'Voiced postalveolar affricate',
    guide: 'Chu môi nhẹ, đầu lưỡi bật khỏi vòm họng đồng thời rung dây thanh quản.'
  },
  {
    symbol: '/tʃ/',
    example: 'chair, match, future',
    name: 'Voiceless postalveolar affricate',
    guide: 'Khẩu hình giống /dʒ/ nhưng không rung dây thanh, bật hơi dứt khoát như tiếng "ch" mạnh.'
  }
];
