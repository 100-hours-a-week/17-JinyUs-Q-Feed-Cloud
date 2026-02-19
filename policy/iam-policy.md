## **1. 기본 원칙**

| 원칙                    | 설명                                           |
| ----------------------- | ---------------------------------------------- |
| **최소 권한 원칙**      | 업무에 필요한 최소한의 권한만 부여             |
| **역할 기반 접근**      | 개인이 아닌 역할(Role) 단위로 권한 관리        |
| **Root 계정 사용 금지** | Root는 MFA 설정 후 봉인, 일상 업무에 사용 금지 |
| **공용 계정 금지**      | 반드시 개인별 IAM 계정 사용                    |

---

## **2. 역할 정의**

| 역할              | 대상         | 인원 | 권한 범위                          |
| ----------------- | ------------ | ---- | ---------------------------------- |
| **Admin**         | 팀장         | 1명  | 전체 AWS 리소스 + IAM 관리         |
| **CloudEngineer** | 클라우드 팀  | 3명  | 전체 AWS 리소스 (IAM 제외)         |
| **Developer**     | 풀스택/AI 팀 | 3명  | S3, CloudWatch 읽기 + EC2 SSM 접속 |

---

## **3. 역할별 IAM 정책**

| 역할              | 정책명                 | 유형       | 비고           |
| ----------------- | ---------------------- | ---------- | -------------- |
| **Admin**         | `AdministratorAccess`  | AWS 관리형 | 전체 권한      |
| **CloudEngineer** | `PowerUserAccess`      | AWS 관리형 | IAM 제외 전체  |
| **Developer**     | `QfeedDeveloperPolicy` | 커스텀     | 아래 권한 조합 |

### **Developer 커스텀 정책 구성**

| 권한            | Action                                                                         | 범위                  |
| --------------- | ------------------------------------------------------------------------------ | --------------------- |
| S3 읽기/쓰기    | `s3:GetObject`, `s3:PutObject`, `s3:ListBucket`                                | `qfeed-dev-s3-*` 버킷 |
| CloudWatch 읽기 | `cloudwatch:Describe*`, `cloudwatch:Get*`, `logs:Get*`, `logs:FilterLogEvents` | 전체                  |
| EC2 읽기        | `ec2:DescribeInstances`                                                        | 전체                  |
| SSM 세션 접속   | `ssm:StartSession`, `ssm:TerminateSession`                                     | 전체 인스턴스         |

※ Developer는 dev 환경 S3만 접근 가능. prod 환경 S3는 EC2 Role을 통해서만 접근.

---

## **4. IAM 그룹 구조**

| 그룹명                 | 연결 정책                                      | 소속                |
| ---------------------- | ---------------------------------------------- | ------------------- |
| `qfeed-admin`          | `AdministratorAccess`                          | 클라우드 팀장(jiny) |
| `qfeed-cloud-engineer` | `PowerUserAccess` + `QfeedSelfManagedMFA`      | 클라우드 팀원 2명   |
| `qfeed-developer`      | `QfeedDeveloperPolicy` + `QfeedSelfManagedMFA` | 풀스택 2명, AI 1명  |

※ `QfeedSelfManagedMFA`: 자신의 MFA 설정/관리 권한 (13절 참고)

---

## **5. 역할별 권한 요약**

| 권한         | Admin | CloudEngineer | Developer   |
| ------------ | ----- | ------------- | ----------- |
| EC2 관리     | O     | O             | 읽기만      |
| EC2 SSM 접속 | O     | O             | O           |
| VPC 관리     | O     | O             | X           |
| RDS 관리     | O     | O             | X           |
| S3 관리      | O     | O             | 특정 버킷만 |
| CloudWatch   | O     | O             | 읽기만      |
| Route53      | O     | O             | X           |
| IAM 관리     | O     | X             | X           |
| 비용 확인    | O     | O             | X           |

---

## **6. EC2 접근 정책 (SSM Session Manager)**

### **6.1 개요**

SSH 키(PEM) 대신 SSM Session Manager를 사용한다.

| 항목         | SSH 키 방식        | SSM Session Manager  |
| ------------ | ------------------ | -------------------- |
| 키 관리      | PEM 파일 공유 필요 | 불필요               |
| 22번 포트    | 열어야 함          | 닫아도 됨            |
| 접근 로그    | 수동 기록          | CloudTrail 자동 기록 |
| 팀원 이탈 시 | 키 교체 필요       | IAM 권한만 제거      |

### **6.2 SSM 설정 요약**

| 단계 | 작업                                                |
| ---- | --------------------------------------------------- |
| 1    | IAM Role에 `AmazonSSMManagedInstanceCore` 정책 연결 |
| 2    | EC2 인스턴스에 Role 연결                            |
| 3    | SSM Agent 실행 확인                                 |

※ SSM 접속 권한은 각 EC2 Role(`qfeed-prod-role-ec2-backend`, `qfeed-prod-role-ec2-ai`)에 포함됨. 12절 참고.

SSM Agent 확인:

```bash
sudo systemctl status amazon-ssm-agent
```

### **6.3 접속 방법**

| 방법     | 경로                                          |
| -------- | --------------------------------------------- |
| AWS 콘솔 | EC2 > 인스턴스 > 연결 > Session Manager       |
| AWS CLI  | `aws ssm start-session --target {인스턴스ID}` |

---

## **7. 계정 보안 규칙**

### **7.1 비밀번호 정책**

| 항목        | 정책                              |
| ----------- | --------------------------------- |
| 최소 길이   | 12자 이상                         |
| 복잡성      | 대문자 + 소문자 + 숫자 + 특수문자 |
| 만료 주기   | 90일                              |
| 재사용 제한 | 최근 5개 비밀번호 재사용 금지     |

