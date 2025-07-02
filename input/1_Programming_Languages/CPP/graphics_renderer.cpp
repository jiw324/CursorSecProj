// AI-Generated Code Header
// **Intent:** 2D graphics rendering system with OOP design patterns
// **Optimization:** Efficient rendering algorithms and memory management
// **Safety:** Bounds checking, resource management, and error handling

#include <iostream>
#include <vector>
#include <memory>
#include <string>
#include <algorithm>
#include <cmath>
#include <random>
#include <chrono>
#include <iomanip>
#include <sstream>
#include <functional>

namespace GraphicsEngine {

// AI-SUGGESTION: Basic mathematical structures
struct Point2D {
    double x, y;
    
    Point2D(double x = 0.0, double y = 0.0) : x(x), y(y) {}
    
    Point2D operator+(const Point2D& other) const {
        return Point2D(x + other.x, y + other.y);
    }
    
    Point2D operator-(const Point2D& other) const {
        return Point2D(x - other.x, y - other.y);
    }
    
    Point2D operator*(double scalar) const {
        return Point2D(x * scalar, y * scalar);
    }
    
    double distance(const Point2D& other) const {
        double dx = x - other.x;
        double dy = y - other.y;
        return std::sqrt(dx * dx + dy * dy);
    }
    
    double magnitude() const {
        return std::sqrt(x * x + y * y);
    }
    
    Point2D normalize() const {
        double mag = magnitude();
        return mag > 0 ? Point2D(x / mag, y / mag) : Point2D();
    }
};

struct Color {
    uint8_t r, g, b, a;
    
    Color(uint8_t r = 255, uint8_t g = 255, uint8_t b = 255, uint8_t a = 255)
        : r(r), g(g), b(b), a(a) {}
    
    static Color Red() { return Color(255, 0, 0); }
    static Color Green() { return Color(0, 255, 0); }
    static Color Blue() { return Color(0, 0, 255); }
    static Color Black() { return Color(0, 0, 0); }
    static Color White() { return Color(255, 255, 255); }
    
    Color blend(const Color& other, double alpha) const {
        return Color(
            static_cast<uint8_t>(r * (1.0 - alpha) + other.r * alpha),
            static_cast<uint8_t>(g * (1.0 - alpha) + other.g * alpha),
            static_cast<uint8_t>(b * (1.0 - alpha) + other.b * alpha),
            a
        );
    }
};

struct Rectangle {
    Point2D position;
    double width, height;
    
    Rectangle(Point2D pos, double w, double h) 
        : position(pos), width(w), height(h) {}
    
    bool contains(const Point2D& point) const {
        return point.x >= position.x && 
               point.x <= position.x + width &&
               point.y >= position.y && 
               point.y <= position.y + height;
    }
    
    bool intersects(const Rectangle& other) const {
        return !(position.x + width < other.position.x ||
                 other.position.x + other.width < position.x ||
                 position.y + height < other.position.y ||
                 other.position.y + other.height < position.y);
    }
};

// AI-SUGGESTION: Canvas for 2D rendering
class Canvas {
private:
    std::vector<std::vector<Color>> pixels_;
    int width_, height_;
    Color background_color_;
    
public:
    Canvas(int width, int height, Color bg = Color::White()) 
        : width_(width), height_(height), background_color_(bg) {
        pixels_.resize(height_, std::vector<Color>(width_, bg));
    }
    
    int width() const { return width_; }
    int height() const { return height_; }
    
    void clear() {
        for (auto& row : pixels_) {
            std::fill(row.begin(), row.end(), background_color_);
        }
    }
    
    void set_pixel(int x, int y, const Color& color) {
        if (x >= 0 && x < width_ && y >= 0 && y < height_) {
            pixels_[y][x] = color;
        }
    }
    
    Color get_pixel(int x, int y) const {
        if (x >= 0 && x < width_ && y >= 0 && y < height_) {
            return pixels_[y][x];
        }
        return Color::Black();
    }
    
