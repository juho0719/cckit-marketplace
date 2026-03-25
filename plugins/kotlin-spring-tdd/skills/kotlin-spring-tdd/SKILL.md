---
name: kotlin-spring-tdd
description: |
  Kotlin + Spring Boot 프로젝트를 위한 체계적 TDD 스킬. RED → GREEN → REFACTOR 사이클을 엄격하게 따르며,
  Kotest + MockK 기반으로 테스트를 작성한다.

  다음 상황에서 반드시 이 스킬을 사용하라:
  - "테스트 먼저 작성해줘", "TDD로 개발해줘", "TDD로 구현해줘"
  - "Kotlin 테스트 작성", "Spring Boot 테스트", "Kotest로 테스트"
  - "단위 테스트", "통합 테스트", "컨트롤러 테스트", "서비스 테스트"
  - "MockK로 테스트", "BehaviorSpec", "FunSpec"
  - "WebMvcTest", "DataJpaTest", "SpringBootTest"
  - "RED-GREEN-REFACTOR", "테스트 주도 개발"
  - Kotlin + Spring Boot 프로젝트에서 테스트를 작성하거나 추가하는 모든 상황
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# Kotlin + Spring Boot TDD

## 철의 법칙 (Iron Law)

> **실패하는 테스트 없이 프로덕션 코드를 작성하지 않는다.**
>
> 테스트를 먼저 작성하라. 실패를 확인하라. 통과시킬 최소한의 코드만 작성하라.

컴파일 에러도 RED다. 테스트가 실패하는 것을 눈으로 확인하지 않으면, 그 테스트가 올바른 것을 검증하는지 알 수 없다.

---

## 핵심 원칙

1. **테스트가 설계를 이끈다** — 테스트를 먼저 작성하면 자연스럽게 좋은 API가 나온다
2. **최소 구현** — 테스트를 통과시킬 최소한의 코드만 작성한다
3. **리팩토링은 GREEN 이후에만** — 모든 테스트가 통과한 상태에서만 개선한다
4. **각 단계를 반드시 검증한다** — RED/GREEN/REFACTOR 각 단계에서 `./gradlew test`를 실행한다

---

## 기술 스택

| 영역 | 기술 |
|------|------|
| 언어 | Kotlin |
| 프레임워크 | Spring Boot |
| 테스트 프레임워크 | **Kotest** (BehaviorSpec, FunSpec, StringSpec) |
| Mock 라이브러리 | MockK |
| Spring 통합 | kotest-extensions-spring + SpringExtension |
| Spring Mock | @MockkBean (springmockk) |
| 빌드 도구 | Gradle (Kotlin DSL) |
| 커버리지 | JaCoCo |

### Gradle 의존성

```kotlin
// build.gradle.kts
dependencies {
    // Kotest
    testImplementation("io.kotest:kotest-runner-junit5:5.x.x")
    testImplementation("io.kotest:kotest-assertions-core:5.x.x")
    testImplementation("io.kotest.extensions:kotest-extensions-spring:1.x.x")

    // MockK
    testImplementation("io.mockk:mockk:1.x.x")
    testImplementation("com.ninja-squad:springmockk:4.x.x")  // @MockkBean

    // Spring Boot Test
    testImplementation("org.springframework.boot:spring-boot-starter-test") {
        exclude(module = "mockito-core")  // MockK 사용 시 Mockito 제외
    }
}

tasks.withType<Test> {
    useJUnitPlatform()
}
```

---

## TDD 사이클

```
인터페이스 설계 → RED → GREEN → REFACTOR
                   ↑                  ↓
                   └──────────────────┘
```

### Step 1: 인터페이스 설계 (Interface First)

구현 전에 공개 API(메서드 시그니처, DTO, 엔드포인트)를 먼저 정의한다.

```kotlin
// 구현하지 않는다. 시그니처만 정의.
interface OrderService {
    fun createOrder(request: CreateOrderRequest): OrderResponse
    fun getOrder(id: Long): OrderResponse
}

data class CreateOrderRequest(
    val productId: Long,
    val quantity: Int,
)

data class OrderResponse(
    val id: Long,
    val productId: Long,
    val quantity: Int,
    val status: OrderStatus,
)

enum class OrderStatus { CREATED, COMPLETED, CANCELLED }
```

### Step 2: RED — 실패하는 테스트 작성

