// AI-Generated Code Header
// **Intent:** Design patterns showcase with Factory, Observer, Strategy, Builder, and other patterns
// **Optimization:** Efficient pattern implementations with clean interfaces and extensibility
// **Safety:** Type safety, null checks, and proper encapsulation

package com.patterns.showcase;

import java.time.LocalDateTime;
import java.util.*;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.function.Function;

// AI-SUGGESTION: Observer Pattern Implementation
interface Observer<T> {
    void update(T data);
}

interface Subject<T> {
    void addObserver(Observer<T> observer);
    void removeObserver(Observer<T> observer);
    void notifyObservers(T data);
}

class EventPublisher<T> implements Subject<T> {
    private final List<Observer<T>> observers = new CopyOnWriteArrayList<>();
    private final String name;

    public EventPublisher(String name) {
        this.name = name;
    }

    @Override
    public void addObserver(Observer<T> observer) {
        observers.add(observer);
        System.out.println("Observer added to " + name + ". Total observers: " + observers.size());
    }

    @Override
    public void removeObserver(Observer<T> observer) {
        observers.remove(observer);
        System.out.println("Observer removed from " + name + ". Total observers: " + observers.size());
    }

    @Override
    public void notifyObservers(T data) {
        System.out.println("Notifying " + observers.size() + " observers from " + name);
        observers.forEach(observer -> observer.update(data));
    }

    public void publishEvent(T event) {
        System.out.println("Publishing event: " + event);
        notifyObservers(event);
    }
}

// AI-SUGGESTION: Strategy Pattern Implementation
interface PaymentStrategy {
    boolean processPayment(double amount);
    String getPaymentMethod();
}

class CreditCardPayment implements PaymentStrategy {
    private final String cardNumber;
    private final String holderName;

    public CreditCardPayment(String cardNumber, String holderName) {
        this.cardNumber = maskCardNumber(cardNumber);
        this.holderName = holderName;
    }

    @Override
    public boolean processPayment(double amount) {
        System.out.printf("Processing credit card payment of $%.2f for %s using card %s%n", 
            amount, holderName, cardNumber);
        return amount > 0 && amount <= 10000; // Simulate validation
    }

    @Override
    public String getPaymentMethod() {
        return "Credit Card";
    }

    private String maskCardNumber(String cardNumber) {
        if (cardNumber.length() < 4) return "****";
        return "**** **** **** " + cardNumber.substring(cardNumber.length() - 4);
    }
}

class PayPalPayment implements PaymentStrategy {
    private final String email;

    public PayPalPayment(String email) {
        this.email = email;
    }

    @Override
    public boolean processPayment(double amount) {
        System.out.printf("Processing PayPal payment of $%.2f for %s%n", amount, email);
        return amount > 0 && amount <= 5000; // Different limits
    }

    @Override
    public String getPaymentMethod() {
        return "PayPal";
    }
}

class BankTransferPayment implements PaymentStrategy {
    private final String accountNumber;

    public BankTransferPayment(String accountNumber) {
        this.accountNumber = accountNumber;
    }

    @Override
    public boolean processPayment(double amount) {
        System.out.printf("Processing bank transfer of $%.2f to account %s%n", amount, accountNumber);
        return amount > 0; // No upper limit
    }

    @Override
    public String getPaymentMethod() {
        return "Bank Transfer";
    }
}

// AI-SUGGESTION: Factory Pattern Implementation
abstract class Document {
    protected String title;
    protected String content;
    protected LocalDateTime createdAt;

    public Document(String title) {
        this.title = title;
        this.content = "";
        this.createdAt = LocalDateTime.now();
    }

    public abstract void render();
    public abstract String getFileExtension();

    // AI-SUGGESTION: Getters and common methods
    public String getTitle() { return title; }
    public String getContent() { return content; }
    public void setContent(String content) { this.content = content; }
    public LocalDateTime getCreatedAt() { return createdAt; }
}

class PDFDocument extends Document {
    public PDFDocument(String title) {
        super(title);
    }

    @Override
    public void render() {
        System.out.println("Rendering PDF document: " + title);
        System.out.println("Adding PDF-specific formatting and layout...");
    }

    @Override
    public String getFileExtension() {
        return ".pdf";
    }
}

class WordDocument extends Document {
    public WordDocument(String title) {
        super(title);
    }

    @Override
    public void render() {
        System.out.println("Rendering Word document: " + title);
        System.out.println("Applying Word-specific styles and formatting...");
    }

