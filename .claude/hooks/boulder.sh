#!/usr/bin/env bash
# oh-my-oda-agent — 완료 엔진 (OMO "Boulder" 재현)
#
# Claude Code Stop hook. Claude가 응답을 끝내려 할 때 발화한다.
# 평가 작업판(.omo/eval-plan.md)에 미완료 체크박스가 남아 있으면
#   exit 2 + stderr 로 "계속하라"는 메시지를 Claude에 전달해 멈추지 못하게 한다.
# 무한루프는 (1) 정체 감지 (2) 절대 시도 상한 으로 막는다 (OMO의 stagnation/상한 가드).
#
# 완료 신호 = 모든 체크박스가 [x] 또는 [~](막힘). 미완료 = [ ].

PROJECT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PLAN="$PROJECT/.omo/eval-plan.md"
STATE="$PROJECT/.omo/.boulder-state"

# 작업판이 없으면 평가 모드가 아님 → 정상 종료 허용
[ -f "$PLAN" ] || exit 0

# 미완료 체크박스 개수 ( - [ ] ). [x](완료)·[~](막힘)는 제외된다.
INCOMPLETE=$(grep -cE '^[[:space:]]*- \[ \]' "$PLAN" 2>/dev/null || true)
INCOMPLETE=${INCOMPLETE:-0}

# 모두 완료 → 종료 허용 + 상태 리셋
if [ "$INCOMPLETE" -eq 0 ]; then
  rm -f "$STATE"
  exit 0
fi

# --- 무한루프 가드: 상태 파일 = "이전미완료 정체횟수 총시도" ---
if [ -f "$STATE" ]; then
  read -r PREV STALL TOTAL < "$STATE"
else
  PREV=-1; STALL=0; TOTAL=0
fi
TOTAL=$((TOTAL + 1))

# (가드 1) 절대 시도 상한: 20회 초과 → 포기하고 종료 허용
if [ "$TOTAL" -gt 20 ]; then
  rm -f "$STATE"
  exit 0
fi

# 진전 체크: 미완료가 줄었으면 정체 리셋, 아니면 정체++
if [ "$PREV" -eq -1 ] || [ "$INCOMPLETE" -lt "$PREV" ]; then
  STALL=0
else
  STALL=$((STALL + 1))
fi
echo "$INCOMPLETE $STALL $TOTAL" > "$STATE"

# (가드 2) 정체 3회(진전 없이 같은 자리) → 종료 허용 (사람 개입 유도)
if [ "$STALL" -ge 3 ]; then
  rm -f "$STATE"
  exit 0
fi

# 미완료 항목 목록 (최대 10개)
PENDING=$(grep -E '^[[:space:]]*- \[ \]' "$PLAN" | sed -E 's/^[[:space:]]*- \[ \][[:space:]]*/  - /' | head -10)

# --- Block: exit 2 + stderr → Claude가 계속 작업 ---
{
  echo "[완료 엔진] 평가 작업판에 미완료 항목이 ${INCOMPLETE}개 남았습니다. 멈추지 말고 계속 진행하세요."
  echo ""
  echo "미완료 항목:"
  echo "${PENDING}"
  echo ""
  echo "각 항목을 끝내면 ${PLAN} 의 해당 체크박스를 [x]로 바꾸세요."
  echo "외부 자료 대기 등으로 정말 더 진행할 수 없으면, 막힌 항목을 [~]로 바꾸고 사유를 적으세요(미완료에서 제외됩니다)."
} >&2
exit 2
