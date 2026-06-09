// ─── Types ────────────────────────────────────────────────────────────────────

interface KmaForecastItem {
  baseDate: string;
  baseTime: string;
  category: string;
  fcstDate: string;
  fcstTime: string;
  fcstValue: string;
  nx: number;
  ny: number;
}

interface KmaHourlyWeather {
  time: string;
  temperature: number;
  skyLabel: string;
  precipLabel: string;
  windSpeed: number;
  windLabel: string;
}

interface RidingRecommendation {
  weather: string;
  temperature: string;
  wind: string;
  recommendedTimeSlot: string;
  recommendation: '추천' | '보통' | '비추천';
  reason: string;
}

type ErrorCode =
  | 'KMA_TIMEOUT'
  | 'KMA_HTTP_4XX'
  | 'KMA_HTTP_5XX'
  | 'KMA_API_ERROR'
  | 'KMA_EMPTY_RESPONSE'
  | 'GEMINI_ERROR'
  | 'CONFIG_ERROR'
  | 'INTERNAL_ERROR';

// ─── Coordinate (다른 API로 바꿀 때: Open-Meteo 등은 이 함수 불필요) ────────

function latLngToGrid(lat: number, lng: number): { nx: number; ny: number } {
  const RE = 6371.00877;
  const GRID = 5.0;
  const DEGRAD = Math.PI / 180;
  const slat1 = 30.0 * DEGRAD;
  const slat2 = 60.0 * DEGRAD;
  const olon = 126.0 * DEGRAD;
  const olat = 38.0 * DEGRAD;
  const xo = 43.0;
  const yo = 136.0;
  const re = RE / GRID;
  const sn =
    Math.log(Math.cos(slat1) / Math.cos(slat2)) /
    Math.log(
      Math.tan(Math.PI * 0.25 + slat2 * 0.5) /
        Math.tan(Math.PI * 0.25 + slat1 * 0.5),
    );
  const sf =
    (Math.pow(Math.tan(Math.PI * 0.25 + slat1 * 0.5), sn) * Math.cos(slat1)) / sn;
  const ro = (re * sf) / Math.pow(Math.tan(Math.PI * 0.25 + olat * 0.5), sn);
  const ra = (re * sf) / Math.pow(Math.tan(Math.PI * 0.25 + lat * DEGRAD * 0.5), sn);
  let theta = lng * DEGRAD - olon;
  if (theta > Math.PI) theta -= 2 * Math.PI;
  if (theta < -Math.PI) theta += 2 * Math.PI;
  theta *= sn;
  return {
    nx: Math.floor(ra * Math.sin(theta) + xo + 0.5),
    ny: Math.floor(ro - ra * Math.cos(theta) + yo + 0.5),
  };
}

// ─── KMA Client (다른 API로 바꿀 때: 이 함수 전체 교체) ──────────────────────

const KMA_URL =
  'https://apihub.kma.go.kr/api/typ02/openApi/VilageFcstInfoService_2.0/getVilageFcst';
const TIMEOUT_MS = 10_000;

class KmaError extends Error {
  code: ErrorCode;
  constructor(code: ErrorCode, message: string) {
    super(message);
    this.code = code;
    this.name = 'KmaError';
  }
}