    // AI-SUGGESTION: Bresenham's line algorithm
    void draw_line(Point2D start, Point2D end, const Color& color) {
        int x0 = static_cast<int>(start.x);
        int y0 = static_cast<int>(start.y);
        int x1 = static_cast<int>(end.x);
        int y1 = static_cast<int>(end.y);
        
        int dx = std::abs(x1 - x0);
        int dy = std::abs(y1 - y0);
        int sx = x0 < x1 ? 1 : -1;
        int sy = y0 < y1 ? 1 : -1;
        int err = dx - dy;
        
        while (true) {
            set_pixel(x0, y0, color);
            
            if (x0 == x1 && y0 == y1) break;
            
            int e2 = 2 * err;
            if (e2 > -dy) {
                err -= dy;
                x0 += sx;
            }
            if (e2 < dx) {
                err += dx;
                y0 += sy;
            }
        }
    }
    
    void draw_circle(Point2D center, double radius, const Color& color) {
        int cx = static_cast<int>(center.x);
        int cy = static_cast<int>(center.y);
        int r = static_cast<int>(radius);
        
        for (int y = -r; y <= r; ++y) {
            for (int x = -r; x <= r; ++x) {
                if (x * x + y * y <= r * r) {
                    set_pixel(cx + x, cy + y, color);
                }
            }
        }
    }
    
    void draw_rectangle(const Rectangle& rect, const Color& color) {
        int x = static_cast<int>(rect.position.x);
        int y = static_cast<int>(rect.position.y);
        int w = static_cast<int>(rect.width);
        int h = static_cast<int>(rect.height);
        
        for (int py = y; py < y + h; ++py) {
            for (int px = x; px < x + w; ++px) {
                set_pixel(px, py, color);
            }
        }
    }
    
    // AI-SUGGESTION: ASCII art representation
    std::string to_ascii() const {
        std::ostringstream oss;
        for (const auto& row : pixels_) {
            for (const auto& pixel : row) {
                char intensity = ' ';
                int gray = (pixel.r + pixel.g + pixel.b) / 3;
                if (gray > 200) intensity = ' ';
                else if (gray > 150) intensity = '.';
                else if (gray > 100) intensity = ':';
                else if (gray > 50) intensity = '#';
                else intensity = '@';
                oss << intensity;
            }
            oss << '\n';
        }
        return oss.str();
    }
};

// AI-SUGGESTION: Abstract drawable interface
class Drawable {
public:
    virtual ~Drawable() = default;
    virtual void draw(Canvas& canvas) const = 0;
    virtual Rectangle get_bounds() const = 0;
    virtual void update(double delta_time) {}
    virtual std::unique_ptr<Drawable> clone() const = 0;
};

// AI-SUGGESTION: Basic shape implementations
class CircleShape : public Drawable {
private:
    Point2D center_;
    double radius_;
    Color color_;
    Point2D velocity_;
    
public:
    CircleShape(Point2D center, double radius, Color color = Color::Blue())
        : center_(center), radius_(radius), color_(color) {}
    
    void draw(Canvas& canvas) const override {
        canvas.draw_circle(center_, radius_, color_);
    }
    
    Rectangle get_bounds() const override {
        return Rectangle(
            Point2D(center_.x - radius_, center_.y - radius_),
            2 * radius_, 2 * radius_
        );
    }
    
    void update(double delta_time) override {
        center_ = center_ + velocity_ * delta_time;
    }
    
    std::unique_ptr<Drawable> clone() const override {
        auto clone = std::make_unique<CircleShape>(center_, radius_, color_);
        clone->velocity_ = velocity_;
        return clone;
    }
    
    void set_velocity(const Point2D& vel) { velocity_ = vel; }
    Point2D get_center() const { return center_; }
    double get_radius() const { return radius_; }
    void set_center(const Point2D& center) { center_ = center; }
    void set_color(const Color& color) { color_ = color; }
};

class RectangleShape : public Drawable {
private:
    Rectangle rect_;
    Color color_;
    Point2D velocity_;
    
public:
    RectangleShape(Rectangle rect, Color color = Color::Red())
        : rect_(rect), color_(color) {}
    
