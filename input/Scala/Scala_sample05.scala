package controllers

import javax.inject._
import play.api._
import play.api.mvc._
import play.api.libs.json._
import play.api.libs.functional.syntax._
import play.api.data._
import play.api.data.Forms._
import play.api.i18n._
import play.api.cache._
import play.api.db.slick.DatabaseConfigProvider
import slick.jdbc.JdbcProfile

import scala.concurrent.{Future, ExecutionContext}
import scala.util.{Success, Failure}
import java.time.{Instant, LocalDateTime}
import java.util.UUID

case class User(
  id: Option[Long] = None,
  email: String,
  username: String,
  firstName: String,
  lastName: String,
  isActive: Boolean = true,
  createdAt: Option[Instant] = None,
  updatedAt: Option[Instant] = None
)

case class UserRegistration(
  email: String,
  username: String,
  password: String,
  firstName: String,
  lastName: String
)

case class UserLogin(email: String, password: String)

case class Product(
  id: Option[Long] = None,
  name: String,
  description: String,
  price: BigDecimal,
  category: String,
  inStock: Boolean = true,
  createdAt: Option[Instant] = None
)

case class Order(
  id: Option[Long] = None,
  userId: Long,
  items: List[OrderItem],
  totalAmount: BigDecimal,
  status: OrderStatus,
  createdAt: Option[Instant] = None
)

case class OrderItem(
  productId: Long,
  quantity: Int,
  price: BigDecimal
)

sealed trait OrderStatus
case object Pending extends OrderStatus
case object Processing extends OrderStatus
case object Shipped extends OrderStatus
case object Delivered extends OrderStatus
case object Cancelled extends OrderStatus

object JsonFormats {
  implicit val userWrites: Writes[User] = Json.writes[User]
  implicit val userReads: Reads[User] = Json.reads[User]
  
  implicit val userRegistrationReads: Reads[UserRegistration] = Json.reads[UserRegistration]
  implicit val userLoginReads: Reads[UserLogin] = Json.reads[UserLogin]
  
  implicit val productWrites: Writes[Product] = Json.writes[Product]
  implicit val productReads: Reads[Product] = Json.reads[Product]
  
  implicit val orderItemWrites: Writes[OrderItem] = Json.writes[OrderItem]
  implicit val orderItemReads: Reads[OrderItem] = Json.reads[OrderItem]
  
  implicit val orderStatusWrites: Writes[OrderStatus] = Writes[OrderStatus] {
    case Pending => JsString("pending")
    case Processing => JsString("processing")
    case Shipped => JsString("shipped")
    case Delivered => JsString("delivered")
    case Cancelled => JsString("cancelled")
  }
  
  implicit val orderStatusReads: Reads[OrderStatus] = Reads[OrderStatus] { json =>
    json.validate[String].flatMap {
      case "pending" => JsSuccess(Pending)
      case "processing" => JsSuccess(Processing)
      case "shipped" => JsSuccess(Shipped)
      case "delivered" => JsSuccess(Delivered)
      case "cancelled" => JsSuccess(Cancelled)
      case _ => JsError("Invalid order status")
    }
  }
  
  implicit val orderWrites: Writes[Order] = Json.writes[Order]
  implicit val orderReads: Reads[Order] = Json.reads[Order]
  
  case class ErrorResponse(message: String, code: String)
  implicit val errorResponseWrites: Writes[ErrorResponse] = Json.writes[ErrorResponse]
  
  case class SuccessResponse[T](data: T, message: String = "Success")
  implicit def successResponseWrites[T](implicit tWrites: Writes[T]): Writes[SuccessResponse[T]] = 
    Json.writes[SuccessResponse[T]]
}

@Singleton
class UserRepository @Inject()(dbConfigProvider: DatabaseConfigProvider)(implicit ec: ExecutionContext) {
  private val dbConfig = dbConfigProvider.get[JdbcProfile]
  
  import dbConfig._
  import profile.api._
  
  class Users(tag: Tag) extends Table[User](tag, "users") {
    def id = column[Long]("id", O.PrimaryKey, O.AutoInc)
    def email = column[String]("email", O.Unique)
    def username = column[String]("username", O.Unique)
    def firstName = column[String]("first_name")
    def lastName = column[String]("last_name")
    def isActive = column[Boolean]("is_active")
    def createdAt = column[Instant]("created_at")
    def updatedAt = column[Instant]("updated_at")
    