    @Override
    public String getFileExtension() {
        return ".docx";
    }
}

class HTMLDocument extends Document {
    public HTMLDocument(String title) {
        super(title);
    }

    @Override
    public void render() {
        System.out.println("Rendering HTML document: " + title);
        System.out.println("Generating HTML markup and CSS styles...");
    }

    @Override
    public String getFileExtension() {
        return ".html";
    }
}

// AI-SUGGESTION: Document Factory
class DocumentFactory {
    public enum DocumentType {
        PDF, WORD, HTML
    }

    public static Document createDocument(DocumentType type, String title) {
        if (title == null || title.trim().isEmpty()) {
            throw new IllegalArgumentException("Document title cannot be null or empty");
        }

        switch (type) {
            case PDF:
                return new PDFDocument(title);
            case WORD:
                return new WordDocument(title);
            case HTML:
                return new HTMLDocument(title);
            default:
                throw new IllegalArgumentException("Unknown document type: " + type);
        }
    }

    public static List<DocumentType> getSupportedTypes() {
        return Arrays.asList(DocumentType.values());
    }
}

// AI-SUGGESTION: Builder Pattern Implementation
class DatabaseConnection {
    private final String host;
    private final int port;
    private final String database;
    private final String username;
    private final String password;
    private final boolean useSSL;
    private final int connectionTimeout;
    private final int maxPoolSize;
    private final Map<String, String> properties;

    private DatabaseConnection(Builder builder) {
        this.host = builder.host;
        this.port = builder.port;
        this.database = builder.database;
        this.username = builder.username;
        this.password = builder.password;
        this.useSSL = builder.useSSL;
        this.connectionTimeout = builder.connectionTimeout;
        this.maxPoolSize = builder.maxPoolSize;
        this.properties = new HashMap<>(builder.properties);
    }

    public void connect() {
        System.out.println("Connecting to database:");
        System.out.println("  Host: " + host + ":" + port);
        System.out.println("  Database: " + database);
        System.out.println("  Username: " + username);
        System.out.println("  SSL: " + useSSL);
        System.out.println("  Timeout: " + connectionTimeout + "ms");
        System.out.println("  Max Pool Size: " + maxPoolSize);
        if (!properties.isEmpty()) {
            System.out.println("  Additional Properties: " + properties);
        }
        System.out.println("Connection established successfully!");
    }

    public static class Builder {
        private String host = "localhost";
        private int port = 5432;
        private String database;
        private String username;
        private String password;
        private boolean useSSL = false;
        private int connectionTimeout = 30000;
        private int maxPoolSize = 10;
        private Map<String, String> properties = new HashMap<>();

        public Builder host(String host) {
            this.host = host;
            return this;
        }

        public Builder port(int port) {
            this.port = port;
            return this;
        }

        public Builder database(String database) {
            this.database = database;
            return this;
        }

        public Builder username(String username) {
            this.username = username;
            return this;
        }

        public Builder password(String password) {
            this.password = password;
            return this;
        }

        public Builder useSSL(boolean useSSL) {
            this.useSSL = useSSL;
            return this;
        }

        public Builder connectionTimeout(int timeout) {
            this.connectionTimeout = timeout;
            return this;
        }

        public Builder maxPoolSize(int maxPoolSize) {
            this.maxPoolSize = maxPoolSize;
            return this;
        }

        public Builder addProperty(String key, String value) {
            this.properties.put(key, value);
            return this;
        }

        public DatabaseConnection build() {
            validateRequired();
            return new DatabaseConnection(this);
        }

        private void validateRequired() {
            if (database == null || database.trim().isEmpty()) {
                throw new IllegalStateException("Database name is required");
            }
            if (username == null || username.trim().isEmpty()) {
                throw new IllegalStateException("Username is required");
            }
            if (password == null) {
                throw new IllegalStateException("Password is required");
            }
        }
    }
}

// AI-SUGGESTION: Singleton Pattern Implementation
class ConfigurationManager {
    private static volatile ConfigurationManager instance;
    private final Map<String, String> properties;
    private final LocalDateTime createdAt;

    private ConfigurationManager() {
        this.properties = new HashMap<>();
        this.createdAt = LocalDateTime.now();
        loadDefaultConfiguration();
    }

