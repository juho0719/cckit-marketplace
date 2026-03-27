# Coroutine 안티패턴 — 상세 패턴

## GlobalScope 사용 — P1

`GlobalScope`는 수명이 애플리케이션 전체와 동일하다. 요청이 취소되거나 컴포넌트가 소멸해도 코루틴이 계속 실행되어 리소스 누수가 발생한다.

```kotlin
// Bad
@Service
class NotificationService {
    fun sendAsync(userId: Long) {
        GlobalScope.launch {  // 취소 불가, 수명 관리 불가
            notificationClient.send(userId)
        }
    }
}

// Good — 빈의 수명과 연결된 scope 사용
@Service
class NotificationService(
    private val notificationClient: NotificationClient,
) : CoroutineScope by CoroutineScope(SupervisorJob() + Dispatchers.IO) {

    fun sendAsync(userId: Long) {
        launch {
            notificationClient.send(userId)
        }
    }

    @PreDestroy
    fun destroy() {
        cancel()  // 빈 소멸 시 모든 코루틴 취소
    }
}

// Good — Spring에서 권장하는 방식 (Spring 6+)
// applicationScope bean 주입
@Service
class NotificationService(
    private val applicationScope: CoroutineScope,  // @Bean으로 정의된 scope
) {
    fun sendAsync(userId: Long) {
        applicationScope.launch {
            notificationClient.send(userId)
        }
    }
}
```

---

## suspend 함수에서 블로킹 IO — P1

`suspend` 함수라고 해서 블로킹 호출이 자동으로 비동기가 되지 않는다.
블로킹 IO를 그대로 호출하면 코루틴 스레드 풀을 점유하여 전체 처리량이 저하된다.

```kotlin
// Bad — suspend 함수 안에서 블로킹 JDBC 직접 호출
suspend fun findUser(id: Long): User {
    return jdbcTemplate.queryForObject(...)  // 블로킹, 코루틴 스레드 점유
}

// Bad — Thread.sleep
suspend fun waitAndNotify() {
    Thread.sleep(1000)  // 블로킹, kotlinx.coroutines.delay 사용해야 함
}

// Good — Dispatchers.IO로 컨텍스트 전환
suspend fun findUser(id: Long): User = withContext(Dispatchers.IO) {
    jdbcTemplate.queryForObject(...)
}

// Good — delay (non-blocking)
suspend fun waitAndNotify() {
    delay(1000)
}

// Good — Spring Data R2DBC 또는 Coroutine 지원 Repository 사용 (가장 이상적)
interface UserRepository : CoroutineCrudRepository<User, Long>
```

**판단 기준**: 블로킹 IO (`JDBC`, `RestTemplate`, `File I/O`)가 `withContext(Dispatchers.IO)` 없이 `suspend` 함수 안에 있으면 P1이다.

---

## Structured Concurrency 위반 — P1

Structured concurrency란 코루틴의 수명이 부모 scope에 종속되어야 한다는 원칙이다.
scope 밖으로 `Job`을 탈출시키면 취소·에러 전파가 끊어진다.

```kotlin
// Bad — Job을 외부로 유출
var backgroundJob: Job? = null

suspend fun startProcessing() {
    backgroundJob = CoroutineScope(Dispatchers.IO).launch {  // 새 scope 생성 → 부모와 무관
        processData()
    }
}

// Bad — coroutineScope 밖에서 launch한 Job을 외부 변수에 저장
class OrderProcessor {
    private val jobs = mutableListOf<Job>()

    fun process(order: Order) {
        jobs += GlobalScope.launch { doProcess(order) }
    }
}

// Good — coroutineScope로 구조적 동시성 유지
suspend fun processAll(orders: List<Order>) = coroutineScope {
    orders.map { order ->
        launch { processOrder(order) }
    }.joinAll()
    // 모든 launch가 완료되거나 하나라도 실패하면 나머지도 취소됨
}
```

---

## launch vs async 혼용 — P2