    def * = (id.?, email, username, firstName, lastName, isActive, createdAt.?, updatedAt.?) <> ((User.apply _).tupled, User.unapply)
  }
  
  private val users = TableQuery[Users]
  
  def create(user: User): Future[User] = {
    val userWithTimestamp = user.copy(
      createdAt = Some(Instant.now()),
      updatedAt = Some(Instant.now())
    )
    val insertQuery = users returning users.map(_.id) into ((user, id) => user.copy(id = Some(id)))
    db.run(insertQuery += userWithTimestamp)
  }
  
  def findById(id: Long): Future[Option[User]] = {
    db.run(users.filter(_.id === id).result.headOption)
  }
  
  def findByEmail(email: String): Future[Option[User]] = {
    db.run(users.filter(_.email === email).result.headOption)
  }
  
  def findByUsername(username: String): Future[Option[User]] = {
    db.run(users.filter(_.username === username).result.headOption)
  }
  
  def list(page: Int = 0, pageSize: Int = 10): Future[List[User]] = {
    db.run(users.drop(page * pageSize).take(pageSize).result).map(_.toList)
  }
  
  def update(id: Long, user: User): Future[Option[User]] = {
    val userWithTimestamp = user.copy(
      id = Some(id),
      updatedAt = Some(Instant.now())
    )
    val updateQuery = users.filter(_.id === id).update(userWithTimestamp)
    db.run(updateQuery).flatMap { rowsAffected =>
      if (rowsAffected > 0) findById(id) else Future.successful(None)
    }
  }
  
  def delete(id: Long): Future[Boolean] = {
    db.run(users.filter(_.id === id).delete).map(_ > 0)
  }
}

@Singleton
class ProductRepository @Inject()(dbConfigProvider: DatabaseConfigProvider)(implicit ec: ExecutionContext) {
  private val dbConfig = dbConfigProvider.get[JdbcProfile]
  
  import dbConfig._
  import profile.api._
  
  class Products(tag: Tag) extends Table[Product](tag, "products") {
    def id = column[Long]("id", O.PrimaryKey, O.AutoInc)
    def name = column[String]("name")
    def description = column[String]("description")
    def price = column[BigDecimal]("price")
    def category = column[String]("category")
    def inStock = column[Boolean]("in_stock")
    def createdAt = column[Instant]("created_at")
    
    def * = (id.?, name, description, price, category, inStock, createdAt.?) <> ((Product.apply _).tupled, Product.unapply)
  }
  
  private val products = TableQuery[Products]
  
  def create(product: Product): Future[Product] = {
    val productWithTimestamp = product.copy(createdAt = Some(Instant.now()))
    val insertQuery = products returning products.map(_.id) into ((product, id) => product.copy(id = Some(id)))
    db.run(insertQuery += productWithTimestamp)
  }
  
  def findById(id: Long): Future[Option[Product]] = {
    db.run(products.filter(_.id === id).result.headOption)
  }
  
  def findByCategory(category: String): Future[List[Product]] = {
    db.run(products.filter(_.category === category).result).map(_.toList)
  }
  
  def search(query: String): Future[List[Product]] = {
    db.run(products.filter(p => p.name.like(s"%$query%") || p.description.like(s"%$query%")).result).map(_.toList)
  }
  
  def list(page: Int = 0, pageSize: Int = 20): Future[List[Product]] = {
    db.run(products.drop(page * pageSize).take(pageSize).result).map(_.toList)
  }
  
  def update(id: Long, product: Product): Future[Option[Product]] = {
    val updateQuery = products.filter(_.id === id).update(product.copy(id = Some(id)))
    db.run(updateQuery).flatMap { rowsAffected =>
      if (rowsAffected > 0) findById(id) else Future.successful(None)
    }
  }
  
  def delete(id: Long): Future[Boolean] = {
    db.run(products.filter(_.id === id).delete).map(_ > 0)
  }
}

