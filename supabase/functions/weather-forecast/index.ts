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
  forecast: DayForecast[];
}

interface DayForecast {
  date: string;               // "YYYYMMDD"
  score: number;              // 0–100
  temperature: number;        // 대표 기온 (°C)
  precipitationChance: number; // 강수확률 (%)
  windSpeed: number;          // 평균 풍속 (m/s)
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

// ─── Region code mapping ──────────────────────────────────────────────────────

function getMidTaRegId(lat: number, lng: number): string {
  if (lat >= 37.4 && lat <= 37.7 && lng >= 126.7 && lng <= 127.3) return '11B10101'; // 서울
  if (lat >= 37.2 && lat <= 37.5 && lng >= 126.4 && lng <= 126.8) return '11B20601'; // 인천
  if (lat >= 36.3 && lat <= 36.7 && lng >= 127.2 && lng <= 127.6) return '11C20401'; // 대전
  if (lat >= 35.8 && lat <= 36.1 && lng >= 128.5 && lng <= 128.8) return '11H10501'; // 대구
  if (lat >= 35.0 && lat <= 35.3 && lng >= 129.0 && lng <= 129.3) return '11H20201'; // 부산
  if (lat >= 35.1 && lat <= 35.3 && lng >= 126.8 && lng <= 127.0) return '11F20501'; // 광주
  if (lat >= 35.5 && lat <= 36.0 && lng >= 129.0 && lng <= 129.5) return '11H20101'; // 울산
  if (lat >= 33.2 && lat <= 33.6 && lng >= 126.0 && lng <= 127.0) return '11G00201'; // 제주
  return '11B10101';
}

function getMidLandRegId(lat: number, lng: number): string {
  if (lat >= 37.0 && lat <= 38.5 && lng >= 126.0 && lng <= 128.5) return '11B00000'; // 서울·인천·경기
  if (lat >= 36.0 && lat <= 37.5 && lng >= 127.0 && lng <= 128.5) return '11C10000'; // 충북
  if (lat >= 36.0 && lat <= 37.5 && lng >= 125.5 && lng <= 127.5) return '11C20000'; // 충남·세종
  if (lat >= 35.3 && lat <= 36.5 && lng >= 127.0 && lng <= 128.0) return '11F10000'; // 전북
  if (lat >= 34.0 && lat <= 35.5 && lng >= 125.5 && lng <= 127.5) return '11F20000'; // 전남·광주
  if (lat >= 35.5 && lat <= 38.0 && lng >= 127.5 && lng <= 130.0) return '11H10000'; // 경북
  if (lat >= 34.5 && lat <= 36.0 && lng >= 127.5 && lng <= 130.0) return '11H20000'; // 경남·울산
  if (lat >= 33.0 && lat <= 34.0) return '11G00000'; // 제주
  return '11B00000';
}

// ─── KMA Clients ──────────────────────────────────────────────────────────────

const KMA_SHORT_URL =
  'https://apihub.kma.go.kr/api/typ02/openApi/VilageFcstInfoService_2.0/getVilageFcst';
const KMA_MID_TA_URL =
  'https://apihub.kma.go.kr/api/typ02/openApi/MidFcstInfoService/getMidTa';
const KMA_MID_LAND_URL =
  'https://apihub.kma.go.kr/api/typ02/openApi/MidFcstInfoService/getMidLandFcst';
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
    res = await fetch(`${KMA_SHORT_URL}?${params}`, { signal: controller.signal });
  } catch (e) {
    if (e instanceof Error && e.name === 'AbortError') {
      throw new KmaError('KMA_TIMEOUT', '기상청 API가 10초 내에 응답하지 않았습니다');
    }
    throw new KmaError('INTERNAL_ERROR', `네트워크 오류: ${String(e)}`);
  } finally {
    clearTimeout(timer);
  }

  if (res.status >= 400 && res.status < 500)
    throw new KmaError('KMA_HTTP_4XX', `기상청 API 클라이언트 오류: HTTP ${res.status}`);
  if (res.status >= 500)
    throw new KmaError('KMA_HTTP_5XX', `기상청 API 서버 오류: HTTP ${res.status}`);

  const json = await res.json();
  const header = json?.response?.header;
  if (header?.resultCode !== '00') {
    throw new KmaError(
      'KMA_API_ERROR',
      `기상청 API 오류 [${header?.resultCode}]: ${header?.resultMsg ?? '알 수 없음'}`,
    );
  }

  const items: unknown = json?.response?.body?.items?.item;
  if (!Array.isArray(items) || items.length === 0)
    throw new KmaError('KMA_EMPTY_RESPONSE', '기상청 예보 데이터가 없습니다');

  return items as KmaForecastItem[];
}