async function fetchKmaForecast(opts: {
  serviceKey: string;
  nx: number;
  ny: number;
  baseDate: string;
  baseTime: string;
}): Promise<KmaForecastItem[]> {
  const params = new URLSearchParams({
    pageNo: '1',
    numOfRows: '1000',
    dataType: 'JSON',
    base_date: opts.baseDate,
    base_time: opts.baseTime,
    nx: String(opts.nx),
    ny: String(opts.ny),
    authKey: opts.serviceKey,
  });
  const url = `${KMA_URL}?${params}`;

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);

  let res: Response;
  try {
    res = await fetch(url, { signal: controller.signal });
  } catch (e) {
    if (e instanceof Error && e.name === 'AbortError') {
      throw new KmaError('KMA_TIMEOUT', '기상청 API가 10초 내에 응답하지 않았습니다');
    }
    throw new KmaError('INTERNAL_ERROR', `네트워크 오류: ${String(e)}`);
  } finally {
    clearTimeout(timer);
  }

  if (res.status >= 400 && res.status < 500) {
    throw new KmaError('KMA_HTTP_4XX', `기상청 API 클라이언트 오류: HTTP ${res.status}`);
  }
  if (res.status >= 500) {
    throw new KmaError('KMA_HTTP_5XX', `기상청 API 서버 오류: HTTP ${res.status}`);
  }

  const json = await res.json();
  const header = json?.response?.header;
  if (header?.resultCode !== '00') {
    throw new KmaError(
      'KMA_API_ERROR',
      `기상청 API 오류 [${header?.resultCode}]: ${header?.resultMsg ?? '알 수 없음'}`,
    );
  }

  const items: unknown = json?.response?.body?.items?.item;
  if (!Array.isArray(items) || items.length === 0) {
    throw new KmaError('KMA_EMPTY_RESPONSE', '기상청 예보 데이터가 없습니다');
  }
  return items as KmaForecastItem[];
}

function getBaseDateTime(now: Date): { baseDate: string; baseTime: string } {
  const kstMs = now.getTime() + 9 * 60 * 60 * 1000;
  const kst = new Date(kstMs);
  const kstMinutes = kst.getUTCHours() * 60 + kst.getUTCMinutes();
  const slots = [120, 300, 480, 660, 840, 1020, 1200, 1380];
  const valid = slots.filter((m) => m <= kstMinutes - 30);
  if (valid.length > 0) {
    const t = valid[valid.length - 1];
    const h = String(Math.floor(t / 60)).padStart(2, '0');
    const m = String(t % 60).padStart(2, '0');
    return {
      baseDate: kst.toISOString().slice(0, 10).replace(/-/g, ''),
      baseTime: `${h}${m}`,
    };
  }
  const prevDay = new Date(kstMs - 24 * 60 * 60 * 1000);
  return {
    baseDate: prevDay.toISOString().slice(0, 10).replace(/-/g, ''),
    baseTime: '2300',
  };
}

// ─── KMA Mapper (다른 API로 바꿀 때: 카테고리 코드와 레이블 함수 교체) ────────

function skyLabel(val: string): string {
  return ({ '1': '맑음', '3': '구름많음', '4': '흐림' } as Record<string, string>)[val] ?? '알 수 없음';
}
function precipLabel(val: string): string {
  return (
    ({ '0': '없음', '1': '비', '2': '비·눈', '3': '눈', '4': '소나기' } as Record<string, string>)[val] ?? '알 수 없음'
  );
}
function windLabel(mps: number): string {
  if (mps < 3) return '약풍';
  if (mps < 8) return '보통';
  if (mps < 14) return '강풍';
  return '매우강풍';
}

function mapTodayHourly(items: KmaForecastItem[], todayKst: string): KmaHourlyWeather[] {
  const todayItems = items.filter((i) => i.fcstDate === todayKst);
  const byTime = new Map<string, Map<string, string>>();
  for (const item of todayItems) {
    if (!byTime.has(item.fcstTime)) byTime.set(item.fcstTime, new Map());
    byTime.get(item.fcstTime)!.set(item.category, item.fcstValue);
  }
  const result: KmaHourlyWeather[] = [];
  for (const [fcstTime, cats] of byTime) {
    const tmp = parseFloat(cats.get('TMP') ?? '');
    const wsd = parseFloat(cats.get('WSD') ?? '');
    if (isNaN(tmp) || isNaN(wsd)) continue;
    result.push({
      time: `${fcstTime.slice(0, 2)}:00`,
      temperature: Math.round(tmp),
      skyLabel: skyLabel(cats.get('SKY') ?? ''),
      precipLabel: precipLabel(cats.get('PTY') ?? '0'),
      windSpeed: Math.round(wsd * 10) / 10,
      windLabel: windLabel(wsd),
    });
  }
  return result.sort((a, b) => a.time.localeCompare(b.time));
}

