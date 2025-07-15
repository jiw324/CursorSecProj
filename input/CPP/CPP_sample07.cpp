#include <iostream>
#include <string>
#include <vector>
#include <map>
#include <fstream>
#include <sstream>
#include <cstring>
#include <cstdlib>
#include <memory>
#include <algorithm>
#include <regex>
#include <chrono>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <queue>
#include <atomic>
#include <set>
#include <optional>
#include <variant>

class XMLValidator {
private:
    std::set<std::string> allowed_tags;
    std::set<std::string> allowed_attributes;
    size_t max_depth;
    size_t max_children;
    size_t max_attributes;
    size_t max_text_length;
    bool allow_comments;
    bool allow_cdata;
    bool allow_dtd;
    
public:
    XMLValidator() : max_depth(100), max_children(1000), 
                    max_attributes(50), max_text_length(10000),
                    allow_comments(true), allow_cdata(true), allow_dtd(false) {}
    
    void add_allowed_tag(const std::string& tag) {
        allowed_tags.insert(tag);
    }
    
    void add_allowed_attribute(const std::string& attr) {
        allowed_attributes.insert(attr);
    }
    
    bool is_tag_allowed(const std::string& tag) const {
        return allowed_tags.empty() || allowed_tags.find(tag) != allowed_tags.end();
    }
    
    bool is_attribute_allowed(const std::string& attr) const {
        return allowed_attributes.empty() || allowed_attributes.find(attr) != allowed_attributes.end();
    }
    
    void set_max_depth(size_t depth) { max_depth = depth; }
    void set_max_children(size_t children) { max_children = children; }
    void set_max_attributes(size_t attributes) { max_attributes = attributes; }
    void set_max_text_length(size_t length) { max_text_length = length; }
    void set_allow_comments(bool allow) { allow_comments = allow; }
    void set_allow_cdata(bool allow) { allow_cdata = allow; }
    void set_allow_dtd(bool allow) { allow_dtd = allow; }
    
    size_t get_max_depth() const { return max_depth; }
    size_t get_max_children() const { return max_children; }
    size_t get_max_attributes() const { return max_attributes; }
    size_t get_max_text_length() const { return max_text_length; }
    bool get_allow_comments() const { return allow_comments; }
    bool get_allow_cdata() const { return allow_cdata; }
    bool get_allow_dtd() const { return allow_dtd; }
};

class XMLSanitizer {
public:
    static std::string sanitize_text(const std::string& text) {
        std::string result;
        result.reserve(text.length());
        
        for (char c : text) {
            switch (c) {
                case '<': result += "&lt;"; break;
                case '>': result += "&gt;"; break;
                case '&': result += "&amp;"; break;
                case '"': result += "&quot;"; break;
                case '\'': result += "&apos;"; break;
                default:
                    if (isprint(c) || c == '\n' || c == '\r' || c == '\t') {
                        result += c;
                    }
                    break;
            }
        }
        
        return result;
    }
    
    static std::string sanitize_attribute(const std::string& attr) {
        return sanitize_text(attr);
    }
    
    static std::string sanitize_tag_name(const std::string& tag) {
        std::string result;
        result.reserve(tag.length());
        
        for (char c : tag) {
            if (isalnum(c) || c == '_' || c == '-' || c == ':') {
                result += c;
            }
        }
        
        return result;
    }
};

class XMLError : public std::runtime_error {
public:
    enum class Type {
        InvalidSyntax,
        MaxDepthExceeded,
        MaxChildrenExceeded,
        MaxAttributesExceeded,
        MaxTextLengthExceeded,
        DisallowedTag,
        DisallowedAttribute,
        DisallowedDTD,
        DisallowedComment,
        DisallowedCDATA,
        ExternalEntityNotAllowed,
        MalformedEntity,
        IOError
    };
    
    XMLError(Type type, const std::string& message)
        : std::runtime_error(message), type_(type) {}
    
    Type get_type() const { return type_; }
    
private:
    Type type_;
};

