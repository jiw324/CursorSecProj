package com.example;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configuration.WebSecurityConfigurerAdapter;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Service;
import org.springframework.stereotype.Repository;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.Query;
import org.springframework.transaction.annotation.Transactional;

import javax.persistence.*;
import java.util.*;
import java.time.LocalDateTime;
import java.time.Duration;

@SpringBootApplication
@EnableScheduling
public class Main {
    public static void main(String[] args) {
        SpringApplication.run(Main.class, args);
    }
}

@Configuration
@EnableWebSecurity
class SecurityConfig extends WebSecurityConfigurerAdapter {

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Override
    protected void configure(HttpSecurity http) throws Exception {
        http
            .csrf().disable()
            .authorizeRequests()
                .antMatchers("/api/auth/**").permitAll()
                .antMatchers("/api/admin/**").hasRole("ADMIN")
                .antMatchers("/api/**").authenticated()
            .and()
            .httpBasic();
    }
}

@Entity
@Table(name = "app_users")
class AppUser {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(unique = true, nullable = false)
    private String username;

    @Column(nullable = false)
    private String password;

    @Column(unique = true, nullable = false)
    private String email;

    @ElementCollection(fetch = FetchType.EAGER)
    private Set<String> roles = new HashSet<>();

    private boolean enabled = true;
    private boolean accountNonExpired = true;
    private boolean credentialsNonExpired = true;
    private boolean accountNonLocked = true;

    private LocalDateTime createdAt;
    private LocalDateTime lastLogin;
    private String lastLoginIp;

    public AppUser() {
        this.createdAt = LocalDateTime.now();
    }

    public AppUser(String username, String password, String email) {
        this();
        this.username = username;
        this.password = password;
        this.email = email;
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getUsername() { return username; }
    public void setUsername(String username) { this.username = username; }

    public String getPassword() { return password; }
    public void setPassword(String password) { this.password = password; }

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }

    public Set<String> getRoles() { return roles; }
    public void setRoles(Set<String> roles) { this.roles = roles; }

    public boolean isEnabled() { return enabled; }
    public void setEnabled(boolean enabled) { this.enabled = enabled; }

    public boolean isAccountNonExpired() { return accountNonExpired; }
    public void setAccountNonExpired(boolean accountNonExpired) { 
        this.accountNonExpired = accountNonExpired; 
    }

    public boolean isCredentialsNonExpired() { return credentialsNonExpired; }
    public void setCredentialsNonExpired(boolean credentialsNonExpired) { 
        this.credentialsNonExpired = credentialsNonExpired; 
    }

    public boolean isAccountNonLocked() { return accountNonLocked; }
    public void setAccountNonLocked(boolean accountNonLocked) { 
        this.accountNonLocked = accountNonLocked; 
    }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }

    public LocalDateTime getLastLogin() { return lastLogin; }
    public void setLastLogin(LocalDateTime lastLogin) { this.lastLogin = lastLogin; }

    public String getLastLoginIp() { return lastLoginIp; }
    public void setLastLoginIp(String lastLoginIp) { this.lastLoginIp = lastLoginIp; }
}

@Repository
interface UserRepository extends JpaRepository<AppUser, Long> {
    Optional<AppUser> findByUsername(String username);
    Optional<AppUser> findByEmail(String email);
    boolean existsByUsername(String username);
    boolean existsByEmail(String email);
}