function todayKst(now: Date): string {
  const kst = new Date(now.getTime() + 9 * 60 * 60 * 1000);
  return kst.toISOString().slice(0, 10).replace(/-/g, '');
}

// ─── Gemini Client (다른 AI로 바꿀 때: URL과 buildBody 요청 포맷 교체) ────────

const GEMINI_URL =
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

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

async function processWithGemini(
  hourlyData: KmaHourlyWeather[],
  apiKey: string,
): Promise<RidingRecommendation> {
  const body = {
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
          recommendation: { type: 'STRING', enum: ['추천', '보통', '비추천'] },
          reason: { type: 'STRING' },
        },
        required: ['weather', 'temperature', 'wind', 'recommendedTimeSlot', 'recommendation', 'reason'],
      },
    },
  };

  let res: Response;
  try {
    res = await fetch(`${GEMINI_URL}?key=${apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
  } catch (e) {
    throw new Error(`GEMINI_ERROR: 네트워크 오류 — ${String(e)}`);
  }

  if (!res.ok) {
    const detail = await res.text().catch(() => '');
    throw new Error(`GEMINI_ERROR: HTTP ${res.status} — ${detail}`);
  }

  const data = await res.json();
  const text: string | undefined = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) throw new Error('GEMINI_ERROR: 빈 응답');

  return JSON.parse(text) as RidingRecommendation;
}

// ─── Entry point ──────────────────────────────────────────────────────────────

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const DEFAULT_LAT = 37.5665;
const DEFAULT_LNG = 126.978;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: CORS });

  try {
    const kmaKey = Deno.env.get('KMA_API_KEY');
    const geminiKey = Deno.env.get('GEMINI_API_KEY');
    if (!kmaKey || !geminiKey) {
      return errRes('CONFIG_ERROR', '환경 변수 누락: KMA_API_KEY 또는 GEMINI_API_KEY', 500);
    }

    let lat = DEFAULT_LAT;
    let lng = DEFAULT_LNG;
    try {
      const b = await req.json();
      if (typeof b?.lat === 'number') lat = b.lat;
      if (typeof b?.lng === 'number') lng = b.lng;
    } catch { /* body 없으면 기본값 사용 */ }

    const { nx, ny } = latLngToGrid(lat, lng);
    const now = new Date();
    const { baseDate, baseTime } = getBaseDateTime(now);

    const rawItems = await fetchKmaForecast({ serviceKey: kmaKey, nx, ny, baseDate, baseTime });

    const today = todayKst(now);
    const hourlyData = mapTodayHourly(rawItems, today);
    if (hourlyData.length === 0) {
      return errRes('KMA_EMPTY_RESPONSE', '오늘 예보 데이터가 없습니다', 502);
    }

    const recommendation = await processWithGemini(hourlyData, geminiKey);

    return new Response(JSON.stringify(recommendation), {
      headers: { ...CORS, 'Content-Type': 'application/json' },
    });
  } catch (err) {
    if (err instanceof KmaError) {
      const status = err.code === 'KMA_TIMEOUT' ? 504 : 502;
      return errRes(err.code, err.message, status);
    }
    const msg = err instanceof Error ? err.message : String(err);
    if (msg.startsWith('GEMINI_ERROR')) {
      return errRes('GEMINI_ERROR', msg.replace('GEMINI_ERROR: ', ''), 502);
    }
    return errRes('INTERNAL_ERROR', msg, 500);
  }
});

function errRes(code: ErrorCode, message: string, status: number): Response {
  return new Response(JSON.stringify({ code, message }), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });
}