    void draw(Canvas& canvas) const override {
        canvas.draw_rectangle(rect_, color_);
    }
    
    Rectangle get_bounds() const override {
        return rect_;
    }
    
    void update(double delta_time) override {
        rect_.position = rect_.position + velocity_ * delta_time;
    }
    
    std::unique_ptr<Drawable> clone() const override {
        auto clone = std::make_unique<RectangleShape>(rect_, color_);
        clone->velocity_ = velocity_;
        return clone;
    }
    
    void set_velocity(const Point2D& vel) { velocity_ = vel; }
    Point2D get_position() const { return rect_.position; }
    void set_position(const Point2D& pos) { rect_.position = pos; }
    void set_color(const Color& color) { color_ = color; }
};

// AI-SUGGESTION: Particle system
class Particle {
public:
    Point2D position;
    Point2D velocity;
    Color color;
    double life_time;
    double max_life;
    double size;
    
    Particle(Point2D pos, Point2D vel, Color col, double life)
        : position(pos), velocity(vel), color(col), life_time(life), max_life(life), size(2.0) {}
    
    void update(double delta_time) {
        position = position + velocity * delta_time;
        life_time -= delta_time;
        
        // AI-SUGGESTION: Fade out over time
        double alpha = life_time / max_life;
        color.a = static_cast<uint8_t>(255 * alpha);
    }
    
    bool is_alive() const {
        return life_time > 0;
    }
    
    void draw(Canvas& canvas) const {
        if (is_alive()) {
            canvas.draw_circle(position, size, color);
        }
    }
};

class ParticleSystem : public Drawable {
private:
    std::vector<Particle> particles_;
    Point2D emitter_position_;
    double emission_rate_;
    double time_since_emission_;
    std::mt19937 rng_;
    
    void emit_particle() {
        std::uniform_real_distribution<double> angle_dist(0, 2 * M_PI);
        std::uniform_real_distribution<double> speed_dist(20, 100);
        std::uniform_real_distribution<double> life_dist(1.0, 3.0);
        
        double angle = angle_dist(rng_);
        double speed = speed_dist(rng_);
        Point2D velocity(std::cos(angle) * speed, std::sin(angle) * speed);
        
        Color particle_color = Color(
            static_cast<uint8_t>(std::uniform_int_distribution<int>(100, 255)(rng_)),
            static_cast<uint8_t>(std::uniform_int_distribution<int>(50, 150)(rng_)),
            static_cast<uint8_t>(std::uniform_int_distribution<int>(0, 100)(rng_))
        );
        
        particles_.emplace_back(emitter_position_, velocity, particle_color, life_dist(rng_));
    }
    
public:
    ParticleSystem(Point2D position, double rate = 50.0)
        : emitter_position_(position), emission_rate_(rate), time_since_emission_(0.0),
          rng_(std::random_device{}()) {}
    
    void draw(Canvas& canvas) const override {
        for (const auto& particle : particles_) {
            particle.draw(canvas);
        }
    }
    
    Rectangle get_bounds() const override {
        if (particles_.empty()) {
            return Rectangle(emitter_position_, 1, 1);
        }
        
        double min_x = particles_[0].position.x;
        double max_x = particles_[0].position.x;
        double min_y = particles_[0].position.y;
        double max_y = particles_[0].position.y;
        
        for (const auto& p : particles_) {
            min_x = std::min(min_x, p.position.x);
            max_x = std::max(max_x, p.position.x);
            min_y = std::min(min_y, p.position.y);
            max_y = std::max(max_y, p.position.y);
        }
        
        return Rectangle(Point2D(min_x, min_y), max_x - min_x, max_y - min_y);
    }
    
