# CloudWatch Logs 사용 가이드

Q-Feed 서비스의 로그를 CloudWatch에서 확인하는 방법을 안내합니다.

---

## 1. CloudWatch Logs 접속

### 1.1 AWS 콘솔 접속

1. AWS 콘솔 로그인: https://console.aws.amazon.com
2. 리전 확인: **서울 (ap-northeast-2)** 선택
3. 검색창에 "CloudWatch" 입력 → CloudWatch 클릭

> [캡쳐 필요] AWS 콘솔 상단 검색창에서 "CloudWatch" 검색하는 화면

### 1.2 Log groups 이동

1. 좌측 메뉴에서 **Logs** > **Log Management > Log groups** 탭 클릭
2. 또는 직접 접속: https://ap-northeast-2.console.aws.amazon.com/cloudwatch/home?region=ap-northeast-2#logsV2:log-groups

---

## 2. Q-Feed Log Groups

| Log Group             | 용도             | 설명                              |
| --------------------- | ---------------- | --------------------------------- |
| `/qfeed/prod/backend` | Spring Boot 로그 | API 서버 로그 (INFO, WARN, ERROR) |
| `/qfeed/prod/ai`      | FastAPI 로그     | AI 서버 로그                      |
| `/qfeed/prod/system`  | 시스템 로그      | EC2 syslog                        |

---

## 3. 로그 검색하기 (Logs Insights)

### 3.1 Logs Insights 접속

1. 좌측 메뉴에서 **Logs** > **Logs Insights** 클릭
2. 또는 직접 접속: https://ap-northeast-2.console.aws.amazon.com/cloudwatch/home?region=ap-northeast-2#logsV2:logs-insights

> [캡쳐 필요] Logs Insights 메인 화면

### 3.2 Log Group 선택

1. **Select log group(s)** 드롭다운 클릭
2. `/qfeed/prod/backend` 체크
3. 여러 개 동시 선택 가능 (backend + ai 같이 검색 가능)

### 3.3 시간 범위 설정

우측 상단에서 시간 범위 선택:

- **1h**: 최근 1시간
- **3h**: 최근 3시간
- **Custom**: 직접 지정

### 3.4 쿼리 작성 및 실행

쿼리 입력창에 원하는 쿼리 작성 후 **Run query** 버튼 클릭

---

## 4. 자주 쓰는 쿼리

### 4.1 최근 로그 조회

```
fields @timestamp, @message
| sort @timestamp desc
| limit 50
```

### 4.2 ERROR 로그만 조회

```
fields @timestamp, @message
| filter @message like /\[ERROR\]/
| sort @timestamp desc
| limit 50
```

### 4.3 특정 traceId로 요청 추적

```
fields @timestamp, @message
| filter @message like /19c28708/
| sort @timestamp asc
```

> traceId는 로그에서 `[3468d693]` 형태로 표시됩니다.
> 하나의 요청에 대한 모든 로그를 추적할 때 사용합니다.

### 4.4 특정 사용자(accountId) 로그 조회

```
fields @timestamp, @message
| filter @message like /accountId: 1/
| sort @timestamp desc
| limit 50
```

### 4.5 특정 API 엔드포인트 조회

```
fields @timestamp, @message
| filter @message like /POST \/api\/interview\/answers/
| sort @timestamp desc
| limit 50
```

### 4.6 WARN 이상 로그 조회

```
fields @timestamp, @message
| filter @message like /\[(WARN|ERROR)\]/
| sort @timestamp desc
| limit 100
```

---

## 5. 실시간 로그 보기 (Live Tail)

### 5.1 Live Tail 시작

1. Log groups에서 `/qfeed/prod/backend` 클릭
2. 상단의 **"Start trailing"** 버튼 클릭

### 5.2 필터 설정 (선택사항)

1. **Filter patterns**에 필터 입력 (예: `ERROR`)
2. **Start** 버튼 클릭

### 5.3 실시간 로그 확인

