Firebase Hosting을 사용해서 AdMob용 app-ads.txt 파일을 호스팅하려고 해.

아래 순서대로 진행해줘:

1. 현재 디렉토리에 `app-ads-hosting` 폴더를 만들고 이동

2. `firebase init hosting` 실행

- public directory: public

- single-page app: No

- GitHub 자동 빌드: No

3. public 폴더 안에 app-ads.txt 파일 생성

- 내용: google.com, pub-8560405440054672, DIRECT, f08c47fec0942fa0

4. firebase.json에 루트("/") 접속 시 리디렉션 설정은 하지 마.

app-ads.txt 파일만 서빙되면 됨.

5. firebase deploy --only hosting 실행

6. 배포 완료 후 호스팅된 URL(https://peak-ads-dev.web.app/app-ads.txt)을 알려줘 이 URL을 브라우저에서 접속해서 내용이 정상 출력되는지 확인할 수 있게 해줘.