```kotlin
class OrderServiceTest : BehaviorSpec({
    val orderRepository = mockk<OrderRepository>()
    val orderService = OrderServiceImpl(orderRepository)

    Given("유효한 주문 요청이 있을 때") {
        val request = CreateOrderRequest(productId = 1L, quantity = 3)
        val savedOrder = Order(id = 1L, productId = 1L, quantity = 3, status = OrderStatus.CREATED)
        every { orderRepository.save(any()) } returns savedOrder

        When("주문을 생성하면") {
            val result = orderService.createOrder(request)

            Then("상품 ID, 수량, CREATED 상태로 저장된다") {
                result.productId shouldBe 1L
                result.quantity shouldBe 3
                result.status shouldBe OrderStatus.CREATED
            }
        }
    }
})
```

**검증 (필수):**
```bash
./gradlew test --tests "*OrderServiceTest"
# FAIL — OrderServiceImpl이 없으니 컴파일 에러 또는 테스트 실패
```

> 테스트가 올바른 이유로 실패하는지 확인한다. "클래스를 찾을 수 없음"이나 "메서드 미구현"이 예상되는 실패다.

### Step 3: GREEN — 최소 구현

```kotlin
class OrderServiceImpl(
    private val orderRepository: OrderRepository,
) : OrderService {

    override fun createOrder(request: CreateOrderRequest): OrderResponse {
        val order = Order(
            productId = request.productId,
            quantity = request.quantity,
            status = OrderStatus.CREATED,
        )
        val saved = orderRepository.save(order)
        return saved.toResponse()
    }
}
```

**검증 (필수):**
```bash
./gradlew test --tests "*OrderServiceTest"
# PASS — 테스트 통과 확인
```

> 과도한 구현 금지. 테스트가 요구하지 않는 로직은 추가하지 않는다.

### Step 4: REFACTOR — 개선

GREEN 상태에서만 리팩토링한다. 중복 제거, 네이밍 개선, Kotlin 관용구 적용.

```kotlin
// 확장 함수로 변환 로직 분리
private fun Order.toResponse() = OrderResponse(
    id = id,
    productId = productId,
    quantity = quantity,
    status = status,
)
```

**검증 (필수):**
```bash
./gradlew test
# 여전히 PASS — 리팩토링이 동작을 바꾸지 않았음을 확인
```

> 리팩토링 중 테스트가 깨지면 즉시 되돌린다.

---

## 파일 네이밍 규칙

```
src/main/kotlin/com/example/order/
├── controller/OrderController.kt
├── service/OrderService.kt              # interface
├── service/OrderServiceImpl.kt          # 구현체
├── repository/OrderRepository.kt
├── domain/Order.kt
└── dto/CreateOrderRequest.kt

src/test/kotlin/com/example/order/
├── service/OrderServiceTest.kt          # BehaviorSpec + MockK (단위)
├── controller/OrderControllerTest.kt    # FunSpec + @WebMvcTest
├── repository/OrderRepositoryTest.kt    # StringSpec + @DataJpaTest
└── integration/OrderIntegrationTest.kt  # BehaviorSpec + @SpringBootTest
```

---

## 테스트 유형별 가이드

### Kotest Spec 스타일 선택 기준

| Spec | 구조 | 권장 사용처 |
|------|------|------------|
| **BehaviorSpec** | Given / When / Then | Service 단위 테스트, 통합 테스트 |
| **FunSpec** | test("설명") { } | Controller 테스트, 간단한 단위 테스트 |
| **StringSpec** | "설명" { } | Repository 테스트, 단순 검증 |

### 1. Service 단위 테스트 (BehaviorSpec + MockK)

```kotlin
class OrderServiceTest : BehaviorSpec({
    val orderRepository = mockk<OrderRepository>()
    val orderService = OrderServiceImpl(orderRepository)

    Given("유효한 주문 요청이 있을 때") {
        val request = CreateOrderRequest(productId = 1L, quantity = 3)
        val savedOrder = Order(id = 1L, productId = 1L, quantity = 3, status = OrderStatus.CREATED)
        every { orderRepository.save(any()) } returns savedOrder

        When("주문을 생성하면") {
            val result = orderService.createOrder(request)

            Then("상품 ID와 수량이 저장된다") {
                result.productId shouldBe 1L
                result.quantity shouldBe 3
                result.status shouldBe OrderStatus.CREATED
            }

            Then("리포지토리에 한 번 저장된다") {
                verify(exactly = 1) { orderRepository.save(any()) }
            }
        }
    }

    Given("존재하지 않는 주문 ID로 조회할 때") {
        every { orderRepository.findByIdOrNull(999L) } returns null

        When("주문을 조회하면") {
            Then("OrderNotFoundException이 발생한다") {
                shouldThrow<OrderNotFoundException> {
                    orderService.getOrder(999L)
                }
            }
        }
    }
})
```

### 2. Controller 테스트 (FunSpec + @WebMvcTest)