    public static ConfigurationManager getInstance() {
        if (instance == null) {
            synchronized (ConfigurationManager.class) {
                if (instance == null) {
                    instance = new ConfigurationManager();
                }
            }
        }
        return instance;
    }

    private void loadDefaultConfiguration() {
        properties.put("app.name", "Design Patterns Showcase");
        properties.put("app.version", "1.0.0");
        properties.put("app.environment", "development");
        properties.put("logging.level", "INFO");
        properties.put("database.pool.size", "10");
    }

    public String getProperty(String key) {
        return properties.get(key);
    }

    public String getProperty(String key, String defaultValue) {
        return properties.getOrDefault(key, defaultValue);
    }

    public void setProperty(String key, String value) {
        properties.put(key, value);
        System.out.println("Configuration updated: " + key + " = " + value);
    }

    public Map<String, String> getAllProperties() {
        return new HashMap<>(properties);
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    @Override
    public String toString() {
        return String.format("ConfigurationManager{properties=%d, created=%s}", 
            properties.size(), createdAt);
    }
}

// AI-SUGGESTION: Command Pattern Implementation
interface Command {
    void execute();
    void undo();
    String getDescription();
}

class TextEditor {
    private StringBuilder content;
    private final Stack<Command> commandHistory;

    public TextEditor() {
        this.content = new StringBuilder();
        this.commandHistory = new Stack<>();
    }

    public void executeCommand(Command command) {
        command.execute();
        commandHistory.push(command);
        System.out.println("Executed: " + command.getDescription());
    }

    public void undo() {
        if (!commandHistory.isEmpty()) {
            Command lastCommand = commandHistory.pop();
            lastCommand.undo();
            System.out.println("Undone: " + lastCommand.getDescription());
        } else {
            System.out.println("Nothing to undo");
        }
    }

    public String getContent() {
        return content.toString();
    }

    public void setContent(StringBuilder content) {
        this.content = content;
    }

    public StringBuilder getContentBuilder() {
        return content;
    }
}

class InsertTextCommand implements Command {
    private final TextEditor editor;
    private final String text;
    private final int position;

    public InsertTextCommand(TextEditor editor, String text, int position) {
        this.editor = editor;
        this.text = text;
        this.position = position;
    }

    @Override
    public void execute() {
        editor.getContentBuilder().insert(position, text);
    }

    @Override
    public void undo() {
        editor.getContentBuilder().delete(position, position + text.length());
    }

    @Override
    public String getDescription() {
        return "Insert '" + text + "' at position " + position;
    }
}

class DeleteTextCommand implements Command {
    private final TextEditor editor;
    private final int startPosition;
    private final int length;
    private String deletedText;

    public DeleteTextCommand(TextEditor editor, int startPosition, int length) {
        this.editor = editor;
        this.startPosition = startPosition;
        this.length = length;
    }

    @Override
    public void execute() {
        StringBuilder content = editor.getContentBuilder();
        deletedText = content.substring(startPosition, startPosition + length);
        content.delete(startPosition, startPosition + length);
    }

    @Override
    public void undo() {
        editor.getContentBuilder().insert(startPosition, deletedText);
    }

    @Override
    public String getDescription() {
        return "Delete " + length + " characters at position " + startPosition;
    }
}

// AI-SUGGESTION: Adapter Pattern Implementation
interface MediaPlayer {
    void play(String audioType, String fileName);
}

interface AdvancedMediaPlayer {
    void playVlc(String fileName);
    void playMp4(String fileName);
}

class VlcPlayer implements AdvancedMediaPlayer {
    @Override
    public void playVlc(String fileName) {
        System.out.println("Playing vlc file. Name: " + fileName);
    }

    @Override
    public void playMp4(String fileName) {
        // Do nothing - VLC can't play mp4 in this example
    }
}

class Mp4Player implements AdvancedMediaPlayer {
    @Override
    public void playVlc(String fileName) {
        // Do nothing - Mp4 player can't play vlc
    }

    @Override
    public void playMp4(String fileName) {
        System.out.println("Playing mp4 file. Name: " + fileName);
    }
}

class MediaAdapter implements MediaPlayer {
    private AdvancedMediaPlayer advancedMusicPlayer;

    public MediaAdapter(String audioType) {
        if ("vlc".equalsIgnoreCase(audioType)) {
            advancedMusicPlayer = new VlcPlayer();
        } else if ("mp4".equalsIgnoreCase(audioType)) {
            advancedMusicPlayer = new Mp4Player();
        }
    }