class XMLStats {
public:
    size_t total_nodes = 0;
    size_t max_depth = 0;
    size_t total_attributes = 0;
    size_t total_text_length = 0;
    std::map<std::string, size_t> tag_counts;
    std::map<std::string, size_t> attribute_counts;
    std::chrono::milliseconds parse_time{0};
    
    void print() const {
        std::cout << "XML Statistics:" << std::endl;
        std::cout << "  Total nodes: " << total_nodes << std::endl;
        std::cout << "  Maximum depth: " << max_depth << std::endl;
        std::cout << "  Total attributes: " << total_attributes << std::endl;
        std::cout << "  Total text length: " << total_text_length << std::endl;
        std::cout << "  Parse time: " << parse_time.count() << "ms" << std::endl;
        
        std::cout << "\nMost common tags:" << std::endl;
        std::vector<std::pair<std::string, size_t>> tags(tag_counts.begin(), tag_counts.end());
        std::sort(tags.begin(), tags.end(),
                 [](const auto& a, const auto& b) { return a.second > b.second; });
        
        for (size_t i = 0; i < std::min(tags.size(), size_t(5)); ++i) {
            std::cout << "  " << tags[i].first << ": " << tags[i].second << std::endl;
        }
        
        std::cout << "\nMost common attributes:" << std::endl;
        std::vector<std::pair<std::string, size_t>> attrs(attribute_counts.begin(), attribute_counts.end());
        std::sort(attrs.begin(), attrs.end(),
                 [](const auto& a, const auto& b) { return a.second > b.second; });
        
        for (size_t i = 0; i < std::min(attrs.size(), size_t(5)); ++i) {
            std::cout << "  " << attrs[i].first << ": " << attrs[i].second << std::endl;
        }
    }
};

class XMLParser {
private:
    std::string xml_content;
    std::map<std::string, std::string> entities;
    bool external_entities_enabled;
    XMLValidator validator;
    XMLStats stats;
    std::atomic<bool> parsing_cancelled{false};
    std::mutex parse_mutex;
    
    struct XMLNode {
        std::string name;
        std::map<std::string, std::string> attributes;
        std::string content;
        std::vector<std::shared_ptr<XMLNode>> children;
        std::weak_ptr<XMLNode> parent;
        size_t depth = 0;
        
        bool has_circular_reference() const {
            std::set<const XMLNode*> visited;
            const XMLNode* current = this;
            while (current) {
                if (!visited.insert(current).second) {
                    return true;
                }
                auto parent_ptr = current->parent.lock();
                if (!parent_ptr) break;
                current = parent_ptr.get();
            }
            return false;
        }
    };
    
    class ParseGuard {
    private:
        XMLParser& parser;
        std::chrono::steady_clock::time_point start;
        
    public:
        ParseGuard(XMLParser& p) : parser(p), start(std::chrono::steady_clock::now()) {
            parser.parsing_cancelled = false;
        }
        
        ~ParseGuard() {
            auto end = std::chrono::steady_clock::now();
            parser.stats.parse_time = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);
        }
    };

