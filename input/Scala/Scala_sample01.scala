import akka.actor.typed._
import akka.actor.typed.scaladsl._
import akka.cluster.typed._
import akka.cluster.sharding.typed.scaladsl._
import akka.persistence.typed.PersistenceId
import akka.persistence.typed.scaladsl._
import akka.stream.scaladsl._
import akka.util.Timeout
import akka.pattern.StatusReply

import scala.concurrent.duration._
import scala.concurrent.Future
import scala.util.{Success, Failure, Random}
import java.time.Instant
import java.util.UUID

object Protocol {
  
  sealed trait UserCommand
  case class CreateUser(name: String, email: String, replyTo: ActorRef[StatusReply[UserCreated]]) extends UserCommand
  case class GetUser(userId: String, replyTo: ActorRef[StatusReply[User]]) extends UserCommand
  case class UpdateUser(userId: String, name: String, email: String, replyTo: ActorRef[StatusReply[UserUpdated]]) extends UserCommand
  case class DeleteUser(userId: String, replyTo: ActorRef[StatusReply[UserDeleted]]) extends UserCommand
  
  sealed trait UserEvent
  case class UserCreated(userId: String, name: String, email: String, timestamp: Instant) extends UserEvent
  case class UserUpdated(userId: String, name: String, email: String, timestamp: Instant) extends UserEvent
  case class UserDeleted(userId: String, timestamp: Instant) extends UserEvent
  
  case class User(userId: String, name: String, email: String, createdAt: Instant)
  
  sealed trait OrderCommand
  case class CreateOrder(customerId: String, items: List[OrderItem], replyTo: ActorRef[StatusReply[OrderCreated]]) extends OrderCommand
  case class ProcessPayment(orderId: String, amount: BigDecimal, replyTo: ActorRef[StatusReply[PaymentProcessed]]) extends OrderCommand
  case class ShipOrder(orderId: String, address: String, replyTo: ActorRef[StatusReply[OrderShipped]]) extends OrderCommand
  case class GetOrderStatus(orderId: String, replyTo: ActorRef[StatusReply[Order]]) extends OrderCommand
  
  sealed trait OrderEvent
  case class OrderCreated(orderId: String, customerId: String, items: List[OrderItem], timestamp: Instant) extends OrderEvent
  case class PaymentProcessed(orderId: String, amount: BigDecimal, timestamp: Instant) extends OrderEvent
  case class OrderShipped(orderId: String, address: String, timestamp: Instant) extends OrderEvent
  
  case class OrderItem(productId: String, name: String, price: BigDecimal, quantity: Int)
  case class Order(orderId: String, customerId: String, items: List[OrderItem], 
                  status: OrderStatus, totalAmount: BigDecimal, createdAt: Instant)
  
  sealed trait OrderStatus
  case object Pending extends OrderStatus
  case object Paid extends OrderStatus
  case object Shipped extends OrderStatus
  case object Delivered extends OrderStatus
  
  sealed trait NotificationCommand
  case class SendEmail(to: String, subject: String, body: String, replyTo: ActorRef[StatusReply[EmailSent]]) extends NotificationCommand
  case class SendSMS(to: String, message: String, replyTo: ActorRef[StatusReply[SMSSent]]) extends NotificationCommand
  
  case class EmailSent(messageId: String, timestamp: Instant)
  case class SMSSent(messageId: String, timestamp: Instant)
  
  sealed trait MetricsCommand
  case class RecordMetric(name: String, value: Double, tags: Map[String, String]) extends MetricsCommand
  case class GetMetrics(replyTo: ActorRef[MetricsSnapshot]) extends MetricsCommand
  
  case class MetricsSnapshot(metrics: Map[String, MetricData], timestamp: Instant)
  case class MetricData(values: List[Double], average: Double, count: Long)
  
  sealed trait ClusterCommand
  case class JoinCluster(address: String) extends ClusterCommand
  case class LeaveCluster() extends ClusterCommand
  case class GetClusterState(replyTo: ActorRef[ClusterState]) extends ClusterCommand
  
  case class ClusterState(members: Set[String], leader: Option[String])
}

object UserActor {
  import Protocol._
  