@Service
class UserService implements UserDetailsService {
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    public UserService(UserRepository userRepository, PasswordEncoder passwordEncoder) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
    }

    @Override
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        AppUser user = userRepository.findByUsername(username)
            .orElseThrow(() -> new UsernameNotFoundException("User not found: " + username));

        return User.builder()
            .username(user.getUsername())
            .password(user.getPassword())
            .authorities(user.getRoles().stream()
                .map(role -> new SimpleGrantedAuthority("ROLE_" + role))
                .toList())
            .accountExpired(!user.isAccountNonExpired())
            .accountLocked(!user.isAccountNonLocked())
            .credentialsExpired(!user.isCredentialsNonExpired())
            .disabled(!user.isEnabled())
            .build();
    }

    public AppUser createUser(String username, String password, String email) {
        if (userRepository.existsByUsername(username)) {
            throw new IllegalArgumentException("Username already exists");
        }
        if (userRepository.existsByEmail(email)) {
            throw new IllegalArgumentException("Email already exists");
        }

        AppUser user = new AppUser(username, passwordEncoder.encode(password), email);
        user.getRoles().add("USER");
        return userRepository.save(user);
    }

    public AppUser createAdmin(String username, String password, String email) {
        AppUser admin = createUser(username, password, email);
        admin.getRoles().add("ADMIN");
        return userRepository.save(admin);
    }

    public void updatePassword(Long userId, String oldPassword, String newPassword) {
        AppUser user = userRepository.findById(userId)
            .orElseThrow(() -> new IllegalArgumentException("User not found"));

        if (!passwordEncoder.matches(oldPassword, user.getPassword())) {
            throw new IllegalArgumentException("Invalid old password");
        }

        user.setPassword(passwordEncoder.encode(newPassword));
        user.setCredentialsNonExpired(true);
        userRepository.save(user);
    }

    public void lockUser(Long userId) {
        AppUser user = userRepository.findById(userId)
            .orElseThrow(() -> new IllegalArgumentException("User not found"));
        user.setAccountNonLocked(false);
        userRepository.save(user);
    }

    public void unlockUser(Long userId) {
        AppUser user = userRepository.findById(userId)
            .orElseThrow(() -> new IllegalArgumentException("User not found"));
        user.setAccountNonLocked(true);
        userRepository.save(user);
    }

    public void disableUser(Long userId) {
        AppUser user = userRepository.findById(userId)
            .orElseThrow(() -> new IllegalArgumentException("User not found"));
        user.setEnabled(false);
        userRepository.save(user);
    }

    public void enableUser(Long userId) {
        AppUser user = userRepository.findById(userId)
            .orElseThrow(() -> new IllegalArgumentException("User not found"));
        user.setEnabled(true);
        userRepository.save(user);
    }

    public void addRole(Long userId, String role) {
        AppUser user = userRepository.findById(userId)
            .orElseThrow(() -> new IllegalArgumentException("User not found"));
        user.getRoles().add(role.toUpperCase());
        userRepository.save(user);
    }

    public void removeRole(Long userId, String role) {
        AppUser user = userRepository.findById(userId)
            .orElseThrow(() -> new IllegalArgumentException("User not found"));
        user.getRoles().remove(role.toUpperCase());
        userRepository.save(user);
    }

    public void updateLoginInfo(String username, String ipAddress) {
        AppUser user = userRepository.findByUsername(username)
            .orElseThrow(() -> new IllegalArgumentException("User not found"));
        user.setLastLogin(LocalDateTime.now());
        user.setLastLoginIp(ipAddress);
        userRepository.save(user);
    }
}

@RestController
@RequestMapping("/api/auth")
class AuthController {
    private final UserService userService;

    public AuthController(UserService userService) {
        this.userService = userService;
    }

    @PostMapping("/register")
    public Map<String, String> register(@RequestBody Map<String, String> request) {
        AppUser user = userService.createUser(
            request.get("username"),
            request.get("password"),
            request.get("email")
        );

        return Map.of(
            "message", "User registered successfully",
            "username", user.getUsername()
        );
    }

    @PostMapping("/change-password")
    public Map<String, String> changePassword(@RequestBody Map<String, String> request) {
        userService.updatePassword(
            Long.parseLong(request.get("userId")),
            request.get("oldPassword"),
            request.get("newPassword")
        );

        return Map.of("message", "Password updated successfully");
    }
}

@RestController
@RequestMapping("/api/admin")
class AdminController {
    private final UserService userService;

    public AdminController(UserService userService) {
        this.userService = userService;
    }

    @PostMapping("/users/{userId}/lock")
    public Map<String, String> lockUser(@PathVariable Long userId) {
        userService.lockUser(userId);
        return Map.of("message", "User locked successfully");
    }

    @PostMapping("/users/{userId}/unlock")
    public Map<String, String> unlockUser(@PathVariable Long userId) {
        userService.unlockUser(userId);
        return Map.of("message", "User unlocked successfully");
    }

    @PostMapping("/users/{userId}/disable")
    public Map<String, String> disableUser(@PathVariable Long userId) {
        userService.disableUser(userId);
        return Map.of("message", "User disabled successfully");
    }

    @PostMapping("/users/{userId}/enable")
    public Map<String, String> enableUser(@PathVariable Long userId) {
        userService.enableUser(userId);
        return Map.of("message", "User enabled successfully");
    }

    @PostMapping("/users/{userId}/roles/add")
    public Map<String, String> addRole(@PathVariable Long userId, @RequestBody Map<String, String> request) {
        userService.addRole(userId, request.get("role"));
        return Map.of("message", "Role added successfully");
    }

    @PostMapping("/users/{userId}/roles/remove")
    public Map<String, String> removeRole(@PathVariable Long userId, @RequestBody Map<String, String> request) {
        userService.removeRole(userId, request.get("role"));
        return Map.of("message", "Role removed successfully");
    }
} 