    @Override
    public void play(String audioType, String fileName) {
        if ("vlc".equalsIgnoreCase(audioType)) {
            advancedMusicPlayer.playVlc(fileName);
        } else if ("mp4".equalsIgnoreCase(audioType)) {
            advancedMusicPlayer.playMp4(fileName);
        }
    }
}

class AudioPlayer implements MediaPlayer {
    private MediaAdapter mediaAdapter;

    @Override
    public void play(String audioType, String fileName) {
        if ("mp3".equalsIgnoreCase(audioType)) {
            System.out.println("Playing mp3 file. Name: " + fileName);
        } else if ("vlc".equalsIgnoreCase(audioType) || "mp4".equalsIgnoreCase(audioType)) {
            mediaAdapter = new MediaAdapter(audioType);
            mediaAdapter.play(audioType, fileName);
        } else {
            System.out.println("Invalid media. " + audioType + " format not supported");
        }
    }
}

// AI-SUGGESTION: Template Method Pattern Implementation
abstract class DataProcessor {
    // Template method defining the algorithm structure
    public final void processData() {
        loadData();
        validateData();
        transformData();
        saveData();
        cleanup();
    }

    protected abstract void loadData();
    protected abstract void validateData();
    protected abstract void transformData();
    protected abstract void saveData();

    // Hook method - can be overridden but not required
    protected void cleanup() {
        System.out.println("Default cleanup completed");
    }
}

class CSVDataProcessor extends DataProcessor {
    @Override
    protected void loadData() {
        System.out.println("Loading data from CSV file...");
    }

    @Override
    protected void validateData() {
        System.out.println("Validating CSV data format and structure...");
    }

    @Override
    protected void transformData() {
        System.out.println("Transforming CSV data to internal format...");
    }

    @Override
    protected void saveData() {
        System.out.println("Saving processed CSV data to database...");
    }

    @Override
    protected void cleanup() {
        System.out.println("Closing CSV file handles and clearing buffers");
    }
}

class JSONDataProcessor extends DataProcessor {
    @Override
    protected void loadData() {
        System.out.println("Loading data from JSON file...");
    }

    @Override
    protected void validateData() {
        System.out.println("Validating JSON schema and syntax...");
    }

    @Override
    protected void transformData() {
        System.out.println("Parsing JSON and transforming to objects...");
    }

    @Override
    protected void saveData() {
        System.out.println("Saving processed JSON data to NoSQL database...");
    }
}

// AI-SUGGESTION: Main demonstration class
public class DesignPatternsShowcase {
    
    public static void main(String[] args) {
        System.out.println("Design Patterns Showcase");
        System.out.println("========================");

        // AI-SUGGESTION: Observer Pattern Demo
        demonstrateObserverPattern();

        // AI-SUGGESTION: Strategy Pattern Demo
        demonstrateStrategyPattern();

        // AI-SUGGESTION: Factory Pattern Demo
        demonstrateFactoryPattern();

        // AI-SUGGESTION: Builder Pattern Demo
        demonstrateBuilderPattern();

        // AI-SUGGESTION: Singleton Pattern Demo
        demonstrateSingletonPattern();

        // AI-SUGGESTION: Command Pattern Demo
        demonstrateCommandPattern();

        // AI-SUGGESTION: Adapter Pattern Demo
        demonstrateAdapterPattern();

        // AI-SUGGESTION: Template Method Pattern Demo
        demonstrateTemplateMethodPattern();

        System.out.println("\n=== Design Patterns Showcase Complete ===");
    }

    private static void demonstrateObserverPattern() {
        System.out.println("\n--- Observer Pattern Demo ---");
        
        EventPublisher<String> newsPublisher = new EventPublisher<>("News Channel");
        
        Observer<String> emailSubscriber = data -> 
            System.out.println("Email Notification: " + data);
        Observer<String> smsSubscriber = data -> 
            System.out.println("SMS Notification: " + data);
        Observer<String> pushSubscriber = data -> 
            System.out.println("Push Notification: " + data);
        
        newsPublisher.addObserver(emailSubscriber);
        newsPublisher.addObserver(smsSubscriber);
        newsPublisher.addObserver(pushSubscriber);
        
        newsPublisher.publishEvent("Breaking News: Design Patterns are Awesome!");
        
        newsPublisher.removeObserver(smsSubscriber);
        newsPublisher.publishEvent("Update: More patterns to explore!");
    }