  def apply(userId: String): Behavior[UserCommand] = {
    Behaviors.setup { context =>
      EventSourcedBehavior[UserCommand, UserEvent, UserState](
        persistenceId = PersistenceId.ofUniqueId(s"user-$userId"),
        emptyState = UserState.empty,
        commandHandler = commandHandler(context),
        eventHandler = eventHandler
      ).withRetention(RetentionCriteria.snapshotEvery(numberOfEvents = 100, keepNSnapshots = 2))
    }
  }
  
  private def commandHandler(context: ActorContext[UserCommand]): (UserState, UserCommand) => Effect[UserEvent, UserState] = {
    (state, command) =>
      command match {
        case CreateUser(name, email, replyTo) =>
          if (state.user.isDefined) {
            Effect.reply(replyTo)(StatusReply.error("User already exists"))
          } else {
            val event = UserCreated(state.userId, name, email, Instant.now())
            Effect.persist(event).thenReply(replyTo)(_ => StatusReply.success(event))
          }
          
        case GetUser(_, replyTo) =>
          state.user match {
            case Some(user) => Effect.reply(replyTo)(StatusReply.success(user))
            case None => Effect.reply(replyTo)(StatusReply.error("User not found"))
          }
          
        case UpdateUser(_, name, email, replyTo) =>
          if (state.user.isDefined) {
            val event = UserUpdated(state.userId, name, email, Instant.now())
            Effect.persist(event).thenReply(replyTo)(_ => StatusReply.success(event))
          } else {
            Effect.reply(replyTo)(StatusReply.error("User not found"))
          }
          
        case DeleteUser(_, replyTo) =>
          if (state.user.isDefined) {
            val event = UserDeleted(state.userId, Instant.now())
            Effect.persist(event).thenReply(replyTo)(_ => StatusReply.success(event))
          } else {
            Effect.reply(replyTo)(StatusReply.error("User not found"))
          }
      }
  }
  
  private def eventHandler: (UserState, UserEvent) => UserState = {
    (state, event) =>
      event match {
        case UserCreated(userId, name, email, timestamp) =>
          state.copy(user = Some(User(userId, name, email, timestamp)))
          
        case UserUpdated(userId, name, email, timestamp) =>
          state.copy(user = state.user.map(_.copy(name = name, email = email)))
          
        case UserDeleted(_, _) =>
          state.copy(user = None)
      }
  }
  
  case class UserState(userId: String, user: Option[User]) {
    def isEmpty: Boolean = user.isEmpty
  }
  
  object UserState {
    def empty: UserState = UserState("", None)
  }
}

object OrderProcessorActor {
  import Protocol._
  
  def apply(): Behavior[OrderCommand] = {
    Behaviors.setup { context =>
      val notificationActor = context.spawn(NotificationActor(), "notification-actor")
      val metricsActor = context.spawn(MetricsActor(), "metrics-actor")
      
      orderProcessing(Map.empty, notificationActor, metricsActor)
    }
  }
  