실시간으로 로그가 스트리밍됩니다. 종료하려면 **Stop** 버튼 클릭.

---

## 6. AWS CLI로 로그 확인 (터미널)

### 6.1 사전 준비

AWS CLI 설치 및 credentials 설정이 필요합니다.

```bash
# AWS CLI 설치 확인
aws --version

# 자격 증명 설정 확인
aws sts get-caller-identity
```

### 6.2 최근 로그 조회

```bash
# 최근 10분 로그
aws logs tail /qfeed/prod/backend --since 10m

# 최근 1시간 로그
aws logs tail /qfeed/prod/backend --since 1h
```

### 6.3 실시간 스트리밍

```bash
# 실시간 로그 (tail -f 처럼)
aws logs tail /qfeed/prod/backend --follow
```

`Ctrl+C`로 종료

### 6.4 특정 패턴 필터링

```bash
# ERROR 로그만
aws logs filter-log-events \
  --log-group-name /qfeed/prod/backend \
  --filter-pattern "ERROR"

# 특정 시간대 로그
aws logs filter-log-events \
  --log-group-name /qfeed/prod/backend \
  --start-time 1706950800000 \
  --end-time 1706954400000
```

---

## 7. 로그 포맷 이해하기

Q-Feed 로그는 다음 형식으로 기록됩니다:

```
[{timestamp}] [{level}] [{logger}] [{traceId}] {message}
```

### 예시

```
[2026-02-03 12:40:51.123] [INFO] [AnswerController] [3468d693] GET /api/answers - accountId: 18, size: 1
```

| 필드      | 값                                          | 설명                          |
| --------- | ------------------------------------------- | ----------------------------- |
| timestamp | `2026-02-03 12:40:51.123`                   | 로그 발생 시각 (밀리초 포함)  |
| level     | `INFO`                                      | 로그 레벨 (INFO, WARN, ERROR) |
| logger    | `AnswerController`                          | 로그를 남긴 클래스            |
| traceId   | `3468d693`                                  | 요청 추적 ID                  |
| message   | `GET /api/answers - accountId: 18, size: 1` | 로그 내용                     |

---

## 8. 장애 대응 시 로그 확인 순서

### 8.1 에러 발생 시

1. **ERROR 로그 먼저 확인**

   ```
   fields @timestamp, @message
   | filter @message like /\[ERROR\]/
   | sort @timestamp desc
   | limit 20
   ```

2. **에러 로그에서 traceId 확인** (예: `[abc123]`)

3. **해당 traceId로 전체 흐름 추적**
   ```
   fields @timestamp, @message
   | filter @message like /abc123/
   | sort @timestamp asc
   ```

### 8.2 특정 사용자 문제 신고 시

1. 사용자의 accountId 확인
2. 해당 accountId로 로그 검색
   ```
   fields @timestamp, @message
   | filter @message like /accountId: 123/
   | sort @timestamp desc
   | limit 50
   ```

---

## 9. 주의사항

- **시간대**: CloudWatch는 **UTC** 기준입니다. 한국 시간(KST)은 UTC+9.
  - 예: 한국 시간 오후 3시 = UTC 오전 6시
- **보관 기간**: 로그는 **30일** 후 자동 삭제됩니다.
- **비용**: 로그 저장 및 쿼리에 비용이 발생합니다. 불필요하게 큰 범위를 조회하지 마세요.

---

## 10. 문제 해결

### 로그가 안 보여요

1. **시간 범위 확인**: 로그 발생 시간이 선택한 범위에 포함되어 있는지 확인
2. **Log group 확인**: 올바른 log group을 선택했는지 확인
3. **쿼리 문법 확인**: 정규식 패턴이 올바른지 확인 (슬래시 `/` 사용)

### 쿼리가 너무 느려요

1. 시간 범위를 줄여보세요 (예: 24h → 1h)
2. `limit`을 추가하세요
3. 필터 조건을 더 구체적으로 작성하세요

---
