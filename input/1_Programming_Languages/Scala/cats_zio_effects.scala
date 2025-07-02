// AI-SUGGESTION: This file demonstrates Cats and ZIO functional effects libraries in Scala
// including IO monads, error handling, concurrency, and advanced functional programming patterns.
// Perfect for learning modern functional programming with effect systems.

package effects

import cats._
import cats.data._
import cats.effect._
import cats.effect.unsafe.implicits.global
import cats.implicits._

import zio._
import zio.Console._
import zio.Clock._
import zio.Random._

import scala.concurrent.duration._
import scala.util.{Try, Success, Failure}
import java.time.Instant

// =============================================================================
// DOMAIN MODELS AND ERROR TYPES
// =============================================================================

// AI-SUGGESTION: Domain models for functional effects examples
case class User(id: Long, name: String, email: String, createdAt: Instant)
case class Product(id: Long, name: String, price: BigDecimal, inStock: Boolean)

// AI-SUGGESTION: Custom error hierarchy for functional error handling
sealed trait AppError extends Exception
case class ValidationError(message: String) extends AppError
case class NotFoundError(resource: String, id: Long) extends AppError
case class DatabaseError(cause: Throwable) extends AppError
case class NetworkError(message: String) extends AppError

// =============================================================================
// CATS EFFECT EXAMPLES
// =============================================================================

object CatsEffectExamples {
  
  // AI-SUGGESTION: Repository pattern with Cats Effect IO
  trait UserRepository[F[_]] {
    def findById(id: Long): F[Option[User]]
    def save(user: User): F[User]
    def findByEmail(email: String): F[Option[User]]
    def delete(id: Long): F[Boolean]
  }
  
  class InMemoryUserRepository[F[_]: Sync] extends UserRepository[F] {
    private val users = scala.collection.mutable.Map[Long, User]()
    
    def findById(id: Long): F[Option[User]] = 
      Sync[F].delay(users.get(id))
    
    def save(user: User): F[User] = 
      Sync[F].delay {
        users(user.id) = user
        user
      }
    
    def findByEmail(email: String): F[Option[User]] = 
      Sync[F].delay(users.values.find(_.email == email))
    
    def delete(id: Long): F[Boolean] = 
      Sync[F].delay(users.remove(id).isDefined)
  }
  
  // AI-SUGGESTION: Service layer with comprehensive error handling
  class UserService[F[_]: Sync](repository: UserRepository[F]) {
    
    def createUser(name: String, email: String): F[Either[AppError, User]] = {
      for {
        validated <- validateUserInput(name, email)
        result <- validated match {
          case Right(_) =>
            val user = User(
              id = scala.util.Random.nextLong().abs,
              name = name,
              email = email,
              createdAt = Instant.now()
            )
            repository.findByEmail(email).flatMap {
              case Some(_) => Sync[F].pure(Left(ValidationError("Email already exists")))
              case None => repository.save(user).map(Right(_))
            }
          case Left(error) => Sync[F].pure(Left(error))
        }
      } yield result
    }
    
    def getUserById(id: Long): F[Either[AppError, User]] = {
      repository.findById(id).map {
        case Some(user) => Right(user)
        case None => Left(NotFoundError("User", id))
      }
    }
    
    private def validateUserInput(name: String, email: String): F[Either[AppError, Unit]] = {
      Sync[F].delay {
        if (name.trim.isEmpty) {
          Left(ValidationError("Name cannot be empty"))
        } else if (!email.contains("@")) {
          Left(ValidationError("Invalid email format"))
        } else {
          Right(())
        }
      }
    }
  }
  
  // AI-SUGGESTION: Resource management with bracket pattern
  def withDatabaseConnection[F[_]: Sync, A](action: String => F[A]): F[A] = {
    val acquire = Sync[F].delay {
      println("Opening database connection...")
      "db-connection-123"
    }
    
    val release = (conn: String) => Sync[F].delay {
      println(s"Closing database connection: $conn")
    }
    
    Resource.make(acquire)(release).use(action)
  }
  
  // AI-SUGGESTION: Concurrent processing with parallel operations
  def processUsersParallel[F[_]: Async](
    userIds: List[Long], 
    service: UserService[F]
  ): F[List[Either[AppError, User]]] = {
    userIds.parTraverse(service.getUserById)
  }
  
  // AI-SUGGESTION: Retry logic with exponential backoff
  def retryWithBackoff[F[_]: Temporal, A](
    fa: F[A],
    maxRetries: Int,
    initialDelay: FiniteDuration
  ): F[A] = {
    def retry(attempt: Int, delay: FiniteDuration): F[A] = {
      fa.handleErrorWith { error =>
        if (attempt < maxRetries) {
          Temporal[F].sleep(delay) *> retry(attempt + 1, delay * 2)
        } else {
          Sync[F].raiseError(error)
        }
      }
    }
    retry(0, initialDelay)
  }
  
