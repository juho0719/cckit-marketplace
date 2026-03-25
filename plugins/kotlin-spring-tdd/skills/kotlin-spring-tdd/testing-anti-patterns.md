# Kotlin + Spring Boot + Kotest 테스트 안티패턴

**이 파일을 읽어야 할 때:** 테스트를 작성하거나 수정할 때, Mock을 추가할 때, 테스트가 이상하게 동작할 때.

**핵심 원칙:** 테스트는 실제 동작을 검증해야 한다. Mock은 격리 수단이지, 테스트 대상이 아니다.

---

## 안티패턴 1: 과도한 Mock (Over-Mocking)

**안티패턴:**
```kotlin
class OrderServiceTest : BehaviorSpec({
    // 의존성이 너무 많으면 클래스의 책임이 과도한 것
    val repo = mockk<OrderRepository>()
    val validator = mockk<OrderValidator>()
    val mapper = mockk<OrderMapper>()
    val eventPublisher = mockk<ApplicationEventPublisher>()
    val notifier = mockk<NotificationService>()
    val logger = mockk<Logger>()  // 로거까지 Mock?
    // ...
})
```

**해결:** Mock이 3개 이상이면 클래스의 책임이 과도한 신호다. 클래스를 분리하거나 설계를 재검토하라.

---

## 안티패턴 2: 구현에 결합된 테스트

**안티패턴:**
```kotlin
Then("주문이 생성된다") {
    // 내부 호출 순서까지 검증 — 리팩토링할 때마다 테스트가 깨진다
    verifySequence {
        validator.validate(request)
        mapper.toEntity(request)
        repo.save(any())
        mapper.toResponse(any())
        eventPublisher.publishEvent(any())
    }
}
```

**해결:** 결과(output)를 검증하라. 내부 호출 순서는 구현 세부사항이다.

```kotlin
Then("주문이 생성된다") {
    result.status shouldBe OrderStatus.CREATED
    result.productId shouldBe request.productId
    // 꼭 필요한 경우만 verify
    verify(exactly = 1) { repo.save(any()) }
}
```

---

## 안티패턴 3: 테스트 간 의존성

**안티패턴:**
```kotlin
// 테스트 실행 순서에 의존 — 순서가 바뀌면 실패
Given("주문이 생성된 상태에서") {  // 이전 테스트가 DB에 데이터를 넣었다고 가정
    When("주문을 조회하면") { ... }
}
```

**해결:** 각 테스트는 독립적이어야 한다. `beforeEach`로 상태를 초기화하라.

```kotlin
beforeEach { orderRepository.deleteAll() }

Given("주문 ID 1번이 존재할 때") {
    val saved = orderRepository.save(Order(...))  // 직접 생성
    When("주문을 조회하면") { ... }
}
```

---

## 안티패턴 4: 과도한 @SpringBootTest 사용

**안티패턴:**
```kotlin
@SpringBootTest  // 전체 컨텍스트 로드 — 느리고 불필요한 빈들이 초기화됨
class OrderServiceTest : BehaviorSpec({ ... })
```

**해결:** 테스트 대상에 맞는 어노테이션을 선택하라.

| 테스트 대상 | 사용할 방법 |
|------------|------------|
| Service 로직 | 어노테이션 없음 — 순수 단위 테스트 + MockK |
| Controller | `@WebMvcTest(XxxController::class)` |
| Repository | `@DataJpaTest` |
| 전체 흐름 | `@SpringBootTest` (통합 테스트만) |

---

## 안티패턴 5: 매직 넘버 / 불명확한 테스트 데이터

**안티패턴:**
```kotlin
Given("42번 상품 7개 주문") {
    val request = CreateOrderRequest(42L, 7)  // 42와 7이 왜?
    When("주문 생성") {
        Then("총액이 49000원") {
            result.totalPrice shouldBe 49000  // 49000은 어디서?
        }
    }
}
```

**해결:** 의미 있는 변수명을 사용하고, 기대값은 하드코딩하라.

```kotlin
Given("단가 10000원인 상품을 3개 주문할 때") {
    val productId = 1L
    val quantity = 3
    val unitPrice = 10_000L
    every { productRepo.findByIdOrNull(productId) } returns Product(id = productId, price = unitPrice)

    When("주문을 생성하면") {
        val result = service.createOrder(CreateOrderRequest(productId, quantity))

        Then("총액은 30000원이다") {
            result.totalPrice shouldBe 30_000L  // 10000 * 3, 명확함
        }
    }
}
```