@Entity
@Table(name = "user_preferences")
class UserPreferences {
    @Id
    private Long userId;

    @Column(nullable = false)
    private String theme = "light";

    @Column(nullable = false)
    private String language = "en";

    @Column(nullable = false)
    private boolean emailNotifications = true;

    @Column(nullable = false)
    private boolean twoFactorEnabled = false;

    @Column
    private String twoFactorSecret;

    public Long getUserId() { return userId; }
    public void setUserId(Long userId) { this.userId = userId; }

    public String getTheme() { return theme; }
    public void setTheme(String theme) { this.theme = theme; }

    public String getLanguage() { return language; }
    public void setLanguage(String language) { this.language = language; }

    public boolean isEmailNotifications() { return emailNotifications; }
    public void setEmailNotifications(boolean emailNotifications) { 
        this.emailNotifications = emailNotifications; 
    }

    public boolean isTwoFactorEnabled() { return twoFactorEnabled; }
    public void setTwoFactorEnabled(boolean twoFactorEnabled) { 
        this.twoFactorEnabled = twoFactorEnabled; 
    }

    public String getTwoFactorSecret() { return twoFactorSecret; }
    public void setTwoFactorSecret(String twoFactorSecret) { 
        this.twoFactorSecret = twoFactorSecret; 
    }
}

@Entity
@Table(name = "audit_logs")
class AuditLog {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String action;

    @Column(nullable = false)
    private String username;

    @Column(nullable = false)
    private LocalDateTime timestamp;

    @Column
    private String ipAddress;

    @Column
    private String details;

    @Column
    private String userAgent;

    public AuditLog() {
        this.timestamp = LocalDateTime.now();
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getAction() { return action; }
    public void setAction(String action) { this.action = action; }

    public String getUsername() { return username; }
    public void setUsername(String username) { this.username = username; }

    public LocalDateTime getTimestamp() { return timestamp; }
    public void setTimestamp(LocalDateTime timestamp) { this.timestamp = timestamp; }

    public String getIpAddress() { return ipAddress; }
    public void setIpAddress(String ipAddress) { this.ipAddress = ipAddress; }

    public String getDetails() { return details; }
    public void setDetails(String details) { this.details = details; }

    public String getUserAgent() { return userAgent; }
    public void setUserAgent(String userAgent) { this.userAgent = userAgent; }
}

@Entity
@Table(name = "login_attempts")
class LoginAttempt {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String username;

    @Column(nullable = false)
    private LocalDateTime timestamp;

    @Column(nullable = false)
    private boolean successful;

    @Column
    private String ipAddress;

    public LoginAttempt() {
        this.timestamp = LocalDateTime.now();
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getUsername() { return username; }
    public void setUsername(String username) { this.username = username; }

    public LocalDateTime getTimestamp() { return timestamp; }
    public void setTimestamp(LocalDateTime timestamp) { this.timestamp = timestamp; }

    public boolean isSuccessful() { return successful; }
    public void setSuccessful(boolean successful) { this.successful = successful; }

    public String getIpAddress() { return ipAddress; }
    public void setIpAddress(String ipAddress) { this.ipAddress = ipAddress; }
}

@Repository
interface UserPreferencesRepository extends JpaRepository<UserPreferences, Long> {
}

@Repository
interface AuditLogRepository extends JpaRepository<AuditLog, Long> {
    List<AuditLog> findByUsernameOrderByTimestampDesc(String username);
    Page<AuditLog> findByTimestampBetween(LocalDateTime start, LocalDateTime end, Pageable pageable);
}

@Repository
interface LoginAttemptRepository extends JpaRepository<LoginAttempt, Long> {
    List<LoginAttempt> findByUsernameAndTimestampAfterAndSuccessfulFalse(
        String username, LocalDateTime since);
    
    @Query("SELECT COUNT(l) FROM LoginAttempt l WHERE l.username = ?1 AND " +
           "l.timestamp > ?2 AND l.successful = false")
    int countFailedAttempts(String username, LocalDateTime since);
}

@Service
class AuditService {
    private final AuditLogRepository auditLogRepository;
    private final LoginAttemptRepository loginAttemptRepository;

    public AuditService(AuditLogRepository auditLogRepository, 
                       LoginAttemptRepository loginAttemptRepository) {
        this.auditLogRepository = auditLogRepository;
        this.loginAttemptRepository = loginAttemptRepository;
    }

    public void logAction(String username, String action, String ipAddress, 
                         String details, String userAgent) {
        AuditLog log = new AuditLog();
        log.setUsername(username);
        log.setAction(action);
        log.setIpAddress(ipAddress);
        log.setDetails(details);
        log.setUserAgent(userAgent);
        auditLogRepository.save(log);
    }

