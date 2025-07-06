// AI-SUGGESTION: This file demonstrates advanced functional programming patterns in Scala
// including monads, type classes, algebraic data types, and immutable collections.
// Perfect for learning functional programming concepts and Scala's powerful type system.

package functional

import scala.annotation.tailrec
import scala.concurrent.Future
import scala.util.{Try, Success, Failure}
import scala.collection.immutable.{List, Map, Set}

// =============================================================================
// ALGEBRAIC DATA TYPES AND PATTERN MATCHING
// =============================================================================

// AI-SUGGESTION: Sealed traits and case classes create powerful ADTs
sealed trait Option[+A] {
  def map[B](f: A => B): Option[B] = this match {
    case Some(value) => Some(f(value))
    case None => None
  }
  
  def flatMap[B](f: A => Option[B]): Option[B] = this match {
    case Some(value) => f(value)
    case None => None
  }
  
  def filter(predicate: A => Boolean): Option[A] = this match {
    case Some(value) if predicate(value) => this
    case _ => None
  }
  
  def getOrElse[B >: A](default: => B): B = this match {
    case Some(value) => value
    case None => default
  }
}

case class Some[+A](value: A) extends Option[A]
case object None extends Option[Nothing]

// AI-SUGGESTION: Either type for error handling without exceptions
sealed trait Either[+E, +A] {
  def map[B](f: A => B): Either[E, B] = this match {
    case Right(value) => Right(f(value))
    case Left(error) => Left(error)
  }
  
  def flatMap[EE >: E, B](f: A => Either[EE, B]): Either[EE, B] = this match {
    case Right(value) => f(value)
    case Left(error) => Left(error)
  }
  
  def fold[B](onLeft: E => B, onRight: A => B): B = this match {
    case Left(error) => onLeft(error)
    case Right(value) => onRight(value)
  }
}

case class Left[+E](error: E) extends Either[E, Nothing]
case class Right[+A](value: A) extends Either[Nothing, A]

// =============================================================================
// TYPE CLASSES AND IMPLICIT PATTERNS
// =============================================================================

// AI-SUGGESTION: Type classes provide polymorphism without inheritance
trait Functor[F[_]] {
  def map[A, B](fa: F[A])(f: A => B): F[B]
}

trait Monad[F[_]] extends Functor[F] {
  def pure[A](a: A): F[A]
  def flatMap[A, B](fa: F[A])(f: A => F[B]): F[B]
  
  override def map[A, B](fa: F[A])(f: A => B): F[B] =
    flatMap(fa)(a => pure(f(a)))
}

// AI-SUGGESTION: Implicit instances for common types
implicit val optionMonad: Monad[Option] = new Monad[Option] {
  def pure[A](a: A): Option[A] = Some(a)
  def flatMap[A, B](fa: Option[A])(f: A => Option[B]): Option[B] = fa match {
    case Some(value) => f(value)
    case None => None
  }
}

implicit val listMonad: Monad[List] = new Monad[List] {
  def pure[A](a: A): List[A] = List(a)
  def flatMap[A, B](fa: List[A])(f: A => List[B]): List[B] = fa.flatMap(f)
}

// AI-SUGGESTION: Show and Eq type classes for polymorphic operations
trait Show[A] {
  def show(a: A): String
}

trait Eq[A] {
  def eqv(x: A, y: A): Boolean
}

implicit val intShow: Show[Int] = new Show[Int] {
  def show(a: Int): String = a.toString
}

implicit val stringShow: Show[String] = new Show[String] {
  def show(a: String): String = s"\"$a\""
}

implicit val intEq: Eq[Int] = new Eq[Int] {
  def eqv(x: Int, y: Int): Boolean = x == y
}

// =============================================================================
// IMMUTABLE DATA STRUCTURES
// =============================================================================

// AI-SUGGESTION: Custom immutable data structures with functional operations
case class ImmutableStack[A](items: List[A] = List.empty) {
  def push(item: A): ImmutableStack[A] = ImmutableStack(item :: items)
  
  def pop: (Option[A], ImmutableStack[A]) = items match {
    case head :: tail => (Some(head), ImmutableStack(tail))
    case Nil => (None, this)
  }
  
  def peek: Option[A] = items.headOption
  
  def isEmpty: Boolean = items.isEmpty
  
  def size: Int = items.length
}