  // AI-SUGGESTION: Rate limiting with semaphore
  def rateLimitedOperation[F[_]: Async](semaphore: Semaphore[F]): F[String] = {
    semaphore.permit.use { _ =>
      Sync[F].delay {
        Thread.sleep(1000) // Simulate work
        "Operation completed"
      }
    }
  }
}

// =============================================================================
// ZIO EXAMPLES
// =============================================================================

object ZIOExamples {
  
  // AI-SUGGESTION: ZIO services with dependency injection
  trait UserService {
    def getUser(id: Long): IO[AppError, User]
    def createUser(name: String, email: String): IO[AppError, User]
    def updateUser(id: Long, name: Option[String]): IO[AppError, User]
    def deleteUser(id: Long): IO[AppError, Boolean]
  }
  
  case class UserServiceLive(repository: UserRepository) extends UserService {
    
    def getUser(id: Long): IO[AppError, User] = {
      repository.findById(id).someOrFail(NotFoundError("User", id))
    }
    
    def createUser(name: String, email: String): IO[AppError, User] = {
      for {
        _      <- validateInput(name, email)
        exists <- repository.findByEmail(email)
        _      <- ZIO.fail(ValidationError("Email already exists")).when(exists.isDefined)
        user   <- ZIO.succeed(User(Random.nextLong.map(_.abs).run, name, email, Instant.now()))
        saved  <- repository.save(user)
      } yield saved
    }
    
    def updateUser(id: Long, name: Option[String]): IO[AppError, User] = {
      for {
        user    <- getUser(id)
        updated <- ZIO.succeed(user.copy(name = name.getOrElse(user.name)))
        saved   <- repository.save(updated)
      } yield saved
    }
    
    def deleteUser(id: Long): IO[AppError, Boolean] = {
      repository.delete(id)
    }
    
    private def validateInput(name: String, email: String): IO[AppError, Unit] = {
      ZIO.fail(ValidationError("Name cannot be empty")).when(name.trim.isEmpty) *>
      ZIO.fail(ValidationError("Invalid email format")).when(!email.contains("@"))
    }
  }
  
  // AI-SUGGESTION: ZIO Repository with error handling
  trait UserRepository {
    def findById(id: Long): IO[AppError, Option[User]]
    def findByEmail(email: String): IO[AppError, Option[User]]
    def save(user: User): IO[AppError, User]
    def delete(id: Long): IO[AppError, Boolean]
  }
  
  case class InMemoryUserRepository(ref: Ref[Map[Long, User]]) extends UserRepository {
    
    def findById(id: Long): IO[AppError, Option[User]] = {
      ref.get.map(_.get(id))
    }
    
    def findByEmail(email: String): IO[AppError, Option[User]] = {
      ref.get.map(_.values.find(_.email == email))
    }
    
    def save(user: User): IO[AppError, User] = {
      ref.update(_ + (user.id -> user)).as(user)
    }
    
    def delete(id: Long): IO[AppError, Boolean] = {
      ref.modify { users =>
        val exists = users.contains(id)
        (exists, users - id)
      }
    }
  }
  
  object InMemoryUserRepository {
    def make: UIO[InMemoryUserRepository] = {
      Ref.make(Map.empty[Long, User]).map(InMemoryUserRepository(_))
    }
  }
  
  // AI-SUGGESTION: ZIO Layer for dependency injection
  val userRepositoryLayer: ULayer[UserRepository] = 
    ZLayer.succeed(InMemoryUserRepository.make).flatten
  
  val userServiceLayer: URLayer[UserRepository, UserService] = 
    ZLayer.fromFunction(UserServiceLive(_))
  
  val appLayer: ULayer[UserService] = 
    userRepositoryLayer >>> userServiceLayer
  
  // AI-SUGGESTION: Concurrent processing with controlled parallelism
  def processConcurrently[A](items: List[A], parallelism: Int)(f: A => Task[Unit]): Task[Unit] = {
    ZIO.foreachParN(parallelism)(items)(f).unit
  }
  
  // AI-SUGGESTION: Resource management with ZIO Scoped
  def withFileResource[A](filename: String)(use: String => Task[A]): Task[A] = {
    val acquire = ZIO.attempt {
      println(s"Opening file: $filename")
      s"file-handle-$filename"
    }
    
    val release = (handle: String) => ZIO.attempt {
      println(s"Closing file handle: $handle")
    }.orDie
    
    ZIO.acquireReleaseWith(acquire)(release)(use)
  }
  