```kotlin
@WebMvcTest(OrderController::class)
class OrderControllerTest(
    @Autowired private val mockMvc: MockMvc,
    @MockkBean private val orderService: OrderService,
) : FunSpec() {

    init {
        extensions(SpringExtension)

        test("POST /api/orders - 유효한 요청 시 201 Created를 반환한다") {
            val response = OrderResponse(id = 1L, productId = 1L, quantity = 3, status = OrderStatus.CREATED)
            every { orderService.createOrder(any()) } returns response

            mockMvc.post("/api/orders") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"productId": 1, "quantity": 3}"""
            }.andExpect {
                status { isCreated() }
                jsonPath("$.productId") { value(1) }
                jsonPath("$.quantity") { value(3) }
                jsonPath("$.status") { value("CREATED") }
            }
        }

        test("POST /api/orders - 잘못된 요청 시 400 Bad Request를 반환한다") {
            mockMvc.post("/api/orders") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"productId": null, "quantity": -1}"""
            }.andExpect {
                status { isBadRequest() }
            }
        }
    }
}
```

### 3. Repository 테스트 (StringSpec + @DataJpaTest)

```kotlin
@DataJpaTest
class OrderRepositoryTest(
    @Autowired private val orderRepository: OrderRepository,
) : StringSpec() {

    init {
        extensions(SpringExtension)

        "주문을 저장하고 ID로 조회할 수 있다" {
            val order = Order(productId = 1L, quantity = 3, status = OrderStatus.CREATED)

            val saved = orderRepository.save(order)
            val found = orderRepository.findByIdOrNull(saved.id)

            found shouldNotBe null
            found!!.productId shouldBe 1L
            found.quantity shouldBe 3
        }

        "상태별 주문 목록을 조회할 수 있다" {
            orderRepository.saveAll(listOf(
                Order(productId = 1L, quantity = 1, status = OrderStatus.CREATED),
                Order(productId = 2L, quantity = 2, status = OrderStatus.COMPLETED),
                Order(productId = 3L, quantity = 3, status = OrderStatus.CREATED),
            ))

            val createdOrders = orderRepository.findAllByStatus(OrderStatus.CREATED)

            createdOrders shouldHaveSize 2
        }
    }
}
```

### 4. 통합 테스트 (BehaviorSpec + @SpringBootTest)

```kotlin
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class OrderIntegrationTest(
    @Autowired private val testRestTemplate: TestRestTemplate,
    @Autowired private val orderRepository: OrderRepository,
) : BehaviorSpec() {

    init {
        extensions(SpringExtension)

        beforeEach { orderRepository.deleteAll() }

        Given("유효한 주문 데이터가 있을 때") {
            val request = CreateOrderRequest(productId = 1L, quantity = 3)

            When("주문을 생성하고 조회하면") {
                val createResponse = testRestTemplate.postForEntity(
                    "/api/orders", request, OrderResponse::class.java
                )
                val orderId = createResponse.body!!.id
                val getResponse = testRestTemplate.getForEntity(
                    "/api/orders/$orderId", OrderResponse::class.java
                )

                Then("생성된 주문을 정상적으로 조회할 수 있다") {
                    createResponse.statusCode shouldBe HttpStatus.CREATED
                    getResponse.statusCode shouldBe HttpStatus.OK
                    getResponse.body!!.productId shouldBe 1L
                    getResponse.body!!.quantity shouldBe 3
                }
            }
        }
    }
}
```

---

## MockK 가이드

```kotlin
// Mock 생성
val repo = mockk<OrderRepository>()
val repo = mockk<OrderRepository>(relaxed = true)  // 기본값 반환 (void 메서드에만 사용)

// 행동 정의
every { repo.save(any()) } returns savedOrder
every { repo.findByIdOrNull(1L) } returns order
every { repo.findByIdOrNull(999L) } returns null
every { repo.delete(any()) } throws IllegalStateException("삭제 불가")

// suspend 함수
coEvery { service.processAsync(any()) } returns result

// 검증
verify(exactly = 1) { repo.save(any()) }
verify(exactly = 0) { repo.delete(any()) }
coVerify { service.processAsync(any()) }

// 인자 캡처
val slot = slot<CreateOrderRequest>()
every { service.createOrder(capture(slot)) } returns response
// slot.captured.productId shouldBe 1L

// Spring 컨텍스트에서 MockK 사용
@MockkBean
private lateinit var orderService: OrderService
```

---

## Kotest Matchers 주요 목록

```kotlin
// 동등 비교
result shouldBe expected
result shouldNotBe null

// 컬렉션
list shouldHaveSize 3
list shouldContain item
list shouldBeEmpty()
list.shouldContainAll(item1, item2)

// 예외
shouldThrow<OrderNotFoundException> { service.getOrder(999L) }
shouldThrowMessage("not found") { service.getOrder(999L) }

// 문자열
str shouldContain "keyword"
str shouldStartWith "prefix"

// 숫자
num shouldBeGreaterThan 0
num shouldBeLessThanOrEqualTo 100

// null 체크
value.shouldBeNull()
value.shouldNotBeNull()
```

