# oh-my-oda-agent

> **OMO(oh-my-openagent)의 멀티 에이전트 설계 원리를 ODA(공적개발원조) 평가 도메인에 적용한 학습·실험 프로젝트.**
> KOICA 평가 업무를 보조하는 agent 팀을 [Claude Code](https://claude.com/claude-code) 위에서 슬라이스 단위로 직접 구현했다.

코딩 에이전트인 OMO를 그대로 가져오는 대신 **도메인 무관 설계 원리만 이식**한다 — 역할=권한, 근거 게이트, Rules 주입, 병렬 다각도, 검증, 완료 강제, 사람 게이트. 평가 기준·척도·규정은 **실제 KOICA 평가지침(2024)·사업평가 규정(제536호)** 기반(`reference/`).

---

## 🎛️ 시스템 구성 — 11 에이전트, 두 평가 유형

KOICA 평가는 **유형이 다르다.** 이 시스템은 두 유형을 구분해 다룬다.

### ① 종료평가 (Final Evaluation) — 사업을 6기준으로 평정 → **A~F 등급**

```
평가 요청 → [평가총괄: CLAUDE.md가 KOICA 기준·규정 주입]
  ▼ 6기준 평가관 병렬 (읽기전용, 각자 1~4점 + 근거; 근거 없으면 "평가 불가")
     적절성·일관성·효과성·효율성·지속가능성  [+CTS 사업은 타당성]
  ▼ quality-verifier        근거 원문 대조 + 점수–근거 정합성
  ▼ 종합점수 → A~F 등급(안)  (평가 불가 기준 있으면 단정 보류)
  ▼ report-composer(작성) → narrative-verifier(서술 검증) → report-quality-inspector(24문항 품질심사)
  ▼ 사람(평가담당관) 확정
```

### ② 영향평가 (Impact Evaluation) — 인과효과 측정 → **적합/조건부/부적합 (등급 없음)**

```
영향평가 보고서 → impact-evaluation-reviewer
  ▼ 5축(과학성·실용성·투명성·윤리성·포용성) / 10질문(인과식별·반사실·선택편의·강건성…)
  ▼ 적합 / 조건부 보완 / 부적합  + 🚩 기술검토(계량) 권고
  ▼ 사람(평가실·품질검토위) 확정
```

> ⚠️ 종료평가의 6기준 틀을 영향평가에 들이대지 않는다 — **평가 유형을 구분**하는 것이 핵심.

### 에이전트 카탈로그 (11)

| 역할 | 에이전트 | 권한 |
|------|---------|:---:|
| 종료평가 6기준 | `dac-{relevance,coherence,effectiveness,efficiency,sustainability}-evaluator` + `cts-validity-evaluator` | 읽기 |
| 근거 검증 | `quality-verifier` | 읽기 |
| 보고서 작성 | `report-composer` | **쓰기** |
| 서술 검증 (환각·일관성) | `narrative-verifier` | 읽기 |
| 보고서 품질심사 (24문항/A~D) | `report-quality-inspector` | 읽기 |
| 영향평가 검토 (5축/10질문) | `impact-evaluation-reviewer` | 읽기 |

\+ **완료 엔진** (`.claude/hooks/boulder.sh`, Stop hook): 작업판에 미완료가 남으면 끝까지 굴린다 (OMO Boulder).

## 🧬 OMO 원리 → 이 시스템

| OMO 원리 | 구현 |
|---------|------|
| **병렬 다각도** (hyperplan) | 6기준 평가관이 서로 다른 관점으로 병렬 평가 |
| **역할 = 권한** | 평가관·검증자는 읽기전용 / `report-composer`만 쓰기 |
| **근거 게이트** | "근거 없으면 등급 없음 / 서술 없음" (지어내기 금지) |
| **완료 주장 불신** | `quality-verifier`·`narrative-verifier`가 근거·일관성 검증 |
| **완료 강제** (Boulder) | 완료 엔진(Stop hook) — 정체·상한 가드 포함 |
| **Rules 주입** | `CLAUDE.md` = KOICA 2024 지침 + 규정 제536호 자동 주입 |
| **사람 게이트** *(공공기관 특수, 신규)* | 최종 등급·판정은 AI가 못 함, 사람 몫 |

> OMO의 코딩 전용 부품(Hashline·모델별 변형)은 도메인상 생략. "근거 없으면 등급 없음"과 "사람 게이트"라는 **공공기관 평가 특유의 안전장치**를 더했다.

## ▶️ 써보기

```bash
cd oh-my-oda-agent
claude        # 처음엔 settings.json의 Stop hook 승인
```
- **종료평가**: `samples/sample-evaluation-report.md 이 사업을 DAC 기준으로 평가해줘`
- **영향평가**: `이 영향평가 보고서를 검토해줘` → `impact-evaluation-reviewer`가 인과추론·방법론을 심사
- **보고서 품질심사**: `이 평가보고서 품질을 검토해줘` → 24문항/A~D

## ✅ 검증 (Validation)

실제로 작동하고 실제 KOICA 평가와 부합하는지의 기록 → **[`docs/validation-log.md`](docs/validation-log.md)**

- **실물 e2e 2회** — headless `claude`로 실제 `.claude/agents/*` 호출 확인 (시뮬레이션 아님)
- **실제 보고서 4건 대조** — 캄보디아(등급 일치)·미얀마(기준별 방향 일치)·파키스탄(약점 방향 일치)·베트남(평가 유형 구분)
- **게이트 실증** — 근거 없으면 평가 불가·종합 보류·사람 게이트가 실제로 작동
- ⚠️ 학습·실험 자체검증(표본 소수). 전문가 교차검증·표본 확대는 진행 과제.

## 🗺️ 로드맵

- ✅ **슬라이스 1~1.6**: 효과성 평가관 → KOICA 길라잡이 2024 반영 (DAC 6대 기준, A~F 공식 등급척도, 4점 루브릭)
- ✅ **슬라이스 2 / 2.5**: 6기준 병렬 평가팀 + 종합점수→A~F (`hyperplan` 재현) / CTS 타당성 평가관 추가
- ✅ **슬라이스 3**: 완료 엔진 — Stop hook으로 긴/다건 평가를 끝까지 (OMO Boulder)
- ✅ **슬라이스 4**: 평가보고서 품질심사관 — 보고서를 24문항/A~D로 심사 (메타 평가)
- ✅ **슬라이스 5**: 보고서 작성 지원 — `report-composer`(쓰기) + `narrative-verifier`. "근거 없으면 서술 없음"
- ✅ **슬라이스 6**: 영향평가 검토 모듈 + 사업평가 규정(제536호) 규정 근거 주입
- ✅ **슬라이스 7**: 품질심사관 공식 v2 반영 — 「평가품질검토 가이드라인 v2」(2025.6)로 갱신. **Pass 경계 70→60 교정**, 세부항목 v2 명칭·매핑, 총평 200자, 평가용역 종합등급 산정표 신설
- 설계 전체 그림: `../analysis/03-KOICA-사업평가-Agent팀-설계서.md`

## 📚 reference (KOICA 공식 자료 다이제스트)

원본 PDF·HWP는 저작권 고려해 미포함(`.gitignore`), 추출 다이제스트만 보관:
- `KOICA-평가지침-2024-다이제스트.md` (종료평가 기준·등급척도) / `KOICA-평가지침-다이제스트.md` (2017 구버전)
- `KOICA-품질검토-체크리스트.md` (24문항/A~D)
- `KOICA-영향평가-가이드라인-다이제스트.md` (KIEP 2025)
- `KOICA-사업평가규정-다이제스트.md` (규정 제536호, 2025.2 — 우리 시스템의 규정적 근거)

## 📌 출처 / 라이선스

[oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent)를 리버스 엔지니어링해 얻은 **설계 원리에서 영감**을 받았다. OMO 소스 코드를 포함하지 않으며(파생물 아님), 아이디어·패턴만 참고. 평가 기준·규정은 KOICA 공식 자료에서 추출(원본 미포함, 다이제스트만). 학습·실험용 개인 프로젝트.