// AI-SUGGESTION: Persistent data structure with structural sharing
sealed trait Tree[+A] {
  def insert[B >: A](value: B)(implicit ord: Ordering[B]): Tree[B] = this match {
    case Empty => Node(value, Empty, Empty)
    case Node(v, left, right) =>
      val cmp = ord.compare(value, v)
      if (cmp < 0) Node(v, left.insert(value), right)
      else if (cmp > 0) Node(v, left, right.insert(value))
      else this
  }
  
  def contains[B >: A](value: B)(implicit ord: Ordering[B]): Boolean = this match {
    case Empty => false
    case Node(v, left, right) =>
      val cmp = ord.compare(value, v)
      if (cmp < 0) left.contains(value)
      else if (cmp > 0) right.contains(value)
      else true
  }
  
  def toList: List[A] = {
    @tailrec
    def inOrder(trees: List[Tree[A]], acc: List[A]): List[A] = trees match {
      case Nil => acc.reverse
      case Empty :: rest => inOrder(rest, acc)
      case Node(v, left, right) :: rest =>
        inOrder(left :: Node(v, Empty, Empty) :: right :: rest, v :: acc)
    }
    inOrder(List(this), List.empty)
  }
}

case object Empty extends Tree[Nothing]
case class Node[A](value: A, left: Tree[A], right: Tree[A]) extends Tree[A]

// =============================================================================
// HIGHER-ORDER FUNCTIONS AND COMBINATORS
// =============================================================================

object FunctionalOps {
  
  // AI-SUGGESTION: Composition and partial application
  def compose[A, B, C](f: B => C, g: A => B): A => C = a => f(g(a))
  
  def curry[A, B, C](f: (A, B) => C): A => B => C = a => b => f(a, b)
  
  def uncurry[A, B, C](f: A => B => C): (A, B) => C = (a, b) => f(a)(b)
  
  // AI-SUGGESTION: Memoization for expensive computations
  def memoize[A, B](f: A => B): A => B = {
    val cache = scala.collection.mutable.Map.empty[A, B]
    a => cache.getOrElseUpdate(a, f(a))
  }
  
  // AI-SUGGESTION: Tail-recursive factorial with accumulator
  def factorial(n: Int): BigInt = {
    @tailrec
    def factorialAcc(n: Int, acc: BigInt): BigInt = {
      if (n <= 1) acc
      else factorialAcc(n - 1, n * acc)
    }
    factorialAcc(n, 1)
  }
  
  // AI-SUGGESTION: Fibonacci with memoization
  lazy val fibonacci: Int => BigInt = memoize {
    case 0 => 0
    case 1 => 1
    case n => fibonacci(n - 1) + fibonacci(n - 2)
  }
  
  // AI-SUGGESTION: Generic fold operations
  def foldLeft[A, B](list: List[A])(z: B)(op: (B, A) => B): B = {
    @tailrec
    def loop(remaining: List[A], acc: B): B = remaining match {
      case Nil => acc
      case head :: tail => loop(tail, op(acc, head))
    }
    loop(list, z)
  }
  
  def foldRight[A, B](list: List[A])(z: B)(op: (A, B) => B): B = list match {
    case Nil => z
    case head :: tail => op(head, foldRight(tail)(z)(op))
  }
}

// =============================================================================
// FUNCTIONAL VALIDATION
// =============================================================================

// AI-SUGGESTION: Validation that accumulates errors
sealed trait Validated[+E, +A] {
  def map[B](f: A => B): Validated[E, B] = this match {
    case Valid(value) => Valid(f(value))
    case invalid @ Invalid(_) => invalid
  }
  
  def flatMap[EE >: E, B](f: A => Validated[EE, B]): Validated[EE, B] = this match {
    case Valid(value) => f(value)
    case invalid @ Invalid(_) => invalid
  }
  