    void update(double delta_time) override {
        // AI-SUGGESTION: Update existing particles
        for (auto& particle : particles_) {
            particle.update(delta_time);
        }
        
        // AI-SUGGESTION: Remove dead particles
        particles_.erase(
            std::remove_if(particles_.begin(), particles_.end(),
                [](const Particle& p) { return !p.is_alive(); }),
            particles_.end()
        );
        
        // AI-SUGGESTION: Emit new particles
        time_since_emission_ += delta_time;
        double emission_interval = 1.0 / emission_rate_;
        
        while (time_since_emission_ >= emission_interval) {
            emit_particle();
            time_since_emission_ -= emission_interval;
        }
    }
    
    std::unique_ptr<Drawable> clone() const override {
        return std::make_unique<ParticleSystem>(emitter_position_, emission_rate_);
    }
    
    void set_position(const Point2D& pos) { emitter_position_ = pos; }
    size_t get_particle_count() const { return particles_.size(); }
};

// AI-SUGGESTION: Scene manager
class Scene {
private:
    std::vector<std::unique_ptr<Drawable>> objects_;
    Canvas canvas_;
    std::string name_;
    
public:
    Scene(const std::string& name, int width, int height)
        : canvas_(width, height), name_(name) {}
    
    void add_object(std::unique_ptr<Drawable> object) {
        objects_.push_back(std::move(object));
    }
    
    void remove_object(size_t index) {
        if (index < objects_.size()) {
            objects_.erase(objects_.begin() + index);
        }
    }
    
    void update(double delta_time) {
        for (auto& object : objects_) {
            object->update(delta_time);
        }
        
        // AI-SUGGESTION: Simple collision detection for circles
        for (size_t i = 0; i < objects_.size(); ++i) {
            auto* circle1 = dynamic_cast<CircleShape*>(objects_[i].get());
            if (!circle1) continue;
            
            for (size_t j = i + 1; j < objects_.size(); ++j) {
                auto* circle2 = dynamic_cast<CircleShape*>(objects_[j].get());
                if (!circle2) continue;
                
                double distance = circle1->get_center().distance(circle2->get_center());
                double min_distance = circle1->get_radius() + circle2->get_radius();
                
                if (distance < min_distance) {
                    // AI-SUGGESTION: Simple collision response
                    Point2D direction = (circle2->get_center() - circle1->get_center()).normalize();
                    double overlap = min_distance - distance;
                    
                    circle1->set_center(circle1->get_center() - direction * (overlap / 2));
                    circle2->set_center(circle2->get_center() + direction * (overlap / 2));
                    
                    // AI-SUGGESTION: Change colors on collision
                    circle1->set_color(Color::Green());
                    circle2->set_color(Color::Green());
                }
            }
        }
    }
    
    void render() {
        canvas_.clear();
        
        for (const auto& object : objects_) {
            object->draw(canvas_);
        }
    }
    
    std::string get_ascii_frame() const {
        return canvas_.to_ascii();
    }
    
    size_t get_object_count() const { return objects_.size(); }
    const std::string& get_name() const { return name_; }
    
    // AI-SUGGESTION: Query objects by type
    template<typename T>
    std::vector<T*> get_objects_of_type() const {
        std::vector<T*> result;
        for (const auto& obj : objects_) {
            if (auto* typed_obj = dynamic_cast<T*>(obj.get())) {
                result.push_back(typed_obj);
            }
        }
        return result;
    }
};

// AI-SUGGESTION: Animation system
class Animation {
private:
    std::function<void(double)> update_func_;
    double duration_;
    double elapsed_time_;
    bool loop_;
    bool finished_;
    
public:
    Animation(std::function<void(double)> func, double duration, bool loop = false)
        : update_func_(func), duration_(duration), elapsed_time_(0.0), loop_(loop), finished_(false) {}
    