public:
    XMLParser() : external_entities_enabled(true) {}
    
    ~XMLParser() = default;
    
    void set_external_entities(bool enabled) {
        external_entities_enabled = enabled;
    }
    
    void set_validator(const XMLValidator& val) {
        validator = val;
    }
    
    const XMLStats& get_stats() const {
        return stats;
    }
    
    void cancel_parsing() {
        parsing_cancelled = true;
    }
    
    bool load_from_file(const std::string& filename) {
        std::ifstream file(filename);
        if (!file.is_open()) {
            throw XMLError(XMLError::Type::IOError, "Failed to open file: " + filename);
        }
        
        std::stringstream buffer;
        buffer << file.rdbuf();
        xml_content = buffer.str();
        
        return true;
    }
    
    bool load_from_string(const std::string& content) {
        xml_content = content;
        return true;
    }
    
    std::shared_ptr<XMLNode> parse() {
        if (xml_content.empty()) {
            return nullptr;
        }
        
        ParseGuard guard(*this);
        stats = XMLStats();
        
        try {
            return parse_node(xml_content, 0);
        } catch (const XMLError& e) {
            std::cerr << "XML parsing error: " << e.what() << std::endl;
            return nullptr;
        }
    }
    
    std::string process_entities(const std::string& text) {
        if (text.length() > validator.get_max_text_length()) {
            throw XMLError(XMLError::Type::MaxTextLengthExceeded,
                         "Text length exceeds maximum allowed");
        }
        
        std::string result = text;
        
        if (external_entities_enabled) {
            std::regex entity_regex("&([^;]+);");
            std::smatch match;
            
            while (std::regex_search(result, match, entity_regex)) {
                if (parsing_cancelled) {
                    throw XMLError(XMLError::Type::InvalidSyntax, "Parsing cancelled");
                }
                
                std::string entity_name = match[1];
                std::string replacement = resolve_entity(entity_name);
                result.replace(match.position(), match.length(), replacement);
            }
        }
        
        return XMLSanitizer::sanitize_text(result);
    }
    
    std::string resolve_entity(const std::string& entity_name) {
        if (entity_name == "lt") return "<";
        if (entity_name == "gt") return ">";
        if (entity_name == "amp") return "&";
        if (entity_name == "quot") return "\"";
        if (entity_name == "apos") return "'";
        
        if (entity_name.find("SYSTEM") != std::string::npos) {
            if (!validator.get_allow_dtd()) {
                throw XMLError(XMLError::Type::DisallowedDTD,
                             "DTD processing is not allowed");
            }
            return resolve_external_entity(entity_name);
        }
        
        auto it = entities.find(entity_name);
        if (it != entities.end()) {
            return it->second;
        }
        
        throw XMLError(XMLError::Type::MalformedEntity,
                      "Unknown entity: " + entity_name);
    }
    
    std::string resolve_external_entity(const std::string& entity_decl) {
        if (!external_entities_enabled) {
            throw XMLError(XMLError::Type::ExternalEntityNotAllowed,
                         "External entity processing is disabled");
        }
        
        size_t system_pos = entity_decl.find("SYSTEM");
        if (system_pos == std::string::npos) {
            throw XMLError(XMLError::Type::MalformedEntity,
                         "Invalid external entity declaration");
        }
        
        size_t quote_start = entity_decl.find('"', system_pos);
        if (quote_start == std::string::npos) {
            throw XMLError(XMLError::Type::MalformedEntity,
                         "Invalid external entity declaration");
        }
        
        size_t quote_end = entity_decl.find('"', quote_start + 1);
        if (quote_end == std::string::npos) {
            throw XMLError(XMLError::Type::MalformedEntity,
                         "Invalid external entity declaration");
        }
        
        std::string file_path = entity_decl.substr(quote_start + 1, 
                                                 quote_end - quote_start - 1);
        
        std::ifstream file(file_path);
        if (file.is_open()) {
            std::stringstream buffer;
            buffer << file.rdbuf();
            return buffer.str();
        }
        
        throw XMLError(XMLError::Type::IOError,
                      "Failed to read external entity: " + file_path);
    }
    
    void add_entity(const std::string& name, const std::string& value) {
        entities[XMLSanitizer::sanitize_tag_name(name)] = 
            XMLSanitizer::sanitize_text(value);
    }
    
    std::string extract_cdata(const std::string& text) {
        if (!validator.get_allow_cdata()) {
            throw XMLError(XMLError::Type::DisallowedCDATA,
                         "CDATA sections are not allowed");
        }
        
        std::string result = text;
        std::regex cdata_regex("<!\\[CDATA\\[(.*?)\\]\\]>");
        std::smatch match;
        
        while (std::regex_search(result, match, cdata_regex)) {
            if (parsing_cancelled) {
                throw XMLError(XMLError::Type::InvalidSyntax, "Parsing cancelled");
            }
            
            std::string cdata_content = match[1];
            result.replace(match.position(), match.length(), 
                         XMLSanitizer::sanitize_text(cdata_content));
        }
        
        return result;
    }
    
    std::shared_ptr<XMLNode> parse_node(const std::string& content, size_t depth) {
        if (parsing_cancelled) {
            throw XMLError(XMLError::Type::InvalidSyntax, "Parsing cancelled");
        }
        
        if (depth > validator.get_max_depth()) {
            throw XMLError(XMLError::Type::MaxDepthExceeded,
                         "Maximum nesting depth exceeded");
        }
        
        auto node = std::make_shared<XMLNode>();
        node->depth = depth;
        stats.max_depth = std::max(stats.max_depth, depth);
        stats.total_nodes++;
        
        size_t tag_start = content.find('<');
        if (tag_start == std::string::npos) {
            return nullptr;
        }
        
        size_t tag_end = content.find('>', tag_start);
        if (tag_end == std::string::npos) {
            throw XMLError(XMLError::Type::InvalidSyntax,
                         "Unclosed tag found");
        }
        
        std::string tag_content = content.substr(tag_start + 1, tag_end - tag_start - 1);
        
        if (tag_content[0] == '/') {
            return nullptr;
        }
        
        bool self_closing = (tag_content.back() == '/');
        
        size_t space_pos = tag_content.find(' ');
        if (space_pos != std::string::npos) {
            node->name = XMLSanitizer::sanitize_tag_name(
                tag_content.substr(0, space_pos));
            parse_attributes(tag_content.substr(space_pos + 1), node);
        } else {
            node->name = XMLSanitizer::sanitize_tag_name(
                self_closing ? tag_content.substr(0, tag_content.length() - 1) 
                           : tag_content);
        }
        
        if (!validator.is_tag_allowed(node->name)) {
            throw XMLError(XMLError::Type::DisallowedTag,
                         "Tag not allowed: " + node->name);
        }
        
        stats.tag_counts[node->name]++;
        
        if (self_closing) {
            return node;
        }
        
        std::string closing_tag = "</" + node->name + ">";
        size_t content_start = tag_end + 1;
        size_t content_end = content.find(closing_tag, content_start);
        
        if (content_end == std::string::npos) {
            throw XMLError(XMLError::Type::InvalidSyntax,
                         "Missing closing tag for: " + node->name);
        }
        
        std::string raw_content = content.substr(content_start, 
                                               content_end - content_start);
        node->content = process_entities(extract_cdata(raw_content));
        stats.total_text_length += node->content.length();
        
        size_t child_start = 0;
        while (child_start < raw_content.length()) {
            if (node->children.size() >= validator.get_max_children()) {
                throw XMLError(XMLError::Type::MaxChildrenExceeded,
                             "Maximum number of child nodes exceeded");
            }
            
            size_t child_tag_start = raw_content.find('<', child_start);
            if (child_tag_start == std::string::npos) {
                break;
            }
            
            auto child_node = parse_node(raw_content, depth + 1);
            if (child_node) {
                child_node->parent = node;
                if (child_node->has_circular_reference()) {
                    throw XMLError(XMLError::Type::InvalidSyntax,
                                 "Circular reference detected");
                }
                node->children.push_back(child_node);
                child_start = raw_content.find('>', child_tag_start) + 1;
            } else {
                break;
            }
        }
        
        return node;
    }
    
    void parse_attributes(const std::string& attr_string, 
                         std::shared_ptr<XMLNode> node) {
        std::regex attr_regex("([^\\s=]+)=\"([^\"]*)\"");
        std::smatch match;
        std::string::const_iterator search_start(attr_string.cbegin());
        
        while (std::regex_search(search_start, attr_string.cend(), match, attr_regex)) {
            if (node->attributes.size() >= validator.get_max_attributes()) {
                throw XMLError(XMLError::Type::MaxAttributesExceeded,
                             "Maximum number of attributes exceeded");
            }
            
            std::string name = XMLSanitizer::sanitize_tag_name(match[1]);
            std::string value = match[2];
            
            if (!validator.is_attribute_allowed(name)) {
                throw XMLError(XMLError::Type::DisallowedAttribute,
                             "Attribute not allowed: " + name);
            }
            
            value = process_entities(value);
            
            node->attributes[name] = XMLSanitizer::sanitize_attribute(value);
            stats.attribute_counts[name]++;
            stats.total_attributes++;
            
            search_start = match.suffix().first;
        }
    }
    
    void print_node(const std::shared_ptr<XMLNode>& node, int depth = 0) {
        if (!node) return;
        
        std::string indent(depth * 2, ' ');
        std::cout << indent << "<" << node->name;
        
        for (const auto& attr : node->attributes) {
            std::cout << " " << attr.first << "=\"" << attr.second << "\"";
        }
        
        if (node->children.empty() && node->content.empty()) {
            std::cout << "/>" << std::endl;
        } else {
            std::cout << ">";
            
            if (!node->content.empty()) {
                std::cout << node->content;
            }
            
            if (!node->children.empty()) {
                std::cout << std::endl;
                for (const auto& child : node->children) {
                    print_node(child, depth + 1);
                }
                std::cout << indent;
            }
            
            std::cout << "</" << node->name << ">" << std::endl;
        }
    }
    
    std::string get_node_value(const std::shared_ptr<XMLNode>& node, 
                              const std::string& path) {
        if (!node) return "";
        
        std::vector<std::string> path_parts;
        std::istringstream path_stream(path);
        std::string part;
        
        while (std::getline(path_stream, part, '/')) {
            if (!part.empty()) {
                path_parts.push_back(part);
            }
        }
        
        return navigate_node(node, path_parts, 0);
    }
    
    std::string navigate_node(const std::shared_ptr<XMLNode>& node,
                            const std::vector<std::string>& path, 
                            size_t index) {
        if (!node || index >= path.size()) {
            return node ? node->content : "";
        }
        
        std::string target = path[index];
        
        for (const auto& child : node->children) {
            if (child->name == target) {
                return navigate_node(child, path, index + 1);
            }
        }
        
        return "";
    }
};

