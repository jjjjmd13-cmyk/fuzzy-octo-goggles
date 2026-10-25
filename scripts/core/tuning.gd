extends Node
## 밸런스 수치 창구 (autoload: Tuning). 게임 코드는 Tuning.data.<키> 로 읽는다.
## 테스트는 data 를 복제본으로 바꿔 빠른 수치로 돌릴 수 있다.

const BALANCE_PATH := "res://data/balance/balance.tres"

var data: Resource = load(BALANCE_PATH)