---

## 안티패턴 6: try-catch로 예외 테스트

**안티패턴:**
```kotlin
Then("예외가 발생한다") {
    try {
        service.getOrder(999L)
        fail("예외가 발생해야 한다")
    } catch (e: OrderNotFoundException) {
        e.message shouldContain "999"
    }
}
```

**해결:** Kotest의 `shouldThrow`를 사용하라.

```kotlin
Then("OrderNotFoundException이 발생한다") {
    val exception = shouldThrow<OrderNotFoundException> {
        service.getOrder(999L)
    }
    exception.message shouldContain "999"
}
```

---

## 안티패턴 7: 프로덕션 로직 복제

**안티패턴:**
```kotlin
Then("할인 금액이 올바르다") {
    val price = 10_000L
    val discountRate = 0.1
    // 프로덕션과 동일한 계산을 테스트에서 반복 — 같은 버그가 양쪽에 생긴다
    val expected = (price * (1 - discountRate)).toLong()
    result.discountedPrice shouldBe expected
}
```

**해결:** 기대값을 하드코딩하라. 테스트는 "무엇"을 검증하는 것이지 "어떻게"를 반복하는 것이 아니다.

```kotlin
Then("10000원에 10% 할인 시 9000원이 된다") {
    result.discountedPrice shouldBe 9_000L
}
```

---

## 안티패턴 8: 불필요한 relaxed mock

**안티패턴:**
```kotlin
// relaxed = true는 모든 메서드가 기본값을 반환 — 잘못된 호출도 감지 못함
val service = mockk<OrderService>(relaxed = true)
service.createOrder(request)  // 아무것도 검증하지 않음
```

**해결:** 필요한 행동만 명시적으로 정의하라. `relaxed`는 반환값이 중요하지 않은 void 메서드에만 사용.

```kotlin
val service = mockk<OrderService>()
every { service.createOrder(any()) } returns response
// 이제 예상치 못한 호출은 오류로 처리됨
```

---

## 안티패턴 9: 불명확한 테스트 이름

**안티패턴:**
```kotlin
Given("test1") { When("run") { Then("ok") { ... } } }
Given("주문") { When("생성") { Then("성공") { ... } } }
```

**해결:** "[상황]에서 [행동]하면 [결과]한다" 패턴으로 작성하라.

```kotlin
Given("재고가 부족한 상품에 대한 주문 요청이 있을 때") {
    When("주문을 생성하면") {
        Then("InsufficientStockException이 발생한다") { ... }
    }
}

Given("유효한 주문이 존재할 때") {
    When("주문을 취소하면") {
        Then("주문 상태가 CANCELLED로 변경된다") { ... }
    }
}
```

---

## 안티패턴 10: 테스트 없이 리팩토링

**안티패턴:**
```
"간단한 리팩토링이니까 테스트 없이 해도 돼"
"이름만 바꾸는 건데 테스트가 필요해?"
```

**해결:** 리팩토링 전후로 반드시 테스트를 실행하라.

```bash
# 리팩토링 전 — 현재 상태 확인
./gradlew test
# PASS 확인

# 리팩토링 수행

# 리팩토링 후 — 동작이 유지되는지 확인
./gradlew test
# 여전히 PASS여야 함
```

리팩토링 후 테스트가 깨지면 즉시 되돌린다. 리팩토링 중에 새로운 기능을 추가하지 않는다.

---

## 빠른 참조

| 안티패턴 | 해결 |
|----------|------|
| Mock이 3개 이상 | 클래스 책임 분리 |
| 호출 순서 검증 | 결과(output) 검증으로 대체 |
| 테스트 간 공유 상태 | `beforeEach`에서 초기화 |
| 전부 @SpringBootTest | 적절한 슬라이스 테스트 사용 |
| 매직 넘버 | 의미 있는 변수명 + 하드코딩된 기대값 |
| try-catch 예외 | `shouldThrow<>` 사용 |
| 로직 복제 | 기대값 하드코딩 |
| relaxed mock 남용 | 명시적 `every {}` 정의 |
| 불명확한 이름 | Given/When/Then 서술형 |
| 테스트 없이 리팩토링 | 전후 `./gradlew test` 실행 |