`launch`는 결과값이 없는 실행용이고, `async`는 결과값(`Deferred`)을 반환하기 위한 것이다.

```kotlin
// Bad — 결과값이 필요한데 launch 사용
suspend fun fetchUserAndOrder(userId: Long): Pair<User, List<Order>> {
    var user: User? = null
    var orders: List<Order>? = null

    coroutineScope {
        launch { user = userService.getUser(userId) }
        launch { orders = orderService.getOrders(userId) }
    }
    return Pair(user!!, orders!!)  // !! 강제 사용
}

// Good — async + await으로 결과값 수집
suspend fun fetchUserAndOrder(userId: Long): Pair<User, List<Order>> = coroutineScope {
    val userDeferred = async { userService.getUser(userId) }
    val ordersDeferred = async { orderService.getOrders(userId) }
    Pair(userDeferred.await(), ordersDeferred.await())
}
```

---

## runBlocking을 프로덕션 코드에서 사용 — P2

`runBlocking`은 현재 스레드를 블로킹하며 코루틴이 끝날 때까지 기다린다.
테스트나 `main()` 함수 진입점에서만 사용해야 한다.
프로덕션 Service/Repository에서 사용하면 코루틴의 이점을 모두 잃는다.

```kotlin
// Bad — Service에서 runBlocking
@Service
class OrderService {
    fun createOrder(request: CreateOrderRequest): OrderResponse {
        return runBlocking {  // 스레드 블로킹, 스레드 풀 소진 위험
            processOrder(request)
        }
    }
}

// Good — suspend 함수로 선언
@Service
class OrderService {
    suspend fun createOrder(request: CreateOrderRequest): OrderResponse {
        return processOrder(request)
    }
}

// 허용: 테스트에서 사용
class OrderServiceTest : FunSpec({
    test("주문 생성") {
        runTest {  // runTest 사용 (kotlinx-coroutines-test)
            val result = orderService.createOrder(request)
            result.status shouldBe OrderStatus.CREATED
        }
    }
})
```

---

## CoroutineExceptionHandler 미설정 — P2

`launch`로 실행된 코루틴에서 발생한 예외는 부모 scope로 전파되거나,
`SupervisorJob`을 사용하는 경우 조용히 무시될 수 있다.
예외가 로그에 남지 않으면 운영 중 장애 원인 파악이 어렵다.

```kotlin
// Bad — 예외 핸들러 없이 launch
applicationScope.launch {
    sendNotification(userId)  // 실패해도 아무도 모름
}

// Good — CoroutineExceptionHandler 설정
val handler = CoroutineExceptionHandler { _, exception ->
    logger.error("Coroutine failed", exception)
    // 알림 발송, 메트릭 기록 등
}

applicationScope.launch(handler) {
    sendNotification(userId)
}

// Good — try-catch로 명시적 처리
applicationScope.launch {
    try {
        sendNotification(userId)
    } catch (e: NotificationException) {
        logger.error("Failed to send notification to $userId", e)
    }
}
```

---

## Flow cold/hot 이해 — P3

`Flow`는 기본적으로 cold stream이다. 수집(collect)할 때마다 새로 실행된다.
`SharedFlow`/`StateFlow`는 hot stream으로 동작이 다르다.

```kotlin
// Bad — cold Flow를 hot처럼 사용
@Service
class EventService {
    // 이 Flow는 collect할 때마다 새로 구독됨
    val events: Flow<Event> = flow {
        emit(eventRepository.findLatest())  // collect마다 DB 쿼리 발생
    }
}

// Good — 공유가 필요하면 SharedFlow 사용
@Service
class EventService {
    private val _events = MutableSharedFlow<Event>()
    val events: SharedFlow<Event> = _events.asSharedFlow()

    suspend fun publish(event: Event) {
        _events.emit(event)
    }
}

// Good — 최신 상태 공유가 필요하면 StateFlow
private val _currentStatus = MutableStateFlow(OrderStatus.CREATED)
val currentStatus: StateFlow<OrderStatus> = _currentStatus.asStateFlow()
```
