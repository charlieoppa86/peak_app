// 다른 API로 바꿀 때: 이 파일 전체를 새 날씨 API 클라이언트로 교체 (URL·파라미터·응답 구조 모두 여기 집중)

import type { ErrorCode, KmaForecastItem } from './types.ts';

const KMA_URL =
  'https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getVilageFcst';
const TIMEOUT_MS = 10_000;

// 호출 측이 code 필드로 에러 종류를 식별할 수 있도록 구조화된 에러 사용
export class KmaError extends Error {
  constructor(
    public readonly code: ErrorCode,
    message: string,
  ) {
    super(message);
    this.name = 'KmaError';
  }
}

export interface KmaFetchOptions {
  serviceKey: string;
  nx: number;
  ny: number;
  baseDate: string; // YYYYMMDD
  baseTime: string; // HHmm (예: '0500')
  numOfRows?: number;
}

export async function fetchKmaForecast(
  opts: KmaFetchOptions,
): Promise<KmaForecastItem[]> {
  const params = new URLSearchParams({
    serviceKey: opts.serviceKey,
    pageNo: '1',
    numOfRows: String(opts.numOfRows ?? 1000),
    dataType: 'JSON',
    base_date: opts.baseDate,
    base_time: opts.baseTime,
    nx: String(opts.nx),
    ny: String(opts.ny),
  });

  // 10초 초과 시 AbortError → KMA_TIMEOUT으로 변환
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

  // 4xx / 5xx 분리
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

/**
 * 현재 시각 기준 가장 최근 기상청 발표 시각 계산.
 * 발표: 0200·0500·0800·1100·1400·1700·2000·2300 (제공까지 ~10분, 여유 30분 확보).
 */
export function getBaseDateTime(now: Date): {
  baseDate: string;
  baseTime: string;
} {
  const kstMs = now.getTime() + 9 * 60 * 60 * 1000;
  const kst = new Date(kstMs);
  const kstMinutes = kst.getUTCHours() * 60 + kst.getUTCMinutes();

  const slots = [120, 300, 480, 660, 840, 1020, 1200, 1380]; // 0200~2300 (분 단위)
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

  // 자정~02:30 KST → 전날 2300 발표분
  const prevDay = new Date(kstMs - 24 * 60 * 60 * 1000);
  return {
    baseDate: prevDay.toISOString().slice(0, 10).replace(/-/g, ''),
    baseTime: '2300',
  };
}
