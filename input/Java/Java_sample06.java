import java.io.*;
import java.net.*;
import java.security.*;
import java.sql.*;
import java.util.*;
import javax.servlet.*;
import javax.servlet.http.*;
import javax.servlet.annotation.WebServlet;

@WebServlet("/vulnerable/*")
public class VulnerableWebApp extends HttpServlet {
    
    private static final Map<String, User> users = new HashMap<>();
    private static final Map<String, Session> sessions = new HashMap<>();
    
    static {
        users.put("admin", new User("1", "admin", "admin123", "admin@example.com", true));
        users.put("user", new User("2", "user", "password", "user@example.com", false));
    }
    
    private static class User {
        String id, username, password, email;
        boolean isAdmin;
        
        User(String id, String username, String password, String email, boolean isAdmin) {
            this.id = id;
            this.username = username;
            this.password = password;
            this.email = email;
            this.isAdmin = isAdmin;
        }
    }
    
    private static class Session {
        String userId, username;
        boolean isAdmin;
        Date created;
        
        Session(String userId, String username, boolean isAdmin) {
            this.userId = userId;
            this.username = username;
            this.isAdmin = isAdmin;
            this.created = new Date();
        }
    }
    
    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        
        String path = request.getPathInfo();
        if (path == null) path = "/";
        
        System.out.println("[" + new Date() + "] GET " + path);
        
