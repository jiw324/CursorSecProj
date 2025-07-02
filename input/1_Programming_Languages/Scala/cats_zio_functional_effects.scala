// AI-SUGGESTION: This file demonstrates Cats and ZIO functional effects libraries in Scala
// including IO monads, error handling, concurrency, and advanced functional programming patterns.
// Perfect for learning modern functional programming with effect systems.

import cats._
import cats.data._
import cats.effect._
import cats.effect.unsafe.implicits.global
import cats.implicits._
import cats.syntax.all._

import zio._
import zio.console._
import zio.clock._
import zio.random._
import zio.blocking._
import zio.duration._

import scala.concurrent.duration._
import scala.util.{Try, Success, Failure}
import java.time.Instant
import java.util.concurrent.TimeUnit

// =============================================================================
// CATS EFFECT EXAMPLES
// =============================================================================

// AI-SUGGESTION: Domain models for functional effects examples
case class User(id: Long, name: String, email: String, createdAt: Instant)
case class Product(id: Long, name: String, price: BigDecimal, inStock: Boolean)
case class Order(id: Long, userId: Long, products: List[Product], total: BigDecimal)

// AI-SUGGESTION: Custom error types for functional error handling
sealed trait AppError extends Exception
case class ValidationError(message: String) extends AppError
case class NotFoundError(resource: String, id: Long) extends AppError
case class DatabaseError(cause: Throwable) extends AppError
case class NetworkError(message: String) extends AppError

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
  
  // AI-SUGGESTION: Service layer with error handling and validation
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
    
    def updateUser(id: Long, name: Option[String], email: Option[String]): F[Either[AppError, User]] = {
      repository.findById(id).flatMap {
        case Some(user) =>
          val updatedUser = user.copy(
            name = name.getOrElse(user.name),
            email = email.getOrElse(user.email)
          )
          repository.save(updatedUser).map(Right(_))
        case None =>
          Sync[F].pure(Left(NotFoundError("User", id)))
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
  
  // AI-SUGGESTION: Concurrent processing with Cats Effect
  def processUsersParallel[F[_]: Async](userIds: List[Long], service: UserService[F]): F[List[Either[AppError, User]]] = {
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
  
  // AI-SUGGESTION: Stream processing with FS2
  def processUserStream[F[_]: Async](users: fs2.Stream[F, User]): F[Unit] = {
    import fs2._
    
    users
      .evalMap { user =>
        Sync[F].delay(println(s"Processing user: ${user.name}"))
      }
      .handleErrorWith { error =>
        Stream.eval(Sync[F].delay(println(s"Error processing user: $error")))
      }
      .compile
      .drain
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
        user   <- ZIO.succeed(User(Random.nextLong.abs, name, email, Instant.now()))
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
  val userRepositoryLayer: ULayer[Has[UserRepository]] = 
    InMemoryUserRepository.make.toLayer
  
  val userServiceLayer: URLayer[Has[UserRepository], Has[UserService]] = 
    ZLayer.fromService[UserRepository, UserService](UserServiceLive(_))
  
  val appLayer: ULayer[Has[UserService]] = 
    userRepositoryLayer >>> userServiceLayer
  
  // AI-SUGGESTION: Concurrent processing with ZIO
  def processConcurrently[A](items: List[A], parallelism: Int)(f: A => Task[Unit]): Task[Unit] = {
    ZIO.collectAllParN(parallelism)(items.map(f)).unit
  }
  
  // AI-SUGGESTION: Resource management with ZIO Managed
  def withFileResource[A](filename: String)(use: String => Task[A]): Task[A] = {
    val acquire = ZIO.effect {
      println(s"Opening file: $filename")
      s"file-handle-$filename"
    }.mapError(ex => new RuntimeException(s"Failed to open file: $filename", ex))
    
    val release = (handle: String) => ZIO.effect {
      println(s"Closing file handle: $handle")
    }.orDie
    
    ZManaged.make(acquire)(release).use(use)
  }
  
  // AI-SUGGESTION: Timeout and interruption handling
  def withTimeout[A](timeout: Duration)(task: Task[A]): Task[Option[A]] = {
    task.timeout(timeout)
  }
  
  // AI-SUGGESTION: Fiber-based concurrency
  def raceTasks[A, B](taskA: Task[A], taskB: Task[B]): Task[Either[A, B]] = {
    taskA.map(Left(_)) race taskB.map(Right(_))
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
      producer <- (1 to 100).map(i => s"item-$i").foreach(queue.offer).fork
      consumer <- queue.take.flatMap(item => putStrLn(s"Consumed: $item"))
                    .repeat(Schedule.recurs(99)).fork
      _        <- producer.join
      _        <- consumer.join
    } yield ()
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
  
  // AI-SUGGESTION: Custom validation DSL
  trait Validator[A, B] {
    def validate(value: A): ValidationResult[B]
  }
  
  object Validator {
    def apply[A, B](f: A => ValidationResult[B]): Validator[A, B] = new Validator[A, B] {
      def validate(value: A): ValidationResult[B] = f(value)
    }
    
    implicit class ValidatorOps[A, B](validator: Validator[A, B]) {
      def and[C](other: Validator[B, C]): Validator[A, C] = Validator { value =>
        validator.validate(value).andThen(other.validate)
      }
      
      def or(other: Validator[A, B]): Validator[A, B] = Validator { value =>
        validator.validate(value) orElse other.validate(value)
      }
    }
  }
  
  // AI-SUGGESTION: Predefined validators
  val nonEmptyString: Validator[String, String] = Validator { s =>
    if (s.nonEmpty) s.validNel else "String cannot be empty".invalidNel
  }
  
  val positiveInt: Validator[Int, Int] = Validator { i =>
    if (i > 0) i.validNel else "Number must be positive".invalidNel
  }
  
  val validEmail: Validator[String, String] = Validator(validateEmail)
}

// =============================================================================
// MONAD TRANSFORMERS
// =============================================================================

object MonadTransformerExamples {
  
  // AI-SUGGESTION: EitherT for error handling in Future context
  type Result[A] = EitherT[IO, AppError, A]
  
  def fetchUser(id: Long): Result[User] = {
    val user = User(id, "John Doe", "john@example.com", Instant.now())
    if (id > 0) EitherT.rightT(user)
    else EitherT.leftT(NotFoundError("User", id))
  }
  
  def fetchUserProfile(userId: Long): Result[String] = {
    for {
      user <- fetchUser(userId)
      profile <- EitherT.rightT[IO, AppError](s"Profile for ${user.name}")
    } yield profile
  }
  
  // AI-SUGGESTION: OptionT for handling optional values
  type MaybeResult[A] = OptionT[IO, A]
  
  def findUserByEmail(email: String): MaybeResult[User] = {
    val user = if (email.contains("@")) 
      Some(User(1, "John", email, Instant.now()))
    else None
    OptionT.fromOption[IO](user)
  }
  
  // AI-SUGGESTION: ReaderT for dependency injection
  case class AppConfig(dbUrl: String, apiKey: String)
  type ConfigReader[A] = ReaderT[IO, AppConfig, A]
  
  def getDbConnection: ConfigReader[String] = {
    ReaderT { config =>
      IO.delay(s"Connected to ${config.dbUrl}")
    }
  }
  
  def makeApiCall: ConfigReader[String] = {
    ReaderT { config =>
      IO.delay(s"API call with key: ${config.apiKey}")
    }
  }
  
  def businessLogic: ConfigReader[String] = {
    for {
      db  <- getDbConnection
      api <- makeApiCall
    } yield s"$db, $api"
  }
}

// =============================================================================
// FUNCTIONAL STREAMING
// =============================================================================

object StreamingExamples {
  import fs2._
  import fs2.concurrent.Queue
  
  // AI-SUGGESTION: FS2 streams for functional reactive programming
  def numberStream[F[_]: Sync]: Stream[F, Int] = {
    Stream.range(1, 100)
  }
  
  def processNumberStream[F[_]: Sync]: F[Unit] = {
    numberStream[F]
      .filter(_ % 2 == 0)
      .map(_ * 2)
      .take(10)
      .evalMap(n => Sync[F].delay(println(s"Processed: $n")))
      .compile
      .drain
  }
  
  // AI-SUGGESTION: Concurrent stream processing
  def concurrentProcessing[F[_]: Async]: F[Unit] = {
    val producer = Stream.range(1, 1000).covary[F]
    val processor = (n: Int) => Sync[F].delay(n * n)
    
    producer
      .mapAsync(maxConcurrent = 10)(processor)
      .evalMap(result => Sync[F].delay(println(s"Result: $result")))
      .compile
      .drain
  }
  
  // AI-SUGGESTION: Queue-based stream communication
  def queueBasedStream[F[_]: Async]: F[Unit] = {
    Queue.unbounded[F, Option[Int]].flatMap { queue =>
      val producer = Stream.range(1, 100)
        .evalMap(i => queue.enqueue1(Some(i)))
        .compile
        .drain
      
      val consumer = Stream.fromQueueNoneTerminated(queue)
        .evalMap(i => Sync[F].delay(println(s"Consumed: $i")))
        .compile
        .drain
      
      producer &> consumer
    }
  }
}

// =============================================================================
// MAIN APPLICATION EXAMPLES
// =============================================================================

object FunctionalEffectsExample extends IOApp {
  
  // AI-SUGGESTION: Cats Effect application
  def runCatsExample: IO[Unit] = {
    import CatsEffectExamples._
    
    val program = for {
      repository <- IO.pure(new InMemoryUserRepository[IO])
      service    = new UserService[IO](repository)
      
      // Create users
      result1 <- service.createUser("Alice", "alice@example.com")
      result2 <- service.createUser("Bob", "bob@example.com")
      result3 <- service.createUser("", "invalid") // Should fail validation
      
      // Process results
      _ <- result1.fold(
        error => IO.delay(println(s"Error creating Alice: $error")),
        user => IO.delay(println(s"Created user: $user"))
      )
      
      _ <- result2.fold(
        error => IO.delay(println(s"Error creating Bob: $error")),
        user => IO.delay(println(s"Created user: $user"))
      )
      
      _ <- result3.fold(
        error => IO.delay(println(s"Expected validation error: $error")),
        user => IO.delay(println(s"Unexpected success: $user"))
      )
      
    } yield ()
    
    program.handleErrorWith { error =>
      IO.delay(println(s"Application error: $error"))
    }
  }
  
  // AI-SUGGESTION: ZIO application example
  def runZIOExample: Task[Unit] = {
    import ZIOExamples._
    
    val program = for {
      _       <- putStrLn("=== ZIO Example ===")
      service <- ZIO.service[UserService]
      
      // Create users
      alice <- service.createUser("Alice Smith", "alice.smith@example.com")
      bob   <- service.createUser("Bob Johnson", "bob.johnson@example.com")
      
      _ <- putStrLn(s"Created users: $alice, $bob")
      
      // Get users
      retrievedAlice <- service.getUser(alice.id)
      retrievedBob   <- service.getUser(bob.id)
      
      _ <- putStrLn(s"Retrieved users: $retrievedAlice, $retrievedBob")
      
      // Update user
      updatedAlice <- service.updateUser(alice.id, Some("Alice Cooper"))
      _ <- putStrLn(s"Updated user: $updatedAlice")
      
    } yield ()
    
    program.catchAll { error =>
      putStrLn(s"ZIO Error: $error")
    }
  }
  
  def run(args: List[String]): IO[ExitCode] = {
    val program = for {
      _ <- IO.delay(println("=== Functional Effects Examples ==="))
      
      // Run Cats Effect example
      _ <- runCatsExample
      
      // Run ZIO example (converted to IO)
      runtime <- IO.delay(Runtime.default)
      _ <- IO.fromFuture(IO.delay(
        runtime.unsafeRunToFuture(
          runZIOExample.provideLayer(ZIOExamples.appLayer)
        )
      ))
      
      // Validation examples
      _ <- IO.delay {
        import ValidationExamples._
        
        val validRequest = CreateUserRequest("John Doe", "john@example.com", 25)
        val invalidRequest = CreateUserRequest("", "invalid-email", -5)
        
        println(s"Valid request validation: ${validateCreateUserRequest(validRequest)}")
        println(s"Invalid request validation: ${validateCreateUserRequest(invalidRequest)}")
      }
      
      _ <- IO.delay(println("=== End Functional Effects Examples ==="))
      
    } yield ExitCode.Success
    
    program.handleErrorWith { error =>
      IO.delay {
        println(s"Application failed with error: $error")
        ExitCode.Error
      }
    }
  }
} 