// graceful — returns {} on any failure
async function fetchMidTa(opts: {
  serviceKey: string;
  regId: string;
  tmFc: string;
}): Promise<Record<string, number>> {
  const params = new URLSearchParams({
    pageNo: '1', numOfRows: '10', dataType: 'JSON',
    regId: opts.regId, tmFc: opts.tmFc, authKey: opts.serviceKey,
  });
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
  try {
    const res = await fetch(`${KMA_MID_TA_URL}?${params}`, { signal: controller.signal });
    if (!res.ok) return {};
    const json = await res.json();
    const items = json?.response?.body?.items?.item;
    return Array.isArray(items) && items.length > 0 ? items[0] as Record<string, number> : {};
  } catch { return {}; } finally { clearTimeout(timer); }
}

async function fetchMidLandFcst(opts: {
  serviceKey: string;
  regId: string;
  tmFc: string;
}): Promise<Record<string, unknown>> {
  const params = new URLSearchParams({
    pageNo: '1', numOfRows: '10', dataType: 'JSON',
    regId: opts.regId, tmFc: opts.tmFc, authKey: opts.serviceKey,
  });
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
  try {
    const res = await fetch(`${KMA_MID_LAND_URL}?${params}`, { signal: controller.signal });
    if (!res.ok) return {};
    const json = await res.json();
    const items = json?.response?.body?.items?.item;
    return Array.isArray(items) && items.length > 0 ? items[0] as Record<string, unknown> : {};
  } catch { return {}; } finally { clearTimeout(timer); }
}

// ─── Base time helpers ────────────────────────────────────────────────────────

function getBaseDateTime(now: Date, slotOffset = 0): { baseDate: string; baseTime: string } {
  const kstMs = now.getTime() + 9 * 60 * 60 * 1000;
  const kst = new Date(kstMs);
  const kstMinutes = kst.getUTCHours() * 60 + kst.getUTCMinutes();
  const slots = [120, 300, 480, 660, 840, 1020, 1200, 1380];
  // 60분 버퍼: KMA 데이터가 발표 후 올라오는 데 걸리는 시간 고려
  const valid = slots.filter((m) => m <= kstMinutes - 60);
  const idx = valid.length - 1 - slotOffset;
  if (idx >= 0) {
    const t = valid[idx];
    const h = String(Math.floor(t / 60)).padStart(2, '0');
    const m = String(t % 60).padStart(2, '0');
    return {
      baseDate: kst.toISOString().slice(0, 10).replace(/-/g, ''),
      baseTime: `${h}${m}`,
    };
  }
  // 오늘 유효 슬롯이 없거나 offset이 넘치면 전날 23:00으로 fallback
  const prevDay = new Date(kstMs - 24 * 60 * 60 * 1000);
  return {
    baseDate: prevDay.toISOString().slice(0, 10).replace(/-/g, ''),
    baseTime: '2300',
  };
}

// 중기예보 발표 시각: 06시 또는 18시 (KST)
function getMidFcstBaseTime(now: Date): string {
  const kstMs = now.getTime() + 9 * 60 * 60 * 1000;
  const kst = new Date(kstMs);
  const dateStr = kst.toISOString().slice(0, 10).replace(/-/g, '');
  const hour = kst.getUTCHours();
  if (hour >= 18) return `${dateStr}1800`;
  if (hour >= 6) return `${dateStr}0600`;
  const prev = new Date(kstMs - 24 * 60 * 60 * 1000);
  return `${prev.toISOString().slice(0, 10).replace(/-/g, '')}1800`;
}