@Singleton
class UserService @Inject()(
  userRepository: UserRepository,
  cache: AsyncCacheApi
)(implicit ec: ExecutionContext) {
  
  def registerUser(registration: UserRegistration): Future[Either[String, User]] = {
    for {
      existingByEmail <- userRepository.findByEmail(registration.email)
      existingByUsername <- userRepository.findByUsername(registration.username)
      result <- {
        if (existingByEmail.isDefined) {
          Future.successful(Left("Email already registered"))
        } else if (existingByUsername.isDefined) {
          Future.successful(Left("Username already taken"))
        } else {
          val newUser = User(
            email = registration.email,
            username = registration.username,
            firstName = registration.firstName,
            lastName = registration.lastName
          )
          userRepository.create(newUser).map(Right(_))
        }
      }
    } yield result
  }
  
  def authenticateUser(login: UserLogin): Future[Option[User]] = {
    userRepository.findByEmail(login.email).filter(_.exists(_.isActive))
  }
  
  def getUserById(id: Long): Future[Option[User]] = {
    cache.getOrElseUpdate(s"user:$id", 5.minutes) {
      userRepository.findById(id)
    }
  }
  
  def updateUserProfile(id: Long, updates: Map[String, String]): Future[Option[User]] = {
    getUserById(id).flatMap {
      case Some(user) =>
        val updatedUser = user.copy(
          firstName = updates.getOrElse("firstName", user.firstName),
          lastName = updates.getOrElse("lastName", user.lastName)
        )
        userRepository.update(id, updatedUser).andThen {
          case Success(_) => cache.remove(s"user:$id")
        }
      case None => Future.successful(None)
    }
  }
  
  def deactivateUser(id: Long): Future[Boolean] = {
    getUserById(id).flatMap {
      case Some(user) =>
        userRepository.update(id, user.copy(isActive = false)).map(_.isDefined).andThen {
          case Success(_) => cache.remove(s"user:$id")
        }
      case None => Future.successful(false)
    }
  }
}

@Singleton
class ProductService @Inject()(
  productRepository: ProductRepository,
  cache: AsyncCacheApi
)(implicit ec: ExecutionContext) {
  
  def createProduct(product: Product): Future[Product] = {
    productRepository.create(product)
  }
  
  def getProduct(id: Long): Future[Option[Product]] = {
    cache.getOrElseUpdate(s"product:$id", 10.minutes) {
      productRepository.findById(id)
    }
  }
  
  def searchProducts(query: String, category: Option[String]): Future[List[Product]] = {
    category match {
      case Some(cat) => productRepository.findByCategory(cat)
      case None => productRepository.search(query)
    }
  }
  
  def getProductsCatalog(page: Int, pageSize: Int): Future[List[Product]] = {
    cache.getOrElseUpdate(s"products:$page:$pageSize", 5.minutes) {
      productRepository.list(page, pageSize)
    }
  }
  
  def updateProduct(id: Long, product: Product): Future[Option[Product]] = {
    productRepository.update(id, product).andThen {
      case Success(_) => cache.remove(s"product:$id")
    }
  }
  
  def deleteProduct(id: Long): Future[Boolean] = {
    productRepository.delete(id).andThen {
      case Success(_) => cache.remove(s"product:$id")
    }
  }
}

class AuthenticatedRequest[A](val user: User, request: Request[A]) extends WrappedRequest[A](request)

@Singleton
class AuthenticatedAction @Inject()(
  userService: UserService,
  parser: BodyParsers.Default
)(implicit ec: ExecutionContext) extends ActionBuilder[AuthenticatedRequest, AnyContent] {
  
  override def parser: BodyParser[AnyContent] = parser
  override protected def executionContext: ExecutionContext = ec
  
  override def invokeBlock[A](request: Request[A], block: AuthenticatedRequest[A] => Future[Result]): Future[Result] = {
    extractUser(request) match {
      case Some(userId) =>
        userService.getUserById(userId).flatMap {
          case Some(user) if user.isActive =>
            block(new AuthenticatedRequest(user, request))
          case _ =>
            Future.successful(Results.Unauthorized(Json.obj("error" -> "Invalid or inactive user")))
        }
      case None =>
        Future.successful(Results.Unauthorized(Json.obj("error" -> "Authentication required")))
    }
  }
  
  private def extractUser(request: RequestHeader): Option[Long] = {
    request.headers.get("Authorization").flatMap { authHeader =>
      if (authHeader.startsWith("Bearer ")) {
        authHeader.substring(7).toLongOption
      } else None
    }
  }
}