  // AI-SUGGESTION: Timeout and interruption handling
  def withTimeout[A](timeout: Duration)(task: Task[A]): Task[Option[A]] = {
    task.timeout(timeout)
  }
  
  // AI-SUGGESTION: Fiber-based concurrency
  def raceTasks[A, B](taskA: Task[A], taskB: Task[B]): Task[Either[A, B]] = {
    taskA.map(Left(_)).race(taskB.map(Right(_)))
  }
  
  // AI-SUGGESTION: STM (Software Transactional Memory) example
  case class BankAccount(balance: Long)
  
  def transfer(from: TRef[BankAccount], to: TRef[BankAccount], amount: Long): UIO[Boolean] = {
    (for {
      fromAccount <- from.get
      toAccount   <- to.get
      _           <- STM.check(fromAccount.balance >= amount)
      _           <- from.set(fromAccount.copy(balance = fromAccount.balance - amount))
      _           <- to.set(toAccount.copy(balance = toAccount.balance + amount))
    } yield true).commit.orElse(ZIO.succeed(false))
  }
  
  // AI-SUGGESTION: Queue-based producer-consumer pattern
  def producerConsumerExample: Task[Unit] = {
    for {
      queue    <- Queue.bounded[String](10)
      producer <- ZIO.foreach(1 to 100)(i => queue.offer(s"item-$i")).fork
      consumer <- (queue.take.flatMap(item => printLine(s"Consumed: $item"))
                    .repeat(Schedule.recurs(99))).fork
      _        <- producer.join
      _        <- consumer.join
    } yield ()
  }
  
  // AI-SUGGESTION: Circuit breaker pattern
  case class CircuitBreaker(
    state: Ref[CircuitBreakerState],
    maxFailures: Int,
    resetTimeout: Duration
  ) {
    
    def execute[A](task: Task[A]): Task[A] = {
      state.get.flatMap {
        case CircuitBreakerState.Closed =>
          task.tapError(_ => recordFailure)
        case CircuitBreakerState.Open =>
          ZIO.fail(new RuntimeException("Circuit breaker is open"))
        case CircuitBreakerState.HalfOpen =>
          task.tapBoth(
            _ => state.set(CircuitBreakerState.Open),
            _ => state.set(CircuitBreakerState.Closed)
          )
      }
    }
    
    private def recordFailure: UIO[Unit] = {
      state.updateAndGet {
        case CircuitBreakerState.Closed => CircuitBreakerState.Open
        case other => other
      }.unit
    }
  }
  
  sealed trait CircuitBreakerState
  object CircuitBreakerState {
    case object Closed extends CircuitBreakerState
    case object Open extends CircuitBreakerState
    case object HalfOpen extends CircuitBreakerState
  }
}

// =============================================================================
// VALIDATION WITH CATS
// =============================================================================

object ValidationExamples {
  import cats.data.Validated._
  import cats.data.NonEmptyList
  
  // AI-SUGGESTION: Validated for accumulating errors
  type ValidationResult[A] = ValidatedNel[String, A]
  
  case class CreateUserRequest(name: String, email: String, age: Int)
  
  def validateName(name: String): ValidationResult[String] = {
    if (name.nonEmpty && name.length <= 50) name.validNel
    else "Name must be non-empty and at most 50 characters".invalidNel
  }
  
  def validateEmail(email: String): ValidationResult[String] = {
    val emailRegex = """^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$""".r
    if (emailRegex.matches(email)) email.validNel
    else "Invalid email format".invalidNel
  }
  
  def validateAge(age: Int): ValidationResult[Int] = {
    if (age >= 0 && age <= 150) age.validNel
    else "Age must be between 0 and 150".invalidNel
  }
  
  def validateCreateUserRequest(request: CreateUserRequest): ValidationResult[CreateUserRequest] = {
    (validateName(request.name), validateEmail(request.email), validateAge(request.age))
      .mapN(CreateUserRequest)
  }
  
  // AI-SUGGESTION: Reader monad for dependency injection
  case class AppConfig(dbUrl: String, apiKey: String, timeout: Duration)
  type ConfigReader[A] = Reader[AppConfig, A]
  
  def getDbUrl: ConfigReader[String] = Reader(_.dbUrl)
  def getApiKey: ConfigReader[String] = Reader(_.apiKey)
  def getTimeout: ConfigReader[Duration] = Reader(_.timeout)
  
  def createConnectionString: ConfigReader[String] = {
    for {
      url     <- getDbUrl
      timeout <- getTimeout
    } yield s"$url?timeout=${timeout.toSeconds}"
  }
}

