# Kotlin 관용구 & 언어 기능 — 상세 패턴

## !! (Non-null assertion) — P1

`!!`는 런타임 NPE를 명시적으로 허용하는 선언이다. Kotlin의 null 안전성을 포기하는 것과 같다.
대부분의 경우 더 안전한 대안이 존재한다.

```kotlin
// Bad
val name = user!!.name

// Good — 안전 호출
val name = user?.name ?: "unknown"

// Good — 진입점 검증
val user = userRepository.findById(id) ?: throw UserNotFoundException(id)
val name = user.name  // 이후 !! 불필요

// Good — 명시적 단언이 필요한 경우 requireNotNull 사용 (메시지 포함)
val config = requireNotNull(environment.getProperty("app.key")) { "app.key must be configured" }
```

**예외**: 테스트 코드에서 lateinit var 대신 `!!`를 가끔 쓰는 것은 P3 수준.
**예외**: `!!`가 논리적으로 절대 null이 될 수 없음을 증명할 수 있는 경우 P2로 낮춰 판단.

---

## val vs var — P2

Kotlin에서 불변성은 기본 원칙이다. `var`는 상태 변경이 명백히 필요할 때만 사용한다.

```kotlin
// Bad
var count = 0
count = items.size

// Good
val count = items.size

// Bad — 루프에서 누적
var total = 0.0
for (item in items) {
    total += item.price
}

// Good — fold/sum 활용
val total = items.sumOf { it.price }
```

**주의**: Spring `@Component` 클래스에서 `lateinit var`는 DI 때문에 필요한 경우가 있으므로
생성자 주입이 가능한지 먼저 확인 후 판단한다.

---

## Nullable vs 빈 컬렉션 — P2

함수의 반환 타입에서 `null`과 빈 컬렉션(`emptyList()`)의 의미는 다르다.
혼용하면 호출부에서 null 체크와 빈 컬렉션 체크를 둘 다 해야 한다.

```kotlin
// Bad — "결과 없음"과 "오류"를 같은 방식으로 표현
fun findOrders(userId: Long): List<Order>? {
    return if (userExists(userId)) orderRepository.findByUserId(userId) else null
}

// Good — 빈 리스트로 "결과 없음"을 표현
fun findOrders(userId: Long): List<Order> {
    if (!userExists(userId)) throw UserNotFoundException(userId)
    return orderRepository.findByUserId(userId)
}
```

규칙: 컬렉션을 반환하는 함수는 가능하면 `emptyList()`를 반환하고, `null`은 "존재하지 않음"의 의미가 명확한 단일 객체 반환에만 사용한다.

---

## data class를 Entity에 사용 — P2

JPA Entity에 `data class`를 쓰면 두 가지 문제가 생긴다.

1. **`equals`/`hashCode`가 모든 필드 기반** — Hibernate 프록시는 실제 Entity와 `equals`가 false
2. **`copy()`로 JPA 추적 밖에서 변경** — 변경 감지(dirty checking)가 동작하지 않을 수 있음

```kotlin
// Bad
@Entity
data class Order(
    @Id val id: Long = 0,
    val status: OrderStatus,
)

// Good — 일반 class, equals/hashCode를 id 기반으로 직접 구현
@Entity
class Order(
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0,

    var status: OrderStatus,
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is Order) return false
        return id != 0L && id == other.id
    }

    override fun hashCode() = id.hashCode()
}
```

**예외**: JPA와 관계없는 도메인 객체(Value Object)나 DTO에는 `data class`가 적합하다.

---

## 스코프 함수 선택 — P3

스코프 함수는 의미에 맞게 선택한다. 혼용하면 코드 의도를 파악하기 어렵다.

| 함수 | 수신 객체 참조 | 반환값 | 주 용도 |
|------|------------|-------|--------|
| `let` | `it` | 람다 결과 | nullable 처리, 변환 |
| `run` | `this` | 람다 결과 | 객체 설정 후 결과 반환 |
| `apply` | `this` | 수신 객체 | 객체 초기화·설정 (빌더 패턴) |
| `also` | `it` | 수신 객체 | 부수 효과 (로깅, 검증) |
| `with` | `this` | 람다 결과 | 비확장: 여러 연산을 한 블록에서 |

```kotlin
// Bad — let을 초기화에 사용 (apply가 적합)
val request = CreateOrderRequest(productId = 1L, quantity = 3).let {
    it.copy(quantity = it.quantity * 2)
}

// Good — apply로 초기화
val builder = StringBuilder().apply {
    append("Hello")
    append(", ")
    append("World")
}

// Good — let으로 nullable 처리
user?.let { sendWelcomeEmail(it) }

// Good — also로 로깅 부수 효과
return orderRepository.save(order).also {
    logger.info("Order created: ${it.id}")
}
```

---

## when expression 활용 — P3

분기가 3개 이상인 if-else 체인은 `when`으로 대체하면 가독성이 높아진다.
`when`을 expression으로 사용하면 컴파일러가 모든 경우를 처리했는지 검사한다(sealed class/enum).

```kotlin
// Bad
fun describe(status: OrderStatus): String {
    if (status == OrderStatus.CREATED) return "주문 생성됨"
    else if (status == OrderStatus.PAID) return "결제 완료"
    else if (status == OrderStatus.SHIPPED) return "배송 중"
    else return "알 수 없음"
}

// Good — when expression (sealed class면 else 불필요)
fun describe(status: OrderStatus): String = when (status) {
    OrderStatus.CREATED -> "주문 생성됨"
    OrderStatus.PAID -> "결제 완료"
    OrderStatus.SHIPPED -> "배송 중"
    OrderStatus.CANCELLED -> "취소됨"
}
```

새로운 enum 값이 추가될 때 `else` 없는 `when`은 컴파일 에러가 발생하므로 누락을 방지할 수 있다.

---

## 확장 함수 위치 — P4

확장 함수는 가능하면 확장 대상 클래스와 같은 패키지에 두거나, 사용처와 가까운 파일에 둔다.
전역 유틸리티 파일에 모두 몰아넣으면 탐색이 어렵다.

```kotlin
// Bad — 모든 확장 함수를 Extensions.kt 하나에
// com/example/util/Extensions.kt
fun Order.toResponse() = ...
fun User.toDto() = ...
fun String.isValidEmail() = ...

// Good — 관련 파일 옆에 배치
// com/example/order/OrderExtensions.kt
fun Order.toResponse() = OrderResponse(id = id, status = status)

// Good — 간단한 변환은 companion object나 파일 내부에
// com/example/order/Order.kt
fun Order.toResponse() = OrderResponse(id = id, status = status)
```