---

## Gradle 테스트 명령어

```bash
# 전체 테스트 실행
./gradlew test

# 특정 클래스 테스트
./gradlew test --tests "com.example.order.service.OrderServiceTest"
./gradlew test --tests "*OrderServiceTest"

# 패턴 매칭
./gradlew test --tests "*Order*"

# 상세 로그 출력
./gradlew test --info
./gradlew test --tests "*OrderServiceTest" --info 2>&1 | tail -50

# 실패한 테스트만 재실행
./gradlew test --rerun

# 커버리지 리포트 생성
./gradlew jacocoTestReport

# 테스트 + 커버리지 한 번에
./gradlew test jacocoTestReport

# 클린 후 테스트 (캐시 무시)
./gradlew clean test

# continuous 모드 (파일 변경 감지 자동 실행)
./gradlew test --continuous
```

편의 스크립트: `skills/kotlin-spring-tdd/scripts/run-tests.sh` 참조

---

## 체계적 디버깅

테스트가 예상대로 동작하지 않을 때 순서대로 확인한다:

### 1. 에러 메시지 정독

```bash
./gradlew test --tests "*OrderServiceTest" --info 2>&1 | tail -80
```

### 2. 단일 테스트 격리 실행

테스트 간 의존성 문제인지 확인한다.

```bash
./gradlew test --tests "*OrderServiceTest" --rerun
```

### 3. Spring Context 관련 문제

| 어노테이션 | 로드 범위 | 주의사항 |
|-----------|----------|---------|
| 없음 (순수 단위) | 없음 | MockK로 모든 의존성 주입 |
| `@WebMvcTest` | Controller 레이어만 | Service는 `@MockkBean` 필수 |
| `@DataJpaTest` | JPA 레이어만 | 인메모리 DB 사용 |
| `@SpringBootTest` | 전체 컨텍스트 | 포트 충돌, 느린 속도 주의 |

### 4. MockK 흔한 문제

| 증상 | 원인 | 해결 |
|------|------|------|
| `no answer found for ...` | `every {}` 미정의 | 필요한 행동 정의 또는 `relaxed = true` |
| `Verification failed` | 호출 횟수 불일치 | `verify` 조건 재확인 |
| `SpringExtension not registered` | Kotest Spring 통합 누락 | `extensions(SpringExtension)` 추가 |
| `@MockkBean` not found | springmockk 의존성 누락 | `com.ninja-squad:springmockk` 추가 |

---

## 흔한 합리화 (하지 말아야 할 것)

| 합리화 | 왜 위험한가 |
|--------|-------------|
| "이건 너무 간단해서 테스트가 필요 없어" | 간단한 버그가 가장 오래 숨어 있다 |
| "테스트는 나중에 작성할게" | '나중'은 오지 않는다. 테스트 없는 코드는 레거시다 |
| "리팩토링이니까 테스트를 건너뛰자" | 리팩토링이야말로 테스트가 가장 필요한 순간이다 |
| "일단 동작하게 만들고 테스트를 추가하자" | 동작하는 코드에 테스트를 추가하면 구현에 맞춘 테스트가 된다 |
| "Mock이 너무 복잡하니까 그냥 통합 테스트로 대체하자" | Mock이 복잡하다는 것은 설계 문제의 신호다. 먼저 설계를 검토하라 |

더 많은 안티패턴: `testing-anti-patterns.md` 참조

---

## 검증 체크리스트

매 TDD 사이클마다 확인:

- [ ] **RED**: 테스트를 먼저 작성했는가?
- [ ] **RED**: `./gradlew test`로 실패를 확인했는가?
- [ ] **RED**: 올바른 이유로 실패하는가? (컴파일 에러, 미구현 등)
- [ ] **GREEN**: 테스트를 통과시킬 최소한의 코드만 작성했는가?
- [ ] **GREEN**: `./gradlew test`로 통과를 확인했는가?
- [ ] **GREEN**: 다른 테스트가 깨지지 않았는가?
- [ ] **REFACTOR**: 모든 테스트가 통과하는 상태에서 리팩토링했는가?
- [ ] **REFACTOR**: `./gradlew test`로 여전히 GREEN인지 확인했는가?
- [ ] BehaviorSpec의 Given/When/Then 구조를 따르고 있는가?
- [ ] 테스트 이름이 행동을 명확히 설명하는가?
- [ ] 각 Then 블록은 하나의 동작만 검증하는가?