  private def orderProcessing(
    orders: Map[String, Order],
    notificationActor: ActorRef[Protocol.NotificationCommand],
    metricsActor: ActorRef[Protocol.MetricsCommand]
  ): Behavior[OrderCommand] = {
    Behaviors.receive { (context, message) =>
      message match {
        case CreateOrder(customerId, items, replyTo) =>
          val orderId = UUID.randomUUID().toString
          val totalAmount = items.map(item => item.price * item.quantity).sum
          val order = Order(orderId, customerId, items, Pending, totalAmount, Instant.now())
          
          metricsActor ! RecordMetric("orders.created", 1.0, Map("customer" -> customerId))
          metricsActor ! RecordMetric("orders.total_amount", totalAmount.toDouble, Map("currency" -> "USD"))
          
          replyTo ! StatusReply.success(OrderCreated(orderId, customerId, items, order.createdAt))
          orderProcessing(orders + (orderId -> order), notificationActor, metricsActor)
          
        case ProcessPayment(orderId, amount, replyTo) =>
          orders.get(orderId) match {
            case Some(order) if order.status == Pending =>
              val success = Random.nextBoolean() 
              
              if (success && amount >= order.totalAmount) {
                val updatedOrder = order.copy(status = Paid)
                
                notificationActor ! SendEmail(
                  to = s"customer-${order.customerId}@example.com",
                  subject = s"Payment Confirmation - Order $orderId",
                  body = s"Your payment of $$${amount} has been processed successfully.",
                  replyTo = context.system.ignoreRef
                )
                
                metricsActor ! RecordMetric("payments.processed", amount.toDouble, Map("status" -> "success"))
                replyTo ! StatusReply.success(PaymentProcessed(orderId, amount, Instant.now()))
                orderProcessing(orders + (orderId -> updatedOrder), notificationActor, metricsActor)
              } else {
                metricsActor ! RecordMetric("payments.processed", amount.toDouble, Map("status" -> "failed"))
                replyTo ! StatusReply.error(s"Payment failed for order $orderId")
                Behaviors.same
              }
              
            case Some(_) =>
              replyTo ! StatusReply.error(s"Order $orderId is not in pending status")
              Behaviors.same
              
            case None =>
              replyTo ! StatusReply.error(s"Order $orderId not found")
              Behaviors.same
          }
          
        case ShipOrder(orderId, address, replyTo) =>
          orders.get(orderId) match {
            case Some(order) if order.status == Paid =>
              val updatedOrder = order.copy(status = Shipped)
              
              notificationActor ! SendEmail(
                to = s"customer-${order.customerId}@example.com",
                subject = s"Order Shipped - $orderId",
                body = s"Your order has been shipped to: $address",
                replyTo = context.system.ignoreRef
              )
              
              metricsActor ! RecordMetric("orders.shipped", 1.0, Map("destination" -> address))
              replyTo ! StatusReply.success(OrderShipped(orderId, address, Instant.now()))
              orderProcessing(orders + (orderId -> updatedOrder), notificationActor, metricsActor)
              
            case Some(_) =>
              replyTo ! StatusReply.error(s"Order $orderId is not paid")
              Behaviors.same
              
            case None =>
              replyTo ! StatusReply.error(s"Order $orderId not found")
              Behaviors.same
          }
          
        case GetOrderStatus(orderId, replyTo) =>
          orders.get(orderId) match {
            case Some(order) =>
              replyTo ! StatusReply.success(order)
            case None =>
              replyTo ! StatusReply.error(s"Order $orderId not found")
          }
          Behaviors.same
      }
    }
  }
}

object NotificationActor {
  import Protocol._
  
  def apply(): Behavior[NotificationCommand] = {
    Behaviors.setup { context =>
      Behaviors.withTimers { timers =>
        notificationBehavior(NotificationState.initial, timers)
      }
    }
  }
  
  private def notificationBehavior(
    state: NotificationState,
    timers: TimerScheduler[NotificationCommand]
  ): Behavior[NotificationCommand] = {
    Behaviors.receive { (context, message) =>
      message match {
        case sendEmail @ SendEmail(to, subject, body, replyTo) =>
          if (state.canSendEmail) {
            val messageId = UUID.randomUUID().toString
            val success = Random.nextFloat() > 0.1 
            
            if (success) {
              context.log.info(s"Email sent to $to: $subject")
              replyTo ! StatusReply.success(EmailSent(messageId, Instant.now()))
              notificationBehavior(state.incrementEmailCount, timers)
            } else {
              context.log.warn(s"Failed to send email to $to")
              replyTo ! StatusReply.error("Email delivery failed")
              Behaviors.same
            }
          } else {
            context.log.warn(s"Rate limit exceeded for emails")
            replyTo ! StatusReply.error("Rate limit exceeded")
            Behaviors.same
          }
          
        case sendSMS @ SendSMS(to, message, replyTo) =>
          if (state.canSendSMS) {
            val messageId = UUID.randomUUID().toString
            val success = Random.nextFloat() > 0.05 
            
            if (success) {
              context.log.info(s"SMS sent to $to: $message")
              replyTo ! StatusReply.success(SMSSent(messageId, Instant.now()))
              notificationBehavior(state.incrementSMSCount, timers)
            } else {
              context.log.warn(s"Failed to send SMS to $to")
              replyTo ! StatusReply.error("SMS delivery failed")
              Behaviors.same
            }
          } else {
            context.log.warn(s"Rate limit exceeded for SMS")
            replyTo ! StatusReply.error("Rate limit exceeded")
            Behaviors.same
          }
      }
    }
  }
  
  case class NotificationState(
    emailsSentInLastMinute: Int,
    smssSentInLastMinute: Int,
    maxEmailsPerMinute: Int = 100,
    maxSMSPerMinute: Int = 50
  ) {
    def canSendEmail: Boolean = emailsSentInLastMinute < maxEmailsPerMinute
    def canSendSMS: Boolean = smssSentInLastMinute < maxSMSPerMinute
    
    def incrementEmailCount: NotificationState = copy(emailsSentInLastMinute = emailsSentInLastMinute + 1)
    def incrementSMSCount: NotificationState = copy(smssSentInLastMinute = smssSentInLastMinute + 1)
  }
  