    private static void demonstrateStrategyPattern() {
        System.out.println("\n--- Strategy Pattern Demo ---");
        
        PaymentStrategy creditCard = new CreditCardPayment("1234567812345678", "John Doe");
        PaymentStrategy paypal = new PayPalPayment("john@example.com");
        PaymentStrategy bankTransfer = new BankTransferPayment("ACC-123456789");
        
        double amount = 1500.00;
        
        System.out.println("Processing payment of $" + amount + " using different strategies:");
        
        List<PaymentStrategy> strategies = Arrays.asList(creditCard, paypal, bankTransfer);
        strategies.forEach(strategy -> {
            System.out.println("\n" + strategy.getPaymentMethod() + ":");
            boolean success = strategy.processPayment(amount);
            System.out.println("Payment " + (success ? "successful" : "failed"));
        });
    }

    private static void demonstrateFactoryPattern() {
        System.out.println("\n--- Factory Pattern Demo ---");
        
        System.out.println("Creating different types of documents:");
        
        for (DocumentFactory.DocumentType type : DocumentFactory.getSupportedTypes()) {
            Document doc = DocumentFactory.createDocument(type, "Sample " + type + " Document");
            doc.setContent("This is sample content for " + type + " document");
            doc.render();
            System.out.println("File extension: " + doc.getFileExtension());
            System.out.println();
        }
    }

    private static void demonstrateBuilderPattern() {
        System.out.println("\n--- Builder Pattern Demo ---");
        
        DatabaseConnection connection = new DatabaseConnection.Builder()
            .host("prod-db-server.company.com")
            .port(5432)
            .database("production_db")
            .username("app_user")
            .password("secure_password")
            .useSSL(true)
            .connectionTimeout(45000)
            .maxPoolSize(20)
            .addProperty("charset", "UTF-8")
            .addProperty("timezone", "UTC")
            .build();
        
        connection.connect();
    }

    private static void demonstrateSingletonPattern() {
        System.out.println("\n--- Singleton Pattern Demo ---");
        
        ConfigurationManager config1 = ConfigurationManager.getInstance();
        ConfigurationManager config2 = ConfigurationManager.getInstance();
        
        System.out.println("Same instance? " + (config1 == config2));
        System.out.println("Configuration: " + config1);
        
        config1.setProperty("debug.mode", "true");
        System.out.println("Debug mode from config2: " + config2.getProperty("debug.mode"));
        
        System.out.println("All properties:");
        config1.getAllProperties().forEach((key, value) -> 
            System.out.println("  " + key + " = " + value));
    }

    private static void demonstrateCommandPattern() {
        System.out.println("\n--- Command Pattern Demo ---");
        
        TextEditor editor = new TextEditor();
        
        editor.executeCommand(new InsertTextCommand(editor, "Hello ", 0));
        editor.executeCommand(new InsertTextCommand(editor, "World!", 6));
        System.out.println("Content: '" + editor.getContent() + "'");
        
        editor.executeCommand(new DeleteTextCommand(editor, 6, 6));
        System.out.println("Content: '" + editor.getContent() + "'");
        
        editor.executeCommand(new InsertTextCommand(editor, "Java!", 6));
        System.out.println("Content: '" + editor.getContent() + "'");
        
        System.out.println("\nUndoing operations:");
        editor.undo();
        System.out.println("Content: '" + editor.getContent() + "'");
        editor.undo();
        System.out.println("Content: '" + editor.getContent() + "'");
        editor.undo();
        System.out.println("Content: '" + editor.getContent() + "'");
    }

    private static void demonstrateAdapterPattern() {
        System.out.println("\n--- Adapter Pattern Demo ---");
        
        AudioPlayer audioPlayer = new AudioPlayer();
        
        audioPlayer.play("mp3", "song.mp3");
        audioPlayer.play("mp4", "movie.mp4");
        audioPlayer.play("vlc", "documentary.vlc");
        audioPlayer.play("avi", "unsupported.avi");
    }

    private static void demonstrateTemplateMethodPattern() {
        System.out.println("\n--- Template Method Pattern Demo ---");
        
        System.out.println("Processing CSV data:");
        DataProcessor csvProcessor = new CSVDataProcessor();
        csvProcessor.processData();
        
        System.out.println("\nProcessing JSON data:");
        DataProcessor jsonProcessor = new JSONDataProcessor();
        jsonProcessor.processData();
    }
} 