@Singleton
class UserController @Inject()(
  cc: ControllerComponents,
  userService: UserService,
  authenticatedAction: AuthenticatedAction
)(implicit ec: ExecutionContext) extends AbstractController(cc) {
  
  import JsonFormats._
  
  def register(): Action[JsValue] = Action.async(parse.json) { implicit request =>
    request.body.validate[UserRegistration].fold(
      errors => Future.successful(BadRequest(Json.obj("error" -> JsError.toJson(errors)))),
      registration => {
        userService.registerUser(registration).map {
          case Right(user) => 
            Created(Json.toJson(SuccessResponse(user, "User registered successfully")))
          case Left(error) => 
            BadRequest(Json.toJson(ErrorResponse(error, "REGISTRATION_FAILED")))
        }
      }
    )
  }
  
  def login(): Action[JsValue] = Action.async(parse.json) { implicit request =>
    request.body.validate[UserLogin].fold(
      errors => Future.successful(BadRequest(Json.obj("error" -> JsError.toJson(errors)))),
      login => {
        userService.authenticateUser(login).map {
          case Some(user) =>
            val token = s"token-${user.id.get}"
            Ok(Json.obj(
              "user" -> Json.toJson(user),
              "token" -> token,
              "message" -> "Login successful"
            ))
          case None =>
            Unauthorized(Json.toJson(ErrorResponse("Invalid credentials", "AUTH_FAILED")))
        }
      }
    )
  }
  
  def getProfile(): Action[AnyContent] = authenticatedAction.async { implicit request =>
    Future.successful(Ok(Json.toJson(SuccessResponse(request.user))))
  }
  
  def updateProfile(): Action[JsValue] = authenticatedAction.async(parse.json) { implicit request =>
    request.body.validate[Map[String, String]].fold(
      errors => Future.successful(BadRequest(Json.obj("error" -> JsError.toJson(errors)))),
      updates => {
        userService.updateUserProfile(request.user.id.get, updates).map {
          case Some(user) => 
            Ok(Json.toJson(SuccessResponse(user, "Profile updated successfully")))
          case None => 
            NotFound(Json.toJson(ErrorResponse("User not found", "USER_NOT_FOUND")))
        }
      }
    )
  }
  
  def deactivateAccount(): Action[AnyContent] = authenticatedAction.async { implicit request =>
    userService.deactivateUser(request.user.id.get).map {
      case true => Ok(Json.obj("message" -> "Account deactivated successfully"))
      case false => InternalServerError(Json.toJson(ErrorResponse("Failed to deactivate account", "DEACTIVATION_FAILED")))
    }
  }
}

@Singleton
class ProductController @Inject()(
  cc: ControllerComponents,
  productService: ProductService,
  authenticatedAction: AuthenticatedAction
)(implicit ec: ExecutionContext) extends AbstractController(cc) {
  
  import JsonFormats._
  
  def list(page: Int, pageSize: Int): Action[AnyContent] = Action.async { implicit request =>
    productService.getProductsCatalog(page, pageSize).map { products =>
      Ok(Json.toJson(SuccessResponse(products)))
    }
  }
  
  def get(id: Long): Action[AnyContent] = Action.async { implicit request =>
    productService.getProduct(id).map {
      case Some(product) => Ok(Json.toJson(SuccessResponse(product)))
      case None => NotFound(Json.toJson(ErrorResponse("Product not found", "PRODUCT_NOT_FOUND")))
    }
  }
  
  def search(q: String, category: Option[String]): Action[AnyContent] = Action.async { implicit request =>
    productService.searchProducts(q, category).map { products =>
      Ok(Json.toJson(SuccessResponse(products)))
    }
  }
  
  def create(): Action[JsValue] = authenticatedAction.async(parse.json) { implicit request =>
    request.body.validate[Product].fold(
      errors => Future.successful(BadRequest(Json.obj("error" -> JsError.toJson(errors)))),
      product => {
        productService.createProduct(product).map { createdProduct =>
          Created(Json.toJson(SuccessResponse(createdProduct, "Product created successfully")))
        }
      }
    )
  }
  
  def update(id: Long): Action[JsValue] = authenticatedAction.async(parse.json) { implicit request =>
    request.body.validate[Product].fold(
      errors => Future.successful(BadRequest(Json.obj("error" -> JsError.toJson(errors)))),
      product => {
        productService.updateProduct(id, product).map {
          case Some(updatedProduct) => 
            Ok(Json.toJson(SuccessResponse(updatedProduct, "Product updated successfully")))
          case None => 
            NotFound(Json.toJson(ErrorResponse("Product not found", "PRODUCT_NOT_FOUND")))
        }
      }
    )
  }
  
  def delete(id: Long): Action[AnyContent] = authenticatedAction.async { implicit request =>
    productService.deleteProduct(id).map {
      case true => Ok(Json.obj("message" -> "Product deleted successfully"))
      case false => NotFound(Json.toJson(ErrorResponse("Product not found", "PRODUCT_NOT_FOUND")))
    }
  }
}