int main(int argc, char* argv[]) {
    if (argc < 2) {
        std::cout << "Usage: " << argv[0] << " <command> [args...]" << std::endl;
        std::cout << "Commands:" << std::endl;
        std::cout << "  parse <filename> - Parse XML file" << std::endl;
        std::cout << "  string <xml_string> - Parse XML string" << std::endl;
        std::cout << "  entity <name> <value> - Add entity" << std::endl;
        std::cout << "  external <enabled> - Enable/disable external entities" << std::endl;
        return 1;
    }
    
    XMLParser parser;
    XMLValidator validator;
    
    validator.set_max_depth(10);
    validator.set_max_children(100);
    validator.set_max_attributes(20);
    validator.set_max_text_length(1000);
    validator.set_allow_dtd(false);
    validator.set_allow_cdata(true);
    validator.set_allow_comments(true);
    
    parser.set_validator(validator);
    
    std::string command = argv[1];
    
    try {
        if (command == "parse" && argc == 3) {
            if (parser.load_from_file(argv[2])) {
                auto root = parser.parse();
                if (root) {
                    std::cout << "Parsed XML structure:" << std::endl;
                    parser.print_node(root);
                    parser.get_stats().print();
                } else {
                    std::cout << "Failed to parse XML" << std::endl;
                }
            }
        }
        else if (command == "string" && argc == 3) {
            if (parser.load_from_string(argv[2])) {
                auto root = parser.parse();
                if (root) {
                    std::cout << "Parsed XML structure:" << std::endl;
                    parser.print_node(root);
                    parser.get_stats().print();
                } else {
                    std::cout << "Failed to parse XML" << std::endl;
                }
            }
        }
        else if (command == "entity" && argc == 4) {
            parser.add_entity(argv[2], argv[3]);
            std::cout << "Added entity: " << argv[2] << " = " << argv[3] << std::endl;
        }
        else if (command == "external" && argc == 3) {
            bool enabled = (std::string(argv[2]) == "true");
            parser.set_external_entities(enabled);
            std::cout << "External entities " << (enabled ? "enabled" : "disabled") << std::endl;
        }
        else {
            std::cout << "Invalid command or arguments" << std::endl;
        }
    } catch (const XMLError& e) {
        std::cerr << "XML Error: " << e.what() << std::endl;
        return 1;
    }
    
    return 0;
} 