function todayKst(now: Date): string {
  const kst = new Date(now.getTime() + 9 * 60 * 60 * 1000);
  return kst.toISOString().slice(0, 10).replace(/-/g, '');
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

function mapDayHourly(items: KmaForecastItem[], date: string): KmaHourlyWeather[] {
  const dayItems = items.filter((i) => i.fcstDate === date);
  const byTime = new Map<string, Map<string, string>>();
  for (const item of dayItems) {
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

// 단기예보 raw items에서 날짜별 강수확률 추출 (POP 카테고리)
function getDayPrecipChance(items: KmaForecastItem[], date: string): number {
  const popItems = items.filter((i) => i.fcstDate === date && i.category === 'POP');
  if (popItems.length === 0) return 0;
  return Math.max(...popItems.map((i) => parseInt(i.fcstValue) || 0));
}

// ─── Scoring ─────────────────────────────────────────────────────────────────

function calcShortTermScore(hours: KmaHourlyWeather[]): number {
  const day = hours.filter((h) => {
    const hh = parseInt(h.time.slice(0, 2));
    return hh >= 6 && hh <= 20;
  });
  const s = day.length > 0 ? day : hours;
  if (s.length === 0) return 50;

  let score = 100;
  const rainHours = s.filter((h) => h.precipLabel !== '없음').length;
  if (rainHours > 0) score -= Math.min(65, rainHours * 13);

  const avgTemp = s.reduce((a, h) => a + h.temperature, 0) / s.length;
  if (avgTemp < 0) score -= 30;
  else if (avgTemp < 5) score -= 18;
  else if (avgTemp < 10) score -= 7;
  else if (avgTemp > 33) score -= 25;
  else if (avgTemp > 28) score -= 12;
  else if (avgTemp > 25) score -= 3;

  const avgWind = s.reduce((a, h) => a + h.windSpeed, 0) / s.length;
  if (avgWind >= 14) score -= 30;
  else if (avgWind >= 8) score -= 15;
  else if (avgWind >= 5) score -= 5;

  return Math.max(5, Math.min(100, Math.round(score)));
}

function calcMidTermScore(
  taMin: number,
  taMax: number,
  precipChance: number,
  skyText?: string,
): number {
  const avg = (taMin + taMax) / 2;
  let score = 95;
  score -= precipChance * 0.65;
  if (avg < 0) score -= 28;
  else if (avg < 5) score -= 16;
  else if (avg < 10) score -= 6;
  else if (avg > 33) score -= 22;
  else if (avg > 28) score -= 10;
  else if (avg > 25) score -= 3;
  if (skyText) {
    if (skyText.includes('비') || skyText.includes('눈') || skyText.includes('소나기')) score -= 18;
    else if (skyText.includes('흐림')) score -= 6;
    else if (skyText.includes('구름많음')) score -= 2;
  }
  return Math.max(5, Math.min(100, Math.round(score)));
}

// ─── Riding Analyzer (오늘 카드용) ───────────────────────────────────────────

type HourScore = 2 | 1 | 0;

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
      const scores: number[] = w.map(scoreHour);
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
  avgTemp: number, avgWind: number,
  topPrecip: string, topSky: string,
  minTemp: number, maxTemp: number,
): string {
  if (level === '추천') {
    if (avgTemp >= 15 && avgTemp <= 22)
      return `라이딩 최적 기온 (${avgTemp}°C), 강수 없고 바람도 약해 최상의 컨디션이에요.`;
    return `강수 없고 바람도 약해 라이딩하기 좋아요. 기온 ${minTemp}~${maxTemp}°C 대비해 주세요.`;
  }
  if (level === '보통') {
    if (topPrecip !== '없음') return `${topPrecip} 가능성 있어요. 방수 재킷 챙기면 라이딩 가능한 날씨예요.`;
    if (avgWind >= 5) return `바람이 ${avgWind}m/s로 다소 강해요. 맞바람 구간에서 페이스 조절이 필요해요.`;
    if (avgTemp < 10) return `기온이 낮아요 (${avgTemp}°C). 동계 레이어링 필수, 짧은 구간을 추천해요.`;
    if (avgTemp > 25) return `기온이 높아요 (${avgTemp}°C). 이른 아침 라이딩과 수분 보충에 신경 써주세요.`;
    return `${topSky} 날씨에 기온 ${avgTemp}°C로 짧은 라이딩은 괜찮아요.`;
  }
  if (topPrecip !== '없음' && avgWind >= 10)
    return `${topPrecip}에 강풍 (${avgWind}m/s)까지 예보됐어요. 오늘은 실내 훈련을 추천해요.`;
  if (topPrecip !== '없음') return `${topPrecip}가 예보됐어요. 미끄러운 노면 위험으로 라이딩을 삼가는 게 좋아요.`;
  if (avgWind >= 10) return `강풍 (${avgWind}m/s)이 예보됐어요. 낙차 위험이 있어 오늘은 쉬는 날로 하세요.`;
  if (minTemp < 0) return `영하 날씨 (최저 ${minTemp}°C)로 노면 결빙 위험이 있어요. 라이딩을 미뤄주세요.`;
  return `오늘 날씨는 라이딩에 적합하지 않아요. 내일 날씨를 확인해 보세요.`;
}

function analyzeRiding(hours: KmaHourlyWeather[]): Omit<RidingRecommendation, 'forecast'> {
  const daytime = hours.filter((h) => {
    const hh = parseInt(h.time.slice(0, 2));
    return hh >= 6 && hh <= 20;
  });
  const sample = daytime.length > 0 ? daytime : hours;
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

// ─── Forecast builders ────────────────────────────────────────────────────────

function buildShortTermForecast(items: KmaForecastItem[], date: string): DayForecast {
  const hourly = mapDayHourly(items, date);
  const day = hourly.filter((h) => { const hh = parseInt(h.time.slice(0, 2)); return hh >= 6 && hh <= 20; });
  const s = day.length > 0 ? day : hourly;
  const avgTemp = s.length > 0 ? Math.round(s.reduce((a, h) => a + h.temperature, 0) / s.length) : 0;
  const avgWind = s.length > 0 ? Math.round((s.reduce((a, h) => a + h.windSpeed, 0) / s.length) * 10) / 10 : 0;
  return {
    date,
    score: calcShortTermScore(hourly),
    temperature: avgTemp,
    precipitationChance: getDayPrecipChance(items, date),
    windSpeed: avgWind,
  };
}

function buildMidTermForecasts(
  taData: Record<string, number>,
  landData: Record<string, unknown>,
  now: Date,
): DayForecast[] {
  const result: DayForecast[] = [];
  const kstMs = now.getTime() + 9 * 60 * 60 * 1000;

  for (let d = 3; d <= 10; d++) {
    const taMin = taData[`taMin${d}`];
    const taMax = taData[`taMax${d}`];
    if (taMin === undefined || taMax === undefined) continue;

    // 강수확률: D+3~7은 AM/PM 분리, D+8~10은 단일 값
    let precipChance = 0;
    let skyText: string | undefined;
    if (d <= 7) {
      const am = (landData[`rnSt${d}Am`] as number | undefined) ?? 0;
      const pm = (landData[`rnSt${d}Pm`] as number | undefined) ?? 0;
      precipChance = Math.max(am, pm);
      const amSky = landData[`wf${d}Am`] as string | undefined;
      const pmSky = landData[`wf${d}Pm`] as string | undefined;
      if (pmSky && (pmSky.includes('비') || pmSky.includes('눈'))) skyText = pmSky;
      else skyText = amSky ?? pmSky;
    } else {
      precipChance = (landData[`rnSt${d}`] as number | undefined) ?? 0;
      skyText = landData[`wf${d}`] as string | undefined;
    }

    const targetDate = new Date(kstMs + d * 24 * 60 * 60 * 1000);
    const dateStr = targetDate.toISOString().slice(0, 10).replace(/-/g, '');

    result.push({
      date: dateStr,
      score: calcMidTermScore(taMin, taMax, precipChance, skyText),
      temperature: Math.round((taMin + taMax) / 2),
      precipitationChance: precipChance,
      windSpeed: 0, // 중기예보 API는 풍속 미제공
    });
  }
  return result;
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
    if (!kmaKey) return errRes('CONFIG_ERROR', '환경 변수 누락: KMA_API_KEY', 500);

    let lat = DEFAULT_LAT, lng = DEFAULT_LNG;
    try {
      const b = await req.json();
      if (typeof b?.lat === 'number') lat = b.lat;
      if (typeof b?.lng === 'number') lng = b.lng;
    } catch { /* body 없으면 기본값 사용 */ }

    const { nx, ny } = latLngToGrid(lat, lng);
    const now = new Date();
    const today = todayKst(now);

    // 1. 단기예보 조회 (D+0 ~ D+2) — 빈 응답이면 한 슬롯 이전으로 재시도
    let rawItems = await fetchKmaForecast({ serviceKey: kmaKey, nx, ny, ...getBaseDateTime(now) });
    if (mapDayHourly(rawItems, today).length === 0) {
      rawItems = await fetchKmaForecast({ serviceKey: kmaKey, nx, ny, ...getBaseDateTime(now, 1) });
    }

    // 2. 오늘 분석 (홈 카드용)
    const todayHourly = mapDayHourly(rawItems, today);
    if (todayHourly.length === 0)
      return errRes('KMA_EMPTY_RESPONSE', '오늘 예보 데이터가 없습니다', 502);
    const todayRec = analyzeRiding(todayHourly);

    // 3. 단기 날별 DayForecast
    const shortDates = [...new Set(rawItems.map((i) => i.fcstDate))].sort();
    const shortForecasts = shortDates.map((d) => buildShortTermForecast(rawItems, d));

    // 4. 중기예보 조회 (D+3 ~ D+10) — 실패해도 단기만 반환
    const tmFc = getMidFcstBaseTime(now);
    const [taData, landData] = await Promise.all([
      fetchMidTa({ serviceKey: kmaKey, regId: getMidTaRegId(lat, lng), tmFc }),
      fetchMidLandFcst({ serviceKey: kmaKey, regId: getMidLandRegId(lat, lng), tmFc }),
    ]);
    const midForecasts = buildMidTermForecasts(taData, landData, now);

    // 5. 합산 (단기 우선, 날짜 오름차순)
    const shortDatesSet = new Set(shortForecasts.map((f) => f.date));
    const forecast: DayForecast[] = [
      ...shortForecasts,
      ...midForecasts.filter((f) => !shortDatesSet.has(f.date)),
    ].sort((a, b) => a.date.localeCompare(b.date));

    return new Response(JSON.stringify({ ...todayRec, forecast }), {
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