  object NotificationState {
    def initial: NotificationState = NotificationState(0, 0)
  }
}

object MetricsActor {
  import Protocol._
  
  def apply(): Behavior[MetricsCommand] = {
    Behaviors.setup { context =>
      metricsCollection(MetricsData.initial)
    }
  }
  
  private def metricsCollection(data: MetricsData): Behavior[MetricsCommand] = {
    Behaviors.receive { (context, message) =>
      message match {
        case RecordMetric(name, value, tags) =>
          val updatedData = data.recordMetric(name, value, tags)
          context.log.debug(s"Recorded metric: $name = $value with tags: $tags")
          metricsCollection(updatedData)
          
        case GetMetrics(replyTo) =>
          val snapshot = MetricsSnapshot(data.getSnapshot, Instant.now())
          replyTo ! snapshot
          Behaviors.same
      }
    }
  }
  
  case class MetricsData(metrics: Map[String, List[Double]]) {
    def recordMetric(name: String, value: Double, tags: Map[String, String]): MetricsData = {
      val taggedName = if (tags.nonEmpty) s"$name[${tags.map { case (k, v) => s"$k:$v" }.mkString(",")}]" else name
      val currentValues = metrics.getOrElse(taggedName, List.empty)
      val updatedValues = (value :: currentValues).take(1000) 
      copy(metrics = metrics + (taggedName -> updatedValues))
    }
    
    def getSnapshot: Map[String, MetricData] = {
      metrics.map { case (name, values) =>
        val average = if (values.nonEmpty) values.sum / values.length else 0.0
        name -> MetricData(values, average, values.length)
      }
    }
  }
  
  object MetricsData {
    def initial: MetricsData = MetricsData(Map.empty)
  }
}

object SupervisorActor {
  import Protocol._
  
  sealed trait SupervisorCommand
  case class StartChild(name: String, behavior: Behavior[_]) extends SupervisorCommand
  case class StopChild(name: String) extends SupervisorCommand
  case class RestartChild(name: String) extends SupervisorCommand
  case class GetChildren(replyTo: ActorRef[Set[String]]) extends SupervisorCommand
  
  def apply(): Behavior[SupervisorCommand] = {
    Behaviors.setup { context =>
      supervision(Map.empty)
    }
  }
  
  private def supervision(children: Map[String, ActorRef[_]]): Behavior[SupervisorCommand] = {
    Behaviors.receive { (context, message) =>
      message match {
        case StartChild(name, behavior) =>
          if (!children.contains(name)) {
            val childRef = context.spawn(
              Behaviors.supervise(behavior).onFailure[Exception](
                SupervisorStrategy.restart.withLimit(maxNrOfRetries = 3, withinTimeRange = 1.minute)
              ),
              name
            )
            context.log.info(s"Started child actor: $name")
            supervision(children + (name -> childRef))
          } else {
            context.log.warn(s"Child actor $name already exists")
            Behaviors.same
          }
          
        case StopChild(name) =>
          children.get(name) match {
            case Some(childRef) =>
              context.stop(childRef)
              context.log.info(s"Stopped child actor: $name")
              supervision(children - name)
            case None =>
              context.log.warn(s"Child actor $name not found")
              Behaviors.same
          }
          
        case RestartChild(name) =>
          children.get(name) match {
            case Some(childRef) =>
              context.stop(childRef)
              context.log.info(s"Restarting child actor: $name")
              
              Behaviors.same
            case None =>
              context.log.warn(s"Child actor $name not found")
              Behaviors.same
          }
          
        case GetChildren(replyTo) =>
          replyTo ! children.keySet
          Behaviors.same
      }
    }
  }
}

object ShardedUserActor {
  import Protocol._
  
  val EntityKey: EntityTypeKey[UserCommand] = EntityTypeKey[UserCommand]("User")
  
  def apply(entityId: String): Behavior[UserCommand] = {
    Behaviors.setup { context =>
      context.log.info(s"Starting sharded user actor for entity: $entityId")
      UserActor(entityId)
    }
  }
  