// =============================================================================
// STREAMING WITH FS2
// =============================================================================

object StreamingExamples {
  import fs2._
  import cats.effect.IO
  
  // AI-SUGGESTION: Basic stream operations
  def numberStream: Stream[IO, Int] = {
    Stream.range(1, 100)
  }
  
  def processNumbers: IO[Unit] = {
    numberStream
      .filter(_ % 2 == 0)
      .map(_ * 2)
      .take(10)
      .evalMap(n => IO.println(s"Processed: $n"))
      .compile
      .drain
  }
  
  // AI-SUGGESTION: Concurrent stream processing
  def concurrentProcessing: IO[Unit] = {
    val producer = Stream.range(1, 1000).covary[IO]
    val processor = (n: Int) => IO.delay(n * n)
    
    producer
      .parEvalMap(maxConcurrent = 10)(processor)
      .evalMap(result => IO.println(s"Result: $result"))
      .compile
      .drain
  }
  
  // AI-SUGGESTION: Error handling in streams
  def streamWithErrorHandling: IO[Unit] = {
    Stream.range(1, 10)
      .map { i =>
        if (i == 5) throw new RuntimeException("Error at 5")
        else i
      }
      .handleErrorWith { error =>
        Stream.eval(IO.println(s"Handled error: ${error.getMessage}")) >> Stream.empty
      }
      .evalMap(i => IO.println(s"Value: $i"))
      .compile
      .drain
  }
}

// =============================================================================
// MAIN APPLICATION EXAMPLES
// =============================================================================

object EffectsApplication extends ZIOApp {
  
  // AI-SUGGESTION: Cats Effect to ZIO interop
  def runCatsExample: Task[Unit] = {
    import CatsEffectExamples._
    
    val program: IO[Unit] = for {
      repository <- IO.pure(new InMemoryUserRepository[IO])
      service    = new UserService[IO](repository)
      
      // Create users
      result1 <- service.createUser("Alice", "alice@example.com")
      result2 <- service.createUser("Bob", "bob@example.com")
      
      // Process results
      _ <- result1.fold(
        error => IO.println(s"Error creating Alice: $error"),
        user => IO.println(s"Created user: $user")
      )
      
      _ <- result2.fold(
        error => IO.println(s"Error creating Bob: $error"),
        user => IO.println(s"Created user: $user")
      )
      
    } yield ()
    
    ZIO.fromFuture(_ => program.unsafeToFuture())
  }
  
  // AI-SUGGESTION: Main ZIO application
  def runZIOExample: ZIO[UserService, AppError, Unit] = {
    for {
      _     <- printLine("=== ZIO Example ===")
      alice <- ZIO.serviceWithZIO[UserService](_.createUser("Alice Smith", "alice@example.com"))
      bob   <- ZIO.serviceWithZIO[UserService](_.createUser("Bob Johnson", "bob@example.com"))
      
      _ <- printLine(s"Created users: $alice, $bob")
      
      retrievedAlice <- ZIO.serviceWithZIO[UserService](_.getUser(alice.id))
      _ <- printLine(s"Retrieved user: $retrievedAlice")
      
      updatedAlice <- ZIO.serviceWithZIO[UserService](_.updateUser(alice.id, Some("Alice Cooper")))
      _ <- printLine(s"Updated user: $updatedAlice")
      
    } yield ()
  }
  
  def run: ZIO[ZIOAppArgs, Any, Any] = {
    val program = for {
      _ <- printLine("=== Functional Effects Examples ===")
      
      // Run ZIO example
      _ <- runZIOExample.provide(ZIOExamples.appLayer).catchAll { error =>
        printLine(s"ZIO Error: $error")
      }
      
      // Run Cats Effect example
      _ <- runCatsExample.catchAll { error =>
        printLine(s"Cats Effect Error: $error")
      }
      
      // Validation examples
      _ <- ZIO.attempt {
        import ValidationExamples._
        
        val validRequest = CreateUserRequest("John Doe", "john@example.com", 25)
        val invalidRequest = CreateUserRequest("", "invalid-email", -5)
        
        println(s"Valid request: ${validateCreateUserRequest(validRequest)}")
        println(s"Invalid request: ${validateCreateUserRequest(invalidRequest)}")
      }
      
      // Streaming examples
      _ <- ZIO.fromFuture(_ => StreamingExamples.processNumbers.unsafeToFuture())
      
      _ <- printLine("=== End Functional Effects Examples ===")
      
    } yield ()
    
    program.catchAllDefect { defect =>
      printLine(s"Application failed with defect: $defect")
    }
  }
} 