  def combine[EE >: E, B, C](other: Validated[EE, B])(f: (A, B) => C): Validated[List[EE], C] = {
    (this, other) match {
      case (Valid(a), Valid(b)) => Valid(f(a, b))
      case (Invalid(e1), Invalid(e2)) => Invalid(List(e1, e2))
      case (Invalid(e), _) => Invalid(List(e))
      case (_, Invalid(e)) => Invalid(List(e))
    }
  }
}

case class Valid[+A](value: A) extends Validated[Nothing, A]
case class Invalid[+E](error: E) extends Validated[E, Nothing]

// AI-SUGGESTION: Validation example with user data
case class User(name: String, email: String, age: Int)

object UserValidation {
  type ValidationResult[A] = Validated[String, A]
  
  def validateName(name: String): ValidationResult[String] = {
    if (name.nonEmpty && name.length <= 50) Valid(name)
    else Invalid("Name must be non-empty and at most 50 characters")
  }
  
  def validateEmail(email: String): ValidationResult[String] = {
    val emailRegex = """^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$""".r
    if (emailRegex.matches(email)) Valid(email)
    else Invalid("Invalid email format")
  }
  
  def validateAge(age: Int): ValidationResult[Int] = {
    if (age >= 0 && age <= 150) Valid(age)
    else Invalid("Age must be between 0 and 150")
  }
  
  def validateUser(name: String, email: String, age: Int): Validated[List[String], User] = {
    val nameResult = validateName(name)
    val emailResult = validateEmail(email)
    val ageResult = validateAge(age)
    
    (nameResult, emailResult, ageResult) match {
      case (Valid(n), Valid(e), Valid(a)) => Valid(User(n, e, a))
      case _ =>
        val errors = List(nameResult, emailResult, ageResult).collect {
          case Invalid(error) => error
        }
        Invalid(errors)
    }
  }
}

// =============================================================================
// LAZY EVALUATION AND STREAMS
// =============================================================================

// AI-SUGGESTION: Custom lazy stream implementation
sealed trait Stream[+A] {
  def headOption: Option[A] = this match {
    case Empty => None
    case Cons(h, _) => Some(h())
  }
  
  def tail: Stream[A] = this match {
    case Empty => Empty
    case Cons(_, t) => t()
  }
  
  def take(n: Int): Stream[A] = {
    if (n <= 0) Empty
    else this match {
      case Empty => Empty
      case Cons(h, t) => Cons(h, () => t().take(n - 1))
    }
  }
  
  def takeWhile(predicate: A => Boolean): Stream[A] = this match {
    case Empty => Empty
    case Cons(h, t) =>
      lazy val head = h()
      if (predicate(head)) Cons(() => head, () => t().takeWhile(predicate))
      else Empty
  }
  
  def map[B](f: A => B): Stream[B] = this match {
    case Empty => Empty
    case Cons(h, t) => Cons(() => f(h()), () => t().map(f))
  }
  
  def filter(predicate: A => Boolean): Stream[A] = this match {
    case Empty => Empty
    case Cons(h, t) =>
      lazy val head = h()
      if (predicate(head)) Cons(() => head, () => t().filter(predicate))
      else t().filter(predicate)
  }
  
  def toList: List[A] = {
    @tailrec
    def loop(stream: Stream[A], acc: List[A]): List[A] = stream match {
      case Empty => acc.reverse
      case Cons(h, t) => loop(t(), h() :: acc)
    }
    loop(this, List.empty)
  }
}

case object Empty extends Stream[Nothing]
case class Cons[+A](head: () => A, tail: () => Stream[A]) extends Stream[A]

object Stream {
  def cons[A](hd: => A, tl: => Stream[A]): Stream[A] = {
    lazy val head = hd
    lazy val tail = tl
    Cons(() => head, () => tail)
  }
  
  def apply[A](as: A*): Stream[A] = {
    if (as.isEmpty) Empty
    else cons(as.head, apply(as.tail: _*))
  }
  
  // AI-SUGGESTION: Infinite streams
  def from(n: Int): Stream[Int] = cons(n, from(n + 1))
  