class ApplicationModule extends play.api.inject.Module {
  override def bindings(environment: Environment, configuration: Configuration) = {
    Seq(
      bind[UserRepository].toSelf.asEagerSingleton(),
      bind[ProductRepository].toSelf.asEagerSingleton(),
      bind[UserService].toSelf.asEagerSingleton(),
      bind[ProductService].toSelf.asEagerSingleton(),
      bind[AuthenticatedAction].toSelf.asEagerSingleton()
    )
  }
}

@Singleton
class WebSocketController @Inject()(
  cc: ControllerComponents,
  actorSystem: ActorSystem
)(implicit ec: ExecutionContext) extends AbstractController(cc) {
  
  import akka.actor._
  import akka.stream.scaladsl._
  import play.api.libs.streams.ActorFlow
  
  def socket: WebSocket = WebSocket.accept[String, String] { request =>
    ActorFlow.actorRef { out =>
      WebSocketActor.props(out)
    }
  }
  
  object WebSocketActor {
    def props(out: ActorRef): Props = Props(new WebSocketActor(out))
  }
  
  class WebSocketActor(out: ActorRef) extends Actor {
    override def receive: Receive = {
      case msg: String =>
        val response = s"Echo: $msg at ${Instant.now()}"
        out ! response
    }
  }
}

@Singleton
class ErrorHandler @Inject()() extends HttpErrorHandler {
  import JsonFormats._
  
  def onClientError(request: RequestHeader, statusCode: Int, message: String): Future[Result] = {
    Future.successful {
      Status(statusCode)(Json.toJson(ErrorResponse(message, s"CLIENT_ERROR_$statusCode")))
    }
  }
  
  def onServerError(request: RequestHeader, exception: Throwable): Future[Result] = {
    Logger.error(s"Server error: ${exception.getMessage}", exception)
    Future.successful {
      InternalServerError(Json.toJson(ErrorResponse("Internal server error", "SERVER_ERROR")))
    }
  }
}

@Singleton
class LoggingFilter @Inject()(implicit ec: ExecutionContext) extends Filter {
  
  def apply(nextFilter: RequestHeader => Future[Result])(requestHeader: RequestHeader): Future[Result] = {
    val startTime = System.currentTimeMillis()
    
    nextFilter(requestHeader).map { result =>
      val endTime = System.currentTimeMillis()
      val requestTime = endTime - startTime
      
      Logger.info(s"${requestHeader.method} ${requestHeader.uri} -> ${result.header.status} (${requestTime}ms)")
      
      result.withHeaders("X-Request-Time" -> requestTime.toString)
    }
  }
}

object PlayWebApplicationExample {
  
  val databaseConfig = """
    slick.dbs.default.profile = "slick.jdbc.H2Profile$"
    slick.dbs.default.db.driver = "org.h2.Driver"
    slick.dbs.default.db.url = "jdbc:h2:mem:play"
    slick.dbs.default.db.user = ""
    slick.dbs.default.db.password = ""
    
    play.cache.defaultCache = "redis"
    play.cache.redis.host = "localhost"
    play.cache.redis.port = 6379
    
    play.http.secret.key = "changeme"
    
    play.filters.enabled += "filters.LoggingFilter"
    
    play.http.errorHandler = "ErrorHandler"
  """
  
  def main(args: Array[String]): Unit = {
    println("=== Play Framework Web Application ===")
    println("This application demonstrates:")
    println("  - RESTful API with JSON serialization")
    println("  - Database access with Slick ORM")
    println("  - Authentication and authorization")
    println("  - Caching with Redis")
    println("  - WebSocket support for real-time features")
    println("  - Error handling and request logging")
    println("  - Dependency injection with Guice")
    println("  - Reactive programming with Futures")
    println("")
    println("To run: sbt run")
    println("API endpoints available at: http://localhost:9000/api/")
    println("=== End Play Framework Example ===")
  }
} 