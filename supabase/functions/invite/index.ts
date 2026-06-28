import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

const APP_STORE_URL = 'https://apps.apple.com/kr/app/peak/id6745970148';
const BUNDLE_ID = 'com.charlieoppa86.peak';

serve(async (req: Request) => {
  const url = new URL(req.url);

  // URL: /functions/v1/invite/{scheduleId}
  const pathParts = url.pathname.split('/');
  const scheduleId = pathParts[pathParts.length - 1];

  const course = url.searchParams.get('course') ?? '';
  const date = url.searchParams.get('date') ?? '';
  const time = url.searchParams.get('time') ?? '';

  // 앱 딥링크: peak://home/schedule/{id}/rsvp
  const deepLink = `peak://home/schedule/${scheduleId}/rsvp?course=${encodeURIComponent(course)}&date=${encodeURIComponent(date)}&time=${encodeURIComponent(time)}`;

  const html = `<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Peak 라이딩 초대</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      background: #0f0f0f;
      color: #f0f0f0;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 24px;
    }
    .card {
      background: #1e1e1e;
      border-radius: 20px;
      padding: 32px 24px;
      width: 100%;
      max-width: 380px;
      text-align: center;
    }
    .logo {
      font-size: 28px;
      font-weight: 800;
      letter-spacing: -0.5px;
      color: #4ade80;
      margin-bottom: 4px;
    }
    .tagline {
      font-size: 13px;
      color: #888;
      margin-bottom: 28px;
    }
    .divider {
      height: 1px;
      background: #2e2e2e;
      margin: 20px 0;
    }
    .label {
      font-size: 12px;
      color: #888;
      margin-bottom: 4px;
      text-align: left;
    }
    .value {
      font-size: 16px;
      font-weight: 600;
      color: #f0f0f0;
      text-align: left;
      margin-bottom: 14px;
    }
    .invite-title {
      font-size: 18px;
      font-weight: 700;
      color: #4ade80;
      margin-bottom: 20px;
    }
    .btn {
      display: block;
      width: 100%;
      padding: 15px;
      border-radius: 14px;
      font-size: 16px;
      font-weight: 600;
      text-decoration: none;
      border: none;
      cursor: pointer;
      margin-top: 12px;
    }
    .btn-primary {
      background: #4ade80;
      color: #0f0f0f;
    }
    .btn-secondary {
      background: #2e2e2e;
      color: #f0f0f0;
    }
    .notice {
      font-size: 13px;
      color: #aaa;
      margin-top: 20px;
      background: #2a2a2a;
      border-radius: 10px;
      padding: 12px 14px;
      line-height: 1.6;
      text-align: left;
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="logo">Peak</div>
    <div class="tagline">날씨 보고 라이딩 잡는 앱</div>

    <div class="invite-title">🚴 라이딩 초대</div>

    ${course ? `<div class="label">코스</div><div class="value">${escapeHtml(course)}</div>` : ''}
    ${date ? `<div class="label">날짜</div><div class="value">${escapeHtml(date)}</div>` : ''}
    ${time ? `<div class="label">시간</div><div class="value">${escapeHtml(time)}</div>` : ''}

    <div class="divider"></div>

    <a class="btn btn-primary" href="${deepLink}" id="open-btn">
      앱에서 참석 여부 답하기
    </a>
    <a class="btn btn-secondary" href="${APP_STORE_URL}">
      Peak 앱 다운로드
    </a>

    <div class="notice">
      💬 카카오톡에서 열리셨나요?<br>
      오른쪽 하단 <strong>···</strong> → <strong>Safari로 열기</strong>를 탭해주세요.
    </div>
  </div>
</body>
</html>`;

  return new Response(html, {
    headers: { 'Content-Type': 'text/html; charset=utf-8' },
  });
});

function escapeHtml(s: string): string {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}
