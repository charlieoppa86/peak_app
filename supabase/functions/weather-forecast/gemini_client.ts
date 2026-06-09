// 다른 AI로 바꿀 때: GEMINI_URL과 buildBody의 요청 포맷·responseSchema를 해당 모델 API 스펙으로 교체

import type { KmaHourlyWeather, RidingRecommendation } from './types.ts';

const GEMINI_URL =
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

const SYSTEM_PROMPT = `
당신은 로드바이커를 위한 날씨 분석 전문가입니다.
오늘의 시간별 날씨 데이터를 분석해 라이딩 추천 정보를 JSON으로만 반환하세요.

판단 기준:
- 추천: 강수 없음 + 기온 10~25°C + 풍속 5m/s 미만
- 보통: 약한 강수 또는 기온 5~30°C 또는 풍속 5~10m/s
- 비추천: 강수 있음 + 풍속 10m/s 초과 또는 기온 0°C 미만·35°C 초과

recommendedTimeSlot: 연속 2~3시간 중 가장 조건 좋은 구간을 "HH시~HH시" 형식으로.
전일 라이딩 불가 시 recommendedTimeSlot은 "없음"으로 설정.
`.trim();

function buildBody(hourlyData: KmaHourlyWeather[]) {
  return {
    contents: [
      {
        parts: [
          {
            text: `${SYSTEM_PROMPT}\n\n오늘의 시간별 날씨:\n${JSON.stringify(hourlyData, null, 2)}\n\n위 데이터를 분석해 JSON만 반환하세요.`,
          },
        ],
      },
    ],
    generationConfig: {
      responseMimeType: 'application/json',
      responseSchema: {
        type: 'OBJECT',
        properties: {
          weather: { type: 'STRING' },
          temperature: { type: 'STRING' },
          wind: { type: 'STRING' },
          recommendedTimeSlot: { type: 'STRING' },
          recommendation: {
            type: 'STRING',
            enum: ['추천', '보통', '비추천'],
          },
          reason: { type: 'STRING' },
        },
        required: [
          'weather',
          'temperature',
          'wind',
          'recommendedTimeSlot',
          'recommendation',
          'reason',
        ],
      },
    },
  };
}

export async function processWithGemini(
  hourlyData: KmaHourlyWeather[],
  apiKey: string,
): Promise<RidingRecommendation> {
  let res: Response;
  try {
    res = await fetch(`${GEMINI_URL}?key=${apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(buildBody(hourlyData)),
    });
  } catch (e) {
    throw new Error(`GEMINI_ERROR: 네트워크 오류 — ${String(e)}`);
  }

  if (!res.ok) {
    const detail = await res.text().catch(() => '');
    throw new Error(`GEMINI_ERROR: HTTP ${res.status} — ${detail}`);
  }

  const data = await res.json();
  const text: string | undefined =
    data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) throw new Error('GEMINI_ERROR: 빈 응답');

  return JSON.parse(text) as RidingRecommendation;
}