  def initSharding(system: ActorSystem[_]): ActorRef[ShardingEnvelope[UserCommand]] = {
    ClusterSharding(system).init(Entity(EntityKey) { entityContext =>
      ShardedUserActor(entityContext.entityId)
    }.withStopMessage(UserCommand))
  }
}

object StreamProcessorActor {
  
  sealed trait StreamCommand
  case class ProcessDataStream(source: Source[String, _], replyTo: ActorRef[StreamResult]) extends StreamCommand
  case class GetProcessingStats(replyTo: ActorRef[ProcessingStats]) extends StreamCommand
  
  case class StreamResult(processedCount: Int, errors: List[String])
  case class ProcessingStats(totalProcessed: Long, totalErrors: Long, averageProcessingTime: Double)
  
  def apply(): Behavior[StreamCommand] = {
    Behaviors.setup { context =>
      implicit val system = context.system
      
      streamProcessing(ProcessingStats(0, 0, 0.0))
    }
  }
  
  private def streamProcessing(stats: ProcessingStats): Behavior[StreamCommand] = {
    Behaviors.receive { (context, message) =>
      implicit val system = context.system
      
      message match {
        case ProcessDataStream(source, replyTo) =>
          val startTime = System.currentTimeMillis()
          
          val processedFuture = source
            .map { data =>
              
              if (Random.nextFloat() > 0.1) { 
                Right(data.toUpperCase)
              } else {
                Left(s"Processing failed for: $data")
              }
            }
            .runFold((0, List.empty[String])) { case ((count, errors), result) =>
              result match {
                case Right(_) => (count + 1, errors)
                case Left(error) => (count, error :: errors)
              }
            }
          
          processedFuture.onComplete {
            case Success((processedCount, errors)) =>
              val processingTime = System.currentTimeMillis() - startTime
              replyTo ! StreamResult(processedCount, errors)
              
            case Failure(exception) =>
              replyTo ! StreamResult(0, List(s"Stream processing failed: ${exception.getMessage}"))
          }(system.executionContext)
          
          val newStats = stats.copy(
            totalProcessed = stats.totalProcessed + 1,
            averageProcessingTime = (stats.averageProcessingTime + (System.currentTimeMillis() - startTime)) / 2
          )
          
          streamProcessing(newStats)
          
        case GetProcessingStats(replyTo) =>
          replyTo ! stats
          Behaviors.same
      }
    }
  }
}

object AkkaActorSystemExample extends App {
  import Protocol._
  
  val system: ActorSystem[Nothing] = ActorSystem(
    Behaviors.setup[Nothing] { context =>
      
      val userProcessor = context.spawn(UserActor("user-123"), "user-processor")
      val orderProcessor = context.spawn(OrderProcessorActor(), "order-processor")
      val supervisor = context.spawn(SupervisorActor(), "supervisor")
      val streamProcessor = context.spawn(StreamProcessorActor(), "stream-processor")
      
      val shardRegion = ShardedUserActor.initSharding(context.system)
      
      implicit val timeout: Timeout = 5.seconds
      implicit val scheduler = context.system.scheduler
      implicit val ec = context.system.executionContext
      
      userProcessor ! CreateUser("John Doe", "john@example.com", context.system.ignoreRef)
      
      val orderItems = List(
        OrderItem("product-1", "Laptop", BigDecimal(999.99), 1),
        OrderItem("product-2", "Mouse", BigDecimal(29.99), 2)
      )
      
      orderProcessor ! CreateOrder("customer-123", orderItems, context.system.ignoreRef)
      
      val dataSource = Source(List("hello", "world", "akka", "actors"))
      streamProcessor ! StreamProcessorActor.ProcessDataStream(dataSource, context.system.ignoreRef)
      
      context.system.scheduler.scheduleWithFixedDelay(
        initialDelay = 10.seconds,
        delay = 30.seconds
      ) { () =>
        context.log.info("Periodic maintenance task executed")
      }
      
      context.log.info("Akka Actor System started successfully")
      context.log.info("Example actors are running and processing messages")
      context.log.info("System demonstrates:")
      context.log.info("  - Persistent actors with event sourcing")
      context.log.info("  - Supervision strategies and fault tolerance")
      context.log.info("  - Cluster sharding for distributed actors")
      context.log.info("  - Stream processing integration")
      context.log.info("  - Rate limiting and metrics collection")
      
      Behaviors.empty
    },
    "AkkaActorSystem"
  )
  
  sys.addShutdownHook {
    system.terminate()
  }
} 