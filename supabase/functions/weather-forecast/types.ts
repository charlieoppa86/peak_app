// 다른 API로 바꿀 때: KmaHourlyWeather는 API 교체 시 필드 변경, RidingRecommendation은 Flutter 모델과 1:1이므로 유지

// 기상청 API 응답 원본 항목
export interface KmaForecastItem {
  baseDate: string;
  baseTime: string;
  category: string;
  fcstDate: string;
  fcstTime: string;
  fcstValue: string;
  nx: number;
  ny: number;
}

// kma_mapper가 생성하는 시간별 날씨 — Gemini 입력용
export interface KmaHourlyWeather {
  time: string;        // "HH:00" (예: "06:00")
  temperature: number; // 기온 (°C)
  skyLabel: string;    // 맑음 / 구름많음 / 흐림
  precipLabel: string; // 없음 / 비 / 비·눈 / 눈 / 소나기
  windSpeed: number;   // 풍속 (m/s)
  windLabel: string;   // 약풍 / 보통 / 강풍 / 매우강풍
}

// Edge Function 최종 출력 — Flutter RidingRecommendation 모델과 1:1
export interface RidingRecommendation {
  weather: string;             // 날씨 요약 (예: "맑음", "구름많고 바람")
  temperature: string;         // 기온 (예: "18°C")
  wind: string;                // 바람 (예: "약풍 (3m/s)")
  recommendedTimeSlot: string; // 추천 시간 구간 (예: "06시~09시")
  recommendation: '추천' | '보통' | '비추천';
  reason: string;              // 한 줄 이유
}

// 에러 응답 구조 — Flutter에서 code로 분기 처리 가능
export interface ErrorResponse {
  code: ErrorCode;
  message: string;
}

export type ErrorCode =
  | 'KMA_TIMEOUT'
  | 'KMA_HTTP_4XX'
  | 'KMA_HTTP_5XX'
  | 'KMA_API_ERROR'
  | 'KMA_EMPTY_RESPONSE'
  | 'GEMINI_ERROR'
  | 'CONFIG_ERROR'
  | 'INTERNAL_ERROR';
