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
  | 'CONFIG_ERROR'
  | 'INTERNAL_ERROR';

// ─── Coordinate ───────────────────────────────────────────────────────────────

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

// ─── KMA Client ───────────────────────────────────────────────────────────────

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

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);

  let res: Response;
  try {
    res = await fetch(`${KMA_URL}?${params}`, { signal: controller.signal });
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

// ─── KMA Mapper ───────────────────────────────────────────────────────────────

function skyLabel(val: string): string {
  return ({ '1': '맑음', '3': '구름많음', '4': '흐림' } as Record<string, string>)[val] ?? '알 수 없음';
}
function precipLabel(val: string): string {
  return (
    { '0': '없음', '1': '비', '2': '비·눈', '3': '눈', '4': '소나기' } as Record<string, string>
  )[val] ?? '알 수 없음';
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

// ─── Rule-based Riding Analyzer ───────────────────────────────────────────────

type HourScore = 2 | 1 | 0; // 2=추천, 1=보통, 0=비추천

function scoreHour(h: KmaHourlyWeather): HourScore {
  const hasRain = h.precipLabel !== '없음';
  const tempGood = h.temperature >= 10 && h.temperature <= 25;
  const windGood = h.windSpeed < 5;
  const tempExtreme = h.temperature < 0 || h.temperature > 35;
  const windStrong = h.windSpeed >= 10;

  if (!hasRain && tempGood && windGood) return 2;
  if (tempExtreme || windStrong) return 0;
  return 1;
}

function findBestWindow(
  hours: KmaHourlyWeather[],
): { start: string; end: string; level: '추천' | '보통' | '비추천' } | null {
  const daytime = hours.filter((h) => {
    const hh = parseInt(h.time.slice(0, 2));
    return hh >= 6 && hh <= 20;
  });
  if (daytime.length === 0) return null;

  let best: { start: string; end: string; score: number; minScore: HourScore } | null = null;

  for (const size of [3, 2]) {
    for (let i = 0; i <= daytime.length - size; i++) {
      const w = daytime.slice(i, i + size);
      const scores = w.map(scoreHour);
      const total = scores.reduce((a, b) => a + b, 0);
      const minScore = Math.min(...scores) as HourScore;
      if (!best || total > best.score || (total === best.score && minScore > best.minScore)) {
        best = {
          start: `${w[0].time.slice(0, 2)}시`,
          end: `${String(parseInt(w[w.length - 1].time.slice(0, 2)) + 1).padStart(2, '0')}시`,
          score: total,
          minScore,
        };
      }
    }
    if (best && best.minScore === 2) break;
  }

  if (!best) return null;
  const level: '추천' | '보통' | '비추천' =
    best.minScore === 2 ? '추천' : best.minScore === 1 ? '보통' : '비추천';
  return { start: best.start, end: best.end, level };
}

function buildReason(
  level: '추천' | '보통' | '비추천',
  avgTemp: number,
  avgWind: number,
  topPrecip: string,
  topSky: string,
  minTemp: number,
  maxTemp: number,
): string {
  if (level === '추천') {
    if (avgTemp >= 15 && avgTemp <= 22) {
      return `라이딩 최적 기온 (${avgTemp}°C), 강수 없고 바람도 약해 최상의 컨디션이에요.`;
    }
    return `강수 없고 바람도 약해 라이딩하기 좋아요. 기온 ${minTemp}~${maxTemp}°C 대비해 주세요.`;
  }
  if (level === '보통') {
    if (topPrecip !== '없음') {
      return `${topPrecip} 가능성 있어요. 방수 재킷 챙기면 라이딩 가능한 날씨예요.`;
    }
    if (avgWind >= 5) {
      return `바람이 ${avgWind}m/s로 다소 강해요. 맞바람 구간에서 페이스 조절이 필요해요.`;
    }
    if (avgTemp < 10) {
      return `기온이 낮아요 (${avgTemp}°C). 동계 레이어링 필수, 짧은 구간을 추천해요.`;
    }
    if (avgTemp > 25) {
      return `기온이 높아요 (${avgTemp}°C). 이른 아침 라이딩과 수분 보충에 신경 써주세요.`;
    }
    return `${topSky} 날씨에 기온 ${avgTemp}°C로 짧은 라이딩은 괜찮아요.`;
  }
  // 비추천
  if (topPrecip !== '없음' && avgWind >= 10) {
    return `${topPrecip}에 강풍 (${avgWind}m/s)까지 예보됐어요. 오늘은 실내 훈련을 추천해요.`;
  }
  if (topPrecip !== '없음') {
    return `${topPrecip}가 예보됐어요. 미끄러운 노면 위험으로 라이딩을 삼가는 게 좋아요.`;
  }
  if (avgWind >= 10) {
    return `강풍 (${avgWind}m/s)이 예보됐어요. 낙차 위험이 있어 오늘은 쉬는 날로 하세요.`;
  }
  if (minTemp < 0) {
    return `영하 날씨 (최저 ${minTemp}°C)로 노면 결빙 위험이 있어요. 라이딩을 미뤄주세요.`;
  }
  return `오늘 날씨는 라이딩에 적합하지 않아요. 내일 날씨를 확인해 보세요.`;
}

function analyzeRiding(hours: KmaHourlyWeather[]): RidingRecommendation {
  const daytime = hours.filter((h) => {
    const hh = parseInt(h.time.slice(0, 2));
    return hh >= 6 && hh <= 20;
  });
  const sample = daytime.length > 0 ? daytime : hours;

  // 대표 날씨: 가장 많이 등장하는 값
  const freq = <T extends string>(arr: T[]): T =>
    arr.sort((a, b) => arr.filter((v) => v === b).length - arr.filter((v) => v === a).length)[0];
  const topPrecip = freq(sample.map((h) => h.precipLabel));
  const topSky = freq(sample.map((h) => h.skyLabel));
  const weatherSummary = topPrecip !== '없음' ? topPrecip : topSky;

  const avgTemp = Math.round(sample.reduce((s, h) => s + h.temperature, 0) / sample.length);
  const minTemp = Math.min(...sample.map((h) => h.temperature));
  const maxTemp = Math.max(...sample.map((h) => h.temperature));
  const avgWind = Math.round((sample.reduce((s, h) => s + h.windSpeed, 0) / sample.length) * 10) / 10;
  const topWindLabel = avgWind < 3 ? '약풍' : avgWind < 8 ? '보통' : avgWind < 14 ? '강풍' : '매우강풍';

  const window = findBestWindow(hours);
  const slot = window ? `${window.start}~${window.end}` : '없음';
  const level = window ? window.level : '비추천';

  return {
    weather: weatherSummary,
    temperature: `${avgTemp}°C`,
    wind: `${topWindLabel} (${avgWind}m/s)`,
    recommendedTimeSlot: slot,
    recommendation: level,
    reason: buildReason(level, avgTemp, avgWind, topPrecip, topSky, minTemp, maxTemp),
  };
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
    if (!kmaKey) {
      return errRes('CONFIG_ERROR', '환경 변수 누락: KMA_API_KEY', 500);
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

    const recommendation = analyzeRiding(hourlyData);

    return new Response(JSON.stringify(recommendation), {
      headers: { ...CORS, 'Content-Type': 'application/json' },
    });
  } catch (err) {
    if (err instanceof KmaError) {
      const status = err.code === 'KMA_TIMEOUT' ? 504 : 502;
      return errRes(err.code, err.message, status);
    }
    return errRes('INTERNAL_ERROR', err instanceof Error ? err.message : String(err), 500);
  }
});

function errRes(code: ErrorCode, message: string, status: number): Response {
  return new Response(JSON.stringify({ code, message }), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });
}
