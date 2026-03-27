# Spring Boot 패턴 & 테스트 — 상세 패턴

## 목차

1. [레이어 아키텍처](#1-레이어-아키텍처)
2. [Entity 노출 금지](#2-entity-노출-금지)
3. [의존성 주입](#3-의존성-주입)
4. [트랜잭션](#4-트랜잭션)
5. [예외 처리](#5-예외-처리)
6. [보안 — 입력값 검증](#6-보안--입력값-검증)
7. [테스트 품질](#7-테스트-품질)

---

## 1. 레이어 아키텍처

### 레이어드 아키텍처 (기본)

의존성 방향은 반드시 한 방향이어야 한다.

```
Controller → Service → Repository
                    → Domain Model
```

```kotlin
// Bad — Repository가 Service를 참조 (역방향)
@Repository
class OrderRepository(private val orderService: OrderService)

// Bad — Controller가 Repository를 직접 참조 (레이어 건너뜀)
@RestController
class OrderController(private val orderRepository: OrderRepository)

// Good
@RestController
class OrderController(private val orderService: OrderService)

@Service
class OrderService(private val orderRepository: OrderRepository)
```

### DDD / 헥사고날 아키텍처 (팀 컨텍스트)

팀이 DDD 또는 헥사고날을 쓰는 경우 추가로 검토한다:

- 도메인 모델에 Spring 어노테이션 (`@Entity`, `@Service`) 혼입 여부
- 인바운드 포트(UseCase 인터페이스)를 거치지 않고 도메인 직접 호출
- 아웃바운드 포트(Repository 인터페이스)를 도메인 패키지에 두지 않고 인프라 패키지에 배치

```kotlin
// Good — 헥사고날: 포트 인터페이스를 도메인에
// domain/port/in/CreateOrderUseCase.kt
interface CreateOrderUseCase {
    fun createOrder(command: CreateOrderCommand): OrderResult
}

// application/service/OrderCommandService.kt
@Service
class OrderCommandService(
    private val orderRepository: OrderRepository,  // 아웃바운드 포트
) : CreateOrderUseCase {
    override fun createOrder(command: CreateOrderCommand): OrderResult { ... }
}
```

---

## 2. Entity 노출 금지

Entity를 Controller의 응답으로 직접 반환하면 세 가지 문제가 생긴다:

1. DB 스키마 변경이 API Breaking Change로 직결
2. 민감 필드(비밀번호 해시, 내부 ID 등) 노출
3. Lazy 로딩 중 Jackson 직렬화로 `LazyInitializationException` 발생

```kotlin
// Bad
@GetMapping("/orders/{id}")
fun getOrder(@PathVariable id: Long): Order {
    return orderService.getOrder(id)
}

// Good
@GetMapping("/orders/{id}")
fun getOrder(@PathVariable id: Long): OrderResponse {
    return orderService.getOrder(id).toResponse()
}

// DTO 변환은 Service 또는 전용 Mapper에서
data class OrderResponse(
    val id: Long,
    val status: OrderStatus,
    val createdAt: LocalDateTime,
    // 민감 필드 제외
)

fun Order.toResponse() = OrderResponse(
    id = id,
    status = status,
    createdAt = createdAt,
)
```

---

## 3. 의존성 주입

### 생성자 주입 권장

필드 주입(`@Autowired` on field)은 세 가지 이유로 지양한다:

1. 테스트에서 mock 주입이 어려움 (reflection 필요)
2. 순환 의존성을 컴파일 타임에 감지하지 못함
3. `val`로 선언할 수 없어 불변성 보장 불가

```kotlin
// Bad — 필드 주입
@Service
class OrderService {
    @Autowired
    private lateinit var orderRepository: OrderRepository
}

// Good — 생성자 주입 (Kotlin에서 @Autowired 생략 가능)
@Service
class OrderService(
    private val orderRepository: OrderRepository,
)
```

---

## 4. 트랜잭션

### @Transactional 위치

```kotlin
// Bad — Controller에 @Transactional
@RestController
class OrderController(private val orderService: OrderService) {
    @Transactional
    @PostMapping("/orders")
    fun createOrder(@RequestBody request: CreateOrderRequest): OrderResponse { ... }
}

// Good — Service 레이어에 @Transactional
@Service
class OrderService(private val orderRepository: OrderRepository) {
    @Transactional
    fun createOrder(request: CreateOrderRequest): OrderResponse { ... }

    @Transactional(readOnly = true)
    fun getOrder(id: Long): OrderResponse { ... }
}
```

### readOnly = true

조회 전용 메서드에 `readOnly = true`를 명시하면:
- Hibernate dirty checking 건너뜀 → 성능 향상
- 읽기 전용 DB replica로 라우팅 가능
- 의도가 코드에 명시적으로 드러남

```kotlin
// Bad
@Transactional
fun findAllOrders(): List<OrderResponse> = orderRepository.findAll().map { it.toResponse() }

// Good
@Transactional(readOnly = true)
fun findAllOrders(): List<OrderResponse> = orderRepository.findAll().map { it.toResponse() }
```

### Lazy 로딩 경계

```kotlin
// Bad — 트랜잭션 밖에서 Lazy 로딩 → LazyInitializationException
@Transactional(readOnly = true)
fun getOrder(id: Long): Order = orderRepository.findById(id).orElseThrow()

// Controller에서 order.items 접근 시 트랜잭션이 이미 종료됨
// order.items → LazyInitializationException

// Good — 트랜잭션 안에서 DTO로 변환 후 반환
@Transactional(readOnly = true)
fun getOrder(id: Long): OrderResponse {
    val order = orderRepository.findById(id).orElseThrow()
    return order.toResponse()  // Lazy 필드 접근이 여기서 발생, 트랜잭션 안
}
```

### N+1 쿼리

```kotlin
// Bad — orders 조회 후 각 order마다 items를 개별 쿼리
fun findAllOrders(): List<OrderResponse> {
    return orderRepository.findAll().map { order ->
        OrderResponse(
            id = order.id,
            items = order.items.map { it.toDto() }  // N+1 발생
        )
    }
}

// Good — Fetch Join 또는 EntityGraph 사용
@Query("SELECT o FROM Order o LEFT JOIN FETCH o.items")
fun findAllWithItems(): List<Order>

// 또는 @EntityGraph
@EntityGraph(attributePaths = ["items"])
fun findAll(): List<Order>
```

---

## 5. 예외 처리

### 통일된 에러 응답

```kotlin
// Bad — 각 Controller에서 직접 에러 응답 처리
@GetMapping("/orders/{id}")
fun getOrder(@PathVariable id: Long): ResponseEntity<*> {
    return try {
        ResponseEntity.ok(orderService.getOrder(id))
    } catch (e: OrderNotFoundException) {
        ResponseEntity.status(404).body(mapOf("error" to e.message))
    }
}

// Good — @ControllerAdvice로 중앙 집중 처리
@RestControllerAdvice
class GlobalExceptionHandler {
    @ExceptionHandler(OrderNotFoundException::class)
    fun handleOrderNotFound(e: OrderNotFoundException): ResponseEntity<ErrorResponse> =
        ResponseEntity.status(HttpStatus.NOT_FOUND)
            .body(ErrorResponse(code = "ORDER_NOT_FOUND", message = e.message))

    @ExceptionHandler(Exception::class)
    fun handleGeneral(e: Exception): ResponseEntity<ErrorResponse> {
        logger.error("Unexpected error", e)  // 스택트레이스 로그
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
            .body(ErrorResponse(code = "INTERNAL_ERROR", message = "서버 오류가 발생했습니다"))
        // 내부 상세 메시지는 클라이언트에 노출하지 않음
    }
}
```

### 의미 있는 예외 타입

```kotlin
// Bad — RuntimeException으로 통일
throw RuntimeException("Order not found: $id")

// Good — 도메인 예외 타입 정의
class OrderNotFoundException(id: Long) :
    RuntimeException("Order not found: $id")

class OrderAlreadyCancelledException(id: Long) :
    RuntimeException("Order $id is already cancelled")
```

---

## 6. 보안 — 입력값 검증

### @Valid 누락

```kotlin
// Bad — 검증 없이 바로 처리
@PostMapping("/orders")
fun createOrder(@RequestBody request: CreateOrderRequest): OrderResponse {
    return orderService.createOrder(request)
}

// Good
@PostMapping("/orders")
fun createOrder(@Valid @RequestBody request: CreateOrderRequest): OrderResponse {
    return orderService.createOrder(request)
}

data class CreateOrderRequest(
    @field:NotNull val productId: Long,
    @field:Min(1) val quantity: Int,
    @field:Size(max = 500) val note: String?,
)
```

### Mass Assignment

```kotlin
// Bad — Request를 Entity에 직접 바인딩
@PostMapping("/users/{id}")
fun updateUser(@PathVariable id: Long, @RequestBody user: User): User {
    return userRepository.save(user)  // role, createdAt 등 민감 필드도 덮어씀
}

// Good — DTO를 통해 허용 필드만 반영
@PostMapping("/users/{id}")
fun updateUser(@PathVariable id: Long, @Valid @RequestBody request: UpdateUserRequest): UserResponse {
    return userService.updateUser(id, request)
}

data class UpdateUserRequest(
    @field:NotBlank val name: String,
    @field:Email val email: String,
    // role, createdAt 등 민감 필드는 포함하지 않음
)
```

---

## 7. 테스트 품질

### 테스트 레이어 선택 기준

| 상황 | 적합한 어노테이션 | 이유 |
|------|----------------|------|
| 비즈니스 로직 검증 | 없음 (순수 단위 테스트) | Spring 컨텍스트 불필요, 빠름 |
| Controller HTTP 처리 | `@WebMvcTest` | Controller 레이어만 로드 |
| JPA 쿼리 검증 | `@DataJpaTest` | JPA 레이어만 로드 |
| E2E 시나리오 | `@SpringBootTest` | 전체 컨텍스트 필요할 때만 |

```kotlin
// Bad — 단순 Service 로직에 @SpringBootTest
@SpringBootTest
class OrderServiceTest {
    @Autowired lateinit var orderService: OrderService
    // 전체 컨텍스트 로드 → 느림, 불필요한 의존성
}

// Good — MockK를 이용한 순수 단위 테스트
class OrderServiceTest : BehaviorSpec({
    val orderRepository = mockk<OrderRepository>()
    val orderService = OrderServiceImpl(orderRepository)

    Given("유효한 주문 요청") {
        every { orderRepository.save(any()) } returns mockOrder()
        When("주문 생성") {
            val result = orderService.createOrder(validRequest())
            Then("CREATED 상태로 반환") {
                result.status shouldBe OrderStatus.CREATED
            }
        }
    }
})
```

### 경계값 & 예외 케이스

```kotlin
// Bad — happy path만 테스트
Given("정상 요청") {
    When("주문 생성") {
        Then("성공") { ... }
    }
}

// Good — 경계값과 예외 케이스 포함
Given("존재하지 않는 상품 ID") {
    every { productRepository.findById(999L) } returns Optional.empty()
    When("주문 생성 시도") {
        Then("ProductNotFoundException 발생") {
            shouldThrow<ProductNotFoundException> { orderService.createOrder(request) }
        }
    }
}

Given("수량이 0인 요청") { ... }
Given("재고 부족 상황") { ... }
```

### 테스트 이름

```kotlin
// Bad
test("test1") { ... }
fun testCreate() { ... }

// Good — 행동과 기대 결과를 설명
test("POST /orders - 유효한 요청 시 201 Created와 생성된 주문을 반환한다") { ... }
"재고가 부족할 때 주문을 생성하면 InsufficientStockException이 발생한다" { ... }
```
