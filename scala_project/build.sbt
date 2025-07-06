name := "scala-security-scan"
version := "0.1.0"
scalaVersion := "3.3.1"

// Dependencies for the Scala files
libraryDependencies ++= Seq(
  // Akka dependencies
  "com.typesafe.akka" %% "akka-actor" % "2.8.5",
  "com.typesafe.akka" %% "akka-stream" % "2.8.5",
  "com.typesafe.akka" %% "akka-http" % "10.5.3",
  
  // Cats and ZIO
  "org.typelevel" %% "cats-core" % "2.9.0",
  "org.typelevel" %% "cats-effect" % "3.5.2",
  "dev.zio" %% "zio" % "2.0.15",
  "dev.zio" %% "zio-streams" % "2.0.15",
  
  // Other utilities
  "org.scalatest" %% "scalatest" % "3.2.17" % Test,
  "com.typesafe" % "config" % "1.4.2",
  "org.slf4j" % "slf4j-api" % "2.0.9"
)

// Compiler options
scalacOptions ++= Seq(
  "-deprecation",
  "-feature",
  "-unchecked"
)

// Java options for SBT
javaOptions ++= Seq(
  "-Xmx2G",
  "-Xms1G"
) 