        switch (path) {
            case "/":
                handleIndex(request, response);
                break;
            case "/file":
                handleFileRead(request, response);
                break;
            case "/exec":
                handleCommandExecution(request, response);
                break;
            case "/search":
                handleFileSearch(request, response);
                break;
            case "/userinfo":
                handleUserInfo(request, response);
                break;
            case "/admin":
                handleAdminPanel(request, response);
                break;
            default:
                response.sendError(HttpServletResponse.SC_NOT_FOUND);
        }
    }
    
    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        
        String path = request.getPathInfo();
        if (path == null) path = "/";
        
        System.out.println("[" + new Date() + "] POST " + path);
        
        switch (path) {
            case "/login":
                handleLogin(request, response);
                break;
            case "/upload":
                handleFileUpload(request, response);
                break;
            default:
                response.sendError(HttpServletResponse.SC_NOT_FOUND);
        }
    }
    
    private void handleIndex(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        
        String html = """
            <html>
            <head><title>Vulnerable Web App</title></head>
            <body>
                <h1>Welcome to Vulnerable Web App</h1>
                <p>Available endpoints:</p>
                <ul>
                    <li>GET /file?path=&lt;path&gt; - Read file</li>
                    <li>GET /exec?cmd=&lt;command&gt; - Execute command</li>
                    <li>GET /search?q=&lt;query&gt; - Search files</li>
                    <li>POST /login - Login</li>
                    <li>POST /upload - Upload file</li>
                    <li>GET /userinfo - User info</li>
                    <li>GET /admin - Admin panel</li>
                </ul>
            </body>
            </html>""";
        
        response.setContentType("text/html");
        response.getWriter().write(html);
    }
    
    private void handleFileRead(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        
        String filePath = request.getParameter("path");
        if (filePath == null || filePath.isEmpty()) {
            response.sendError(HttpServletResponse.SC_BAD_REQUEST, "No file path specified");
            return;
        }
        
        File file = new File(filePath);
        
        if (!file.exists()) {
            response.sendError(HttpServletResponse.SC_NOT_FOUND, "File not found");
            return;
        }
        
        try (FileInputStream fis = new FileInputStream(file);
             BufferedReader reader = new BufferedReader(new InputStreamReader(fis))) {
            
            StringBuilder content = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) {
                content.append(line).append("\n");
            }
            
            response.setContentType("text/plain");
            response.getWriter().write(content.toString());
            
        } catch (IOException e) {
            response.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR, "Error reading file");
        }
    }
    
    private void handleCommandExecution(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        
        String command = request.getParameter("cmd");
        if (command == null || command.isEmpty()) {
            response.sendError(HttpServletResponse.SC_BAD_REQUEST, "No command specified");
            return;
        }
        
        try {
            Process process = Runtime.getRuntime().exec(command);
            BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
            
            StringBuilder output = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) {
                output.append(line).append("\n");
            }
            
            response.setContentType("text/plain");
            response.getWriter().write(output.toString());
            
        } catch (IOException e) {
            response.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR, "Command execution failed");
        }
    }
    
    private void handleFileSearch(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        
        String query = request.getParameter("q");
        if (query == null || query.isEmpty()) {
            response.sendError(HttpServletResponse.SC_BAD_REQUEST, "No search query specified");
            return;
        }
        
        String searchCommand = "find . -name '*" + query + "*' -type f 2>/dev/null";
        
        try {
            Process process = Runtime.getRuntime().exec(searchCommand);
            BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
            
            StringBuilder results = new StringBuilder();
            results.append("<html><body><h1>Search Results</h1><ul>");
            
            String line;
            while ((line = reader.readLine()) != null) {
                if (!line.isEmpty()) {
                    results.append("<li>").append(line).append("</li>");
                }
            }
            
            results.append("</ul></body></html>");
            
            response.setContentType("text/html");
            response.getWriter().write(results.toString());
            
        } catch (IOException e) {
            response.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR, "Search failed");
        }
    }
    
    private void handleLogin(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        
        String username = request.getParameter("username");
        String password = request.getParameter("password");
        
        if (username == null || password == null) {
            response.sendError(HttpServletResponse.SC_BAD_REQUEST, "Missing credentials");
            return;
        }
        
        User user = users.get(username);
        if (user == null || !user.password.equals(password)) {
            response.sendError(HttpServletResponse.SC_UNAUTHORIZED, "Invalid credentials");
            return;
        }
        
        String token = generateToken();
        sessions.put(token, new Session(user.id, user.username, user.isAdmin));
        
        Cookie sessionCookie = new Cookie("session", token);
        sessionCookie.setPath("/");
        sessionCookie.setHttpOnly(true);
        sessionCookie.setMaxAge(3600);
        response.addCookie(sessionCookie);
        
        String html = "<html><body><h1>Login successful for user: " + user.username + "</h1></body></html>";
        response.setContentType("text/html");
        response.getWriter().write(html);
    }
    
    private void handleFileUpload(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        
        Part filePart = request.getPart("file");
        if (filePart == null) {
            response.sendError(HttpServletResponse.SC_BAD_REQUEST, "No file uploaded");
            return;
        }
        
        String fileName = filePart.getSubmittedFileName();
        if (fileName == null || fileName.isEmpty()) {
            fileName = "upload_" + System.currentTimeMillis();
        }
        
        File uploadDir = new File("uploads");
        if (!uploadDir.exists()) {
            uploadDir.mkdirs();
        }
        
        File uploadedFile = new File(uploadDir, fileName);
        
        try (InputStream input = filePart.getInputStream();
             FileOutputStream output = new FileOutputStream(uploadedFile)) {
            
            byte[] buffer = new byte[1024];
            int bytesRead;
            while ((bytesRead = input.read(buffer)) != -1) {
                output.write(buffer, 0, bytesRead);
            }
            
            String html = "<html><body><h1>File uploaded successfully: " + uploadedFile.getPath() + "</h1></body></html>";
            response.setContentType("text/html");
            response.getWriter().write(html);
            
        } catch (IOException e) {
            response.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR, "Upload failed");
        }
    }
    
    private void handleUserInfo(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        
        Cookie[] cookies = request.getCookies();
        String sessionToken = null;
        
        if (cookies != null) {
            for (Cookie cookie : cookies) {
                if ("session".equals(cookie.getName())) {
                    sessionToken = cookie.getValue();
                    break;
                }
            }
        }
        
        if (sessionToken == null) {
            response.sendError(HttpServletResponse.SC_UNAUTHORIZED, "No session found");
            return;
        }
        
        Session session = sessions.get(sessionToken);
        if (session == null) {
            response.sendError(HttpServletResponse.SC_UNAUTHORIZED, "Invalid session");
            return;
        }
        
        Map<String, Object> userInfo = new HashMap<>();
        userInfo.put("user_id", session.userId);
        userInfo.put("username", session.username);
        userInfo.put("is_admin", session.isAdmin);
        userInfo.put("created", session.created);
        userInfo.put("session_id", sessionToken);
        
        response.setContentType("application/json");
        response.getWriter().write(new Gson().toJson(userInfo));
    }
    
    private void handleAdminPanel(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        
        Cookie[] cookies = request.getCookies();
        String sessionToken = null;
        
        if (cookies != null) {
            for (Cookie cookie : cookies) {
                if ("session".equals(cookie.getName())) {
                    sessionToken = cookie.getValue();
                    break;
                }
            }
        }
        
        if (sessionToken == null) {
            response.sendError(HttpServletResponse.SC_UNAUTHORIZED, "No session found");
            return;
        }
        
        Session session = sessions.get(sessionToken);
        if (session == null || !session.isAdmin) {
            response.sendError(HttpServletResponse.SC_FORBIDDEN, "Access denied");
            return;
        }
        
        String action = request.getParameter("action");
        
        switch (action) {
            case "list_users":
                listUsers(response);
                break;
            case "delete_user":
                deleteUser(request, response);
                break;
            case "system_info":
                getSystemInfo(response);
                break;
            default:
                response.sendError(HttpServletResponse.SC_BAD_REQUEST, "Invalid action");
        }
    }
    
    private void listUsers(HttpServletResponse response) throws IOException {
        List<Map<String, Object>> userList = new ArrayList<>();
        for (User user : users.values()) {
            Map<String, Object> userData = new HashMap<>();
            userData.put("id", user.id);
            userData.put("username", user.username);
            userData.put("email", user.email);
            userData.put("password", user.password);
            userData.put("is_admin", user.isAdmin);
            userList.add(userData);
        }
        
        response.setContentType("application/json");
        response.getWriter().write(new Gson().toJson(userList));
    }
    
    private void deleteUser(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        
        String userId = request.getParameter("user_id");
        if (userId == null || userId.isEmpty()) {
            response.sendError(HttpServletResponse.SC_BAD_REQUEST, "No user ID specified");
            return;
        }
        
        users.remove(userId);
        
        String html = "<html><body><h1>User " + userId + " deleted successfully</h1></body></html>";
        response.setContentType("text/html");
        response.getWriter().write(html);
    }
    
    private void getSystemInfo(HttpServletResponse response) throws IOException {
        try {
            Process process = Runtime.getRuntime().exec("uname -a");
            BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
            
            StringBuilder output = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) {
                output.append(line);
            }
            
            Map<String, String> info = new HashMap<>();
            info.put("system_info", output.toString());
            info.put("timestamp", new Date().toString());
            
            response.setContentType("application/json");
            response.getWriter().write(new Gson().toJson(info));
            
        } catch (IOException e) {
            response.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR, "Failed to get system info");
        }
    }
    
    private String generateToken() {
        Random random = new Random();
        byte[] bytes = new byte[16];
        random.nextBytes(bytes);
        return Base64.getEncoder().encodeToString(bytes);
    }
    
    private static class Gson {
        public String toJson(Object obj) {
            if (obj instanceof Map) {
                Map<?, ?> map = (Map<?, ?>) obj;
                StringBuilder json = new StringBuilder("{");
                boolean first = true;
                for (Map.Entry<?, ?> entry : map.entrySet()) {
                    if (!first) json.append(",");
                    json.append("\"").append(entry.getKey()).append("\":");
                    if (entry.getValue() instanceof String) {
                        json.append("\"").append(entry.getValue()).append("\"");
                    } else {
                        json.append(entry.getValue());
                    }
                    first = false;
                }
                json.append("}");
                return json.toString();
            } else if (obj instanceof List) {
                List<?> list = (List<?>) obj;
                StringBuilder json = new StringBuilder("[");
                boolean first = true;
                for (Object item : list) {
                    if (!first) json.append(",");
                    json.append(toJson(item));
                    first = false;
                }
                json.append("]");
                return json.toString();
            }
            return obj.toString();
        }
    }
} 