  def constant[A](a: A): Stream[A] = cons(a, constant(a))
  
  def fibonacci: Stream[BigInt] = {
    def fib(a: BigInt, b: BigInt): Stream[BigInt] = cons(a, fib(b, a + b))
    fib(0, 1)
  }
  
  def unfold[A, S](state: S)(f: S => Option[(A, S)]): Stream[A] = {
    f(state) match {
      case None => Empty
      case Some((a, s)) => cons(a, unfold(s)(f))
    }
  }
}

// =============================================================================
// FUNCTIONAL ERROR HANDLING
// =============================================================================

// AI-SUGGESTION: Try monad for exception handling
object TryOps {
  def attempt[A](computation: => A): Try[A] = {
    try Success(computation)
    catch { case e: Exception => Failure(e) }
  }
  
  def sequence[A](tries: List[Try[A]]): Try[List[A]] = {
    tries.foldRight(Success(List.empty[A]): Try[List[A]]) { (tryA, tryList) =>
      for {
        a <- tryA
        list <- tryList
      } yield a :: list
    }
  }
  
  def traverse[A, B](list: List[A])(f: A => Try[B]): Try[List[B]] = {
    sequence(list.map(f))
  }
}

// =============================================================================
// EXAMPLE USAGE AND TESTING
// =============================================================================

object FunctionalExample extends App {
  
  // AI-SUGGESTION: Demonstrate type class usage
  def show[A](value: A)(implicit showInstance: Show[A]): String = {
    showInstance.show(value)
  }
  
  def equal[A](x: A, y: A)(implicit eqInstance: Eq[A]): Boolean = {
    eqInstance.eqv(x, y)
  }
  
  // AI-SUGGESTION: Example usage
  println("=== Functional Programming Examples ===")
  
  // Option and Either examples
  val someValue: Option[Int] = Some(42)
  val noneValue: Option[Int] = None
  
  val result1 = someValue.map(_ * 2).getOrElse(0)
  val result2 = noneValue.map(_ * 2).getOrElse(0)
  
  println(s"Option examples: $result1, $result2")
  
  // Either for error handling
  val rightValue: Either[String, Int] = Right(10)
  val leftValue: Either[String, Int] = Left("Error occurred")
  
  val eitherResult = rightValue.map(_ * 3).fold(
    error => s"Failed: $error",
    success => s"Success: $success"
  )
  
  println(s"Either example: $eitherResult")
  
  // Immutable data structures
  val stack = ImmutableStack[Int]()
    .push(1)
    .push(2)
    .push(3)
  
  val (popped, newStack) = stack.pop
  println(s"Stack example: popped=$popped, remaining=${newStack.items}")
  
  // Tree operations
  val tree = Empty
    .insert(5)
    .insert(3)
    .insert(7)
    .insert(1)
    .insert(9)
  
  println(s"Tree contains 7: ${tree.contains(7)}")
  println(s"Tree as list: ${tree.toList}")
  
  // Higher-order functions
  val factorial10 = FunctionalOps.factorial(10)
  val fibonacci10 = FunctionalOps.fibonacci(10)
  
  println(s"Factorial 10: $factorial10")
  println(s"Fibonacci 10: $fibonacci10")
  
  // Validation example
  val validUser = UserValidation.validateUser("John Doe", "john@example.com", 30)
  val invalidUser = UserValidation.validateUser("", "invalid-email", -5)
  
  println(s"Valid user: $validUser")
  println(s"Invalid user: $invalidUser")
  
  // Stream operations
  val infiniteOnes = Stream.constant(1)
  val first10Ones = infiniteOnes.take(10).toList
  
  val first10Fibs = Stream.fibonacci.take(10).toList
  
  println(s"First 10 ones: $first10Ones")
  println(s"First 10 Fibonacci numbers: $first10Fibs")
  
  // Type class usage
  println(s"Show int: ${show(42)}")
  println(s"Show string: ${show("hello")}")
  println(s"Equal ints: ${equal(5, 5)}")
  
  println("=== End Examples ===")
} 