### **7.2 MFA**

| 항목      | 정책                               |
| --------- | ---------------------------------- |
| 적용 대상 | 모든 IAM 사용자 필수               |
| MFA 종류  | 가상 MFA (Google Authenticator 등) |
| 설정 기한 | 계정 생성 후 24시간 이내           |

### **7.3 Access Key**

| 항목      | 정책                         |
| --------- | ---------------------------- |
| 발급      | 필요한 경우에만              |
| 로테이션  | 90일마다 교체                |
| 미사용 키 | 30일 이상 미사용 시 비활성화 |
| 저장      | 로컬 저장 금지               |

---

## **8. IAM 사용자 관리**

### **8.1 계정 네이밍**

```
{이름}-{역할}
```

예시: `jiny-cloud`, `theo-dev`

### **8.2 신규 팀원 온보딩**

| 순서 | 작업                                   | 담당  |
| ---- | -------------------------------------- | ----- |
| 1    | IAM 사용자 생성 + 초기 비밀번호 설정   | Admin |
| 2    | 해당 그룹에 추가                       | Admin |
| 3    | 콘솔 URL, 사용자명, 초기 비밀번호 전달 | Admin |
| 4    | 첫 로그인 후 비밀번호 변경             | 본인  |
| 5    | 24시간 내 MFA 설정                     | 본인  |

※ MFA 설정 오류 발생 시 `QfeedSelfManagedMFA` 정책 연결 확인

### **8.3 팀원 오프보딩**

| 순서 | 작업                   | 시점     |
| ---- | ---------------------- | -------- |
| 1    | Access Key 비활성화    | 즉시     |
| 2    | 콘솔 비밀번호 비활성화 | 즉시     |
| 3    | 모든 그룹에서 제거     | 즉시     |
| 4    | IAM 사용자 삭제        | 1주일 후 |
| 5    | 오프보딩 기록          | 노션     |

---

## **9. 권한 요청 프로세스**

### **9.1 요청 절차**

```
요청자 (Discord #aws-권한-요청) → Admin 검토 → 승인 시 권한 부여 → 노션 기록
```

### **9.2 요청 템플릿**

```
[권한 요청]
- 요청자:
- 필요 권한:
- 사유:
```

---

## **10. 정기 점검**

### **10.1 점검 주기**

| 점검 항목         | 주기     | 담당  |
| ----------------- | -------- | ----- |
| 미사용 IAM 사용자 | 월 1회   | Admin |
| 미사용 Access Key | 월 1회   | Admin |
| MFA 미설정 사용자 | 월 1회   | Admin |
| 권한 적정성 검토  | 분기 1회 | Admin |

### **10.2 점검 방법**

```
IAM > 자격 증명 보고서 > 보고서 다운로드
```

### **10.3 점검 체크리스트**

- [ ] 30일 이상 미로그인 사용자 확인
- [ ] 30일 이상 미사용 Access Key 비활성화
- [ ] MFA 미설정 사용자에게 설정 요청
- [ ] 퇴사자 계정 잔존 여부 확인
- [ ] Root 계정 Access Key 없음 확인
- [ ] Root 계정 MFA 활성화 확인

---

## **11. 긴급 상황 대응**

### **11.1 Access Key 유출 시**

| 순서 | 작업                             |
| ---- | -------------------------------- |
| 1    | 해당 Access Key 즉시 비활성화    |
| 2    | CloudTrail에서 사용 이력 확인    |
| 3    | 무단 생성 리소스 삭제, 비용 확인 |
| 4    | 새 Access Key 발급 및 적용       |
| 5    | 사고 보고서 작성                 |

### **11.2 계정 탈취 의심 시**

| 순서 | 작업                                |
| ---- | ----------------------------------- |
| 1    | 비밀번호 + Access Key 즉시 비활성화 |
| 2    | Admin에게 보고                      |
| 3    | CloudTrail 로그 분석                |
| 4    | 필요시 AWS Support 연락             |

---

## **12. 서비스 역할 (Service Roles)**

AWS 리소스(EC2, Lambda 등)에 부여하는 IAM Role 정의.

### **12.1 EC2 Instance Role (prod)**

| Role 이름                     | 대상                       | 연결 정책                                                                   |
| ----------------------------- | -------------------------- | --------------------------------------------------------------------------- |
| `qfeed-prod-role-ec2-backend` | Backend 서버 (Spring Boot) | SSM, CloudWatch Logs, Parameter Store, ECR Pull, S3 uploads/audio 읽기/쓰기 |
| `qfeed-prod-role-ec2-ai`      | AI 서버 (FastAPI)          | SSM, CloudWatch Logs, Parameter Store, ECR Pull, S3 audio 읽기              |

### **12.2 EC2 Instance Role (dev)**

| Role 이름                    | 대상                       | 연결 정책                                                                        |
| ---------------------------- | -------------------------- | -------------------------------------------------------------------------------- |
| `qfeed-dev-role-ec2-backend` | Backend 서버 (Spring Boot) | SSM, CloudWatch Logs, Parameter Store, ECR Pull, `qfeed-dev-s3-*` 읽기/쓰기      |
| `qfeed-dev-role-ec2-ai`      | AI 서버 (FastAPI)          | SSM, CloudWatch Logs, Parameter Store, ECR Pull, `qfeed-dev-s3-*` 읽기/쓰기/삭제 |

※ dev 환경은 prod와 동일한 Role 구조 사용

### **12.3 CI/CD Role**

| Role 이름                        | 용도                           | 연결 정책                         |
| -------------------------------- | ------------------------------ | --------------------------------- |
| `qfeed-prod-role-github-actions` | GitHub Actions 프론트엔드 배포 | S3 static 쓰기, CloudFront 무효화 |

---