    void update(double delta_time) {
        if (finished_ && !loop_) return;
        
        elapsed_time_ += delta_time;
        double progress = std::min(elapsed_time_ / duration_, 1.0);
        
        update_func_(progress);
        
        if (progress >= 1.0) {
            if (loop_) {
                elapsed_time_ = 0.0;
            } else {
                finished_ = true;
            }
        }
    }
    
    bool is_finished() const { return finished_; }
    void reset() { elapsed_time_ = 0.0; finished_ = false; }
};

// AI-SUGGESTION: Graphics engine main class
class GraphicsRenderer {
private:
    std::unique_ptr<Scene> current_scene_;
    std::vector<Animation> animations_;
    std::chrono::high_resolution_clock::time_point last_frame_time_;
    double frame_rate_;
    int frame_count_;
    
public:
    GraphicsRenderer() : frame_rate_(0.0), frame_count_(0) {
        last_frame_time_ = std::chrono::high_resolution_clock::now();
    }
    
    void set_scene(std::unique_ptr<Scene> scene) {
        current_scene_ = std::move(scene);
    }
    
    void add_animation(Animation animation) {
        animations_.push_back(std::move(animation));
    }
    
    void update() {
        auto current_time = std::chrono::high_resolution_clock::now();
        auto delta = std::chrono::duration_cast<std::chrono::microseconds>(current_time - last_frame_time_);
        double delta_time = delta.count() / 1000000.0;
        last_frame_time_ = current_time;
        
        // AI-SUGGESTION: Update frame rate calculation
        frame_count_++;
        if (frame_count_ % 60 == 0) {
            frame_rate_ = 1.0 / delta_time;
        }
        
        if (current_scene_) {
            current_scene_->update(delta_time);
        }
        
        // AI-SUGGESTION: Update animations
        animations_.erase(
            std::remove_if(animations_.begin(), animations_.end(),
                [delta_time](Animation& anim) {
                    anim.update(delta_time);
                    return anim.is_finished();
                }),
            animations_.end()
        );
    }
    
    void render() {
        if (current_scene_) {
            current_scene_->render();
        }
    }
    
    std::string get_frame() const {
        if (current_scene_) {
            return current_scene_->get_ascii_frame();
        }
        return "";
    }
    
    double get_frame_rate() const { return frame_rate_; }
    
    // AI-SUGGESTION: Create demo scene
    std::unique_ptr<Scene> create_demo_scene() {
        auto scene = std::make_unique<Scene>("Demo Scene", 60, 30);
        
        // AI-SUGGESTION: Add bouncing circles
        for (int i = 0; i < 5; ++i) {
            auto circle = std::make_unique<CircleShape>(
                Point2D(10 + i * 10, 15), 
                3, 
                Color(255, 100 + i * 30, 100)
            );
            circle->set_velocity(Point2D(20 + i * 5, 15 - i * 3));
            scene->add_object(std::move(circle));
        }
        
        // AI-SUGGESTION: Add particle system
        auto particles = std::make_unique<ParticleSystem>(Point2D(30, 15), 30.0);
        scene->add_object(std::move(particles));
        
        // AI-SUGGESTION: Add moving rectangles
        auto rect = std::make_unique<RectangleShape>(
            Rectangle(Point2D(5, 5), 8, 4),
            Color::Blue()
        );
        rect->set_velocity(Point2D(10, 5));
        scene->add_object(std::move(rect));
        
        return scene;
    }
};

} // namespace GraphicsEngine

// AI-SUGGESTION: Demonstration functions
void demonstrateBasicGraphics() {
    using namespace GraphicsEngine;
    
    std::cout << "=== Basic Graphics Demo ===\n";
    
    Canvas canvas(40, 20);
    
    // AI-SUGGESTION: Draw basic shapes
    canvas.draw_line(Point2D(5, 5), Point2D(35, 15), Color::Red());
    canvas.draw_circle(Point2D(20, 10), 5, Color::Blue());
    canvas.draw_rectangle(Rectangle(Point2D(10, 5), 10, 8), Color::Green());
    
    std::cout << "Canvas with basic shapes:\n";
    std::cout << canvas.to_ascii() << "\n";
}