    public void logLoginAttempt(String username, boolean successful, String ipAddress) {
        LoginAttempt attempt = new LoginAttempt();
        attempt.setUsername(username);
        attempt.setSuccessful(successful);
        attempt.setIpAddress(ipAddress);
        loginAttemptRepository.save(attempt);
    }

    public boolean isAccountLocked(String username) {
        LocalDateTime threshold = LocalDateTime.now().minusMinutes(30);
        int failedAttempts = loginAttemptRepository.countFailedAttempts(username, threshold);
        return failedAttempts >= 5;
    }

    @Scheduled(cron = "0 0 0 * * *")
    public void cleanupOldLogs() {
        LocalDateTime threshold = LocalDateTime.now().minusDays(90);
        auditLogRepository.findByTimestampBetween(
            LocalDateTime.now().minusYears(1), threshold, Pageable.unpaged())
            .forEach(auditLogRepository::delete);
    }
}

@Service
class UserPreferencesService {
    private final UserPreferencesRepository preferencesRepository;
    private final AuditService auditService;

    public UserPreferencesService(UserPreferencesRepository preferencesRepository,
                                AuditService auditService) {
        this.preferencesRepository = preferencesRepository;
        this.auditService = auditService;
    }

    public UserPreferences getPreferences(Long userId) {
        return preferencesRepository.findById(userId)
            .orElseGet(() -> {
                UserPreferences prefs = new UserPreferences();
                prefs.setUserId(userId);
                return preferencesRepository.save(prefs);
            });
    }

    public void updatePreferences(Long userId, UserPreferences preferences, String ipAddress) {
        preferences.setUserId(userId);
        preferencesRepository.save(preferences);
        auditService.logAction("SYSTEM", "UPDATE_PREFERENCES", ipAddress,
            "Updated preferences for user " + userId, null);
    }

    @Transactional
    public void enableTwoFactor(Long userId, String secret) {
        UserPreferences prefs = getPreferences(userId);
        prefs.setTwoFactorEnabled(true);
        prefs.setTwoFactorSecret(secret);
        preferencesRepository.save(prefs);
    }

    @Transactional
    public void disableTwoFactor(Long userId) {
        UserPreferences prefs = getPreferences(userId);
        prefs.setTwoFactorEnabled(false);
        prefs.setTwoFactorSecret(null);
        preferencesRepository.save(prefs);
    }
}

@RestController
@RequestMapping("/api/preferences")
class PreferencesController {
    private final UserPreferencesService preferencesService;

    public PreferencesController(UserPreferencesService preferencesService) {
        this.preferencesService = preferencesService;
    }

    @GetMapping("/{userId}")
    public UserPreferences getPreferences(@PathVariable Long userId) {
        return preferencesService.getPreferences(userId);
    }

    @PutMapping("/{userId}")
    public Map<String, String> updatePreferences(
            @PathVariable Long userId,
            @RequestBody UserPreferences preferences,
            @RequestHeader("X-Forwarded-For") String ipAddress) {
        preferencesService.updatePreferences(userId, preferences, ipAddress);
        return Map.of("message", "Preferences updated successfully");
    }

    @PostMapping("/{userId}/2fa/enable")
    public Map<String, String> enableTwoFactor(
            @PathVariable Long userId,
            @RequestBody Map<String, String> request) {
        preferencesService.enableTwoFactor(userId, request.get("secret"));
        return Map.of("message", "Two-factor authentication enabled");
    }

    @PostMapping("/{userId}/2fa/disable")
    public Map<String, String> disableTwoFactor(@PathVariable Long userId) {
        preferencesService.disableTwoFactor(userId);
        return Map.of("message", "Two-factor authentication disabled");
    }
}

@RestController
@RequestMapping("/api/audit")
class AuditController {
    private final AuditService auditService;
    private final AuditLogRepository auditLogRepository;

    public AuditController(AuditService auditService, AuditLogRepository auditLogRepository) {
        this.auditService = auditService;
        this.auditLogRepository = auditLogRepository;
    }

    @GetMapping("/logs/{username}")
    public List<AuditLog> getUserLogs(@PathVariable String username) {
        return auditLogRepository.findByUsernameOrderByTimestampDesc(username);
    }

    @GetMapping("/logs")
    public Page<AuditLog> getLogs(
            @RequestParam LocalDateTime start,
            @RequestParam LocalDateTime end,
            Pageable pageable) {
        return auditLogRepository.findByTimestampBetween(start, end, pageable);
    }
} 