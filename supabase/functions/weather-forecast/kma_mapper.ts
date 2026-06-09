// 다른 API로 바꿀 때: 카테고리 코드(CATEGORY)와 레이블 매핑 함수를 새 API 스펙에 맞게 교체

import type { KmaForecastItem, KmaHourlyWeather } from './types.ts';

// 기상청 카테고리 코드
const CAT = {
  TMP: 'TMP', // 기온 (°C, 1시간 간격)
  SKY: 'SKY', // 하늘상태 (1=맑음, 3=구름많음, 4=흐림)
  PTY: 'PTY', // 강수형태 (0=없음, 1=비, 2=비·눈, 3=눈, 4=소나기)
  WSD: 'WSD', // 풍속 (m/s, 1시간 간격)
} as const;

function skyLabel(val: string): string {
  return { '1': '맑음', '3': '구름많음', '4': '흐림' }[val] ?? '알 수 없음';
}

function precipLabel(val: string): string {
  return (
    { '0': '없음', '1': '비', '2': '비·눈', '3': '눈', '4': '소나기' }[val] ??
    '알 수 없음'
  );
}

function windLabel(mps: number): string {
  if (mps < 3) return '약풍';
  if (mps < 8) return '보통';
  if (mps < 14) return '강풍';
  return '매우강풍';
}

/**
 * 오늘(KST 기준) 시간별 날씨 추출.
 * todayKst: 'YYYYMMDD' 형식 — 이 날짜의 데이터만 필터링.
 */
export function mapTodayHourly(
  items: KmaForecastItem[],
  todayKst: string,
): KmaHourlyWeather[] {
  const todayItems = items.filter((i) => i.fcstDate === todayKst);

  // fcstTime별로 그룹핑
  const byTime = new Map<string, Map<string, string>>();
  for (const item of todayItems) {
    if (!byTime.has(item.fcstTime)) byTime.set(item.fcstTime, new Map());
    byTime.get(item.fcstTime)!.set(item.category, item.fcstValue);
  }

  const result: KmaHourlyWeather[] = [];
  for (const [fcstTime, cats] of byTime) {
    const tmp = parseFloat(cats.get(CAT.TMP) ?? '');
    const wsd = parseFloat(cats.get(CAT.WSD) ?? '');
    if (isNaN(tmp) || isNaN(wsd)) continue; // 기온·풍속 없으면 해당 시간대 제외

    const hh = fcstTime.slice(0, 2);
    result.push({
      time: `${hh}:00`,
      temperature: Math.round(tmp),
      skyLabel: skyLabel(cats.get(CAT.SKY) ?? ''),
      precipLabel: precipLabel(cats.get(CAT.PTY) ?? '0'),
      windSpeed: Math.round(wsd * 10) / 10,
      windLabel: windLabel(wsd),
    });
  }

  return result.sort((a, b) => a.time.localeCompare(b.time));
}

/** 현재 KST 날짜를 'YYYYMMDD' 형식으로 반환. */
export function todayKst(now: Date): string {
  const kst = new Date(now.getTime() + 9 * 60 * 60 * 1000);
  return kst.toISOString().slice(0, 10).replace(/-/g, '');
}