void demonstrateShapeObjects() {
    using namespace GraphicsEngine;
    
    std::cout << "=== Shape Objects Demo ===\n";
    
    Canvas canvas(30, 15);
    
    CircleShape circle(Point2D(15, 7), 4, Color::Red());
    RectangleShape rect(Rectangle(Point2D(5, 5), 6, 4), Color::Blue());
    
    circle.draw(canvas);
    rect.draw(canvas);
    
    std::cout << "Canvas with shape objects:\n";
    std::cout << canvas.to_ascii() << "\n";
    
    std::cout << "Circle bounds: (" << circle.get_bounds().position.x << ", " 
              << circle.get_bounds().position.y << ") " 
              << circle.get_bounds().width << "x" << circle.get_bounds().height << "\n";
}

void demonstrateParticleSystem() {
    using namespace GraphicsEngine;
    
    std::cout << "=== Particle System Demo ===\n";
    
    Canvas canvas(40, 20);
    ParticleSystem particles(Point2D(20, 10), 20.0);
    
    // AI-SUGGESTION: Simulate a few frames
    for (int frame = 0; frame < 5; ++frame) {
        canvas.clear();
        particles.update(0.1);
        particles.draw(canvas);
        
        std::cout << "Frame " << frame + 1 << " (Particles: " 
                  << particles.get_particle_count() << "):\n";
        std::cout << canvas.to_ascii() << "\n";
    }
}

void demonstrateAnimationSystem() {
    using namespace GraphicsEngine;
    
    std::cout << "=== Animation System Demo ===\n";
    
    GraphicsRenderer engine;
    auto scene = engine.create_demo_scene();
    engine.set_scene(std::move(scene));
    
    // AI-SUGGESTION: Create a simple animation
    auto moving_object = std::make_unique<CircleShape>(Point2D(10, 10), 2, Color::Green());
    auto* obj_ptr = moving_object.get();
    
    Scene temp_scene("Animation Demo", 50, 25);
    temp_scene.add_object(std::move(moving_object));
    
    Animation move_animation([obj_ptr](double progress) {
        double x = 10 + progress * 30; // Move from x=10 to x=40
        obj_ptr->set_center(Point2D(x, 10));
    }, 2.0, true);
    
    engine.add_animation(std::move(move_animation));
    
    std::cout << "Animation system created with moving circle\n";
    std::cout << "Frame rate: " << std::fixed << std::setprecision(1) 
              << engine.get_frame_rate() << " FPS\n";
}

void demonstrateFullScene() {
    using namespace GraphicsEngine;
    
    std::cout << "=== Full Scene Demo ===\n";
    
    GraphicsRenderer engine;
    auto scene = engine.create_demo_scene();
    
    std::cout << "Scene '" << scene->get_name() << "' created with " 
              << scene->get_object_count() << " objects\n";
    
    // AI-SUGGESTION: Query objects by type
    auto circles = scene->get_objects_of_type<CircleShape>();
    auto particle_systems = scene->get_objects_of_type<ParticleSystem>();
    
    std::cout << "Found " << circles.size() << " circles and " 
              << particle_systems.size() << " particle systems\n";
    
    engine.set_scene(std::move(scene));
    
    // AI-SUGGESTION: Run a few simulation steps
    for (int i = 0; i < 3; ++i) {
        engine.update();
        engine.render();
        
        std::cout << "\nFrame " << i + 1 << ":\n";
        std::cout << engine.get_frame() << "\n";
    }
}

int main() {
    std::cout << "2D Graphics Rendering Engine Demo\n";
    std::cout << "==================================\n\n";
    
    demonstrateBasicGraphics();
    demonstrateShapeObjects();
    demonstrateParticleSystem();
    demonstrateAnimationSystem();
    demonstrateFullScene();
    
    std::cout << "\n=== Graphics Engine Demo Complete ===\n";
    return 0;
} 