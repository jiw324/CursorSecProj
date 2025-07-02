// AI-Generated Code Header
// **Intent:** Comprehensive C++ class library demonstrating OOP principles
// **Optimization:** RAII, smart pointers, and efficient memory management
// **Safety:** Exception handling, const correctness, and resource management

#include <iostream>
#include <vector>
#include <memory>
#include <string>
#include <sstream>
#include <algorithm>
#include <stdexcept>
#include <iomanip>

namespace GeometryLib {

// AI-SUGGESTION: Abstract base class for all geometric shapes
class Shape {
protected:
    std::string name_;
    double x_, y_; // Position coordinates
    
public:
    Shape(const std::string& name, double x = 0.0, double y = 0.0)
        : name_(name), x_(x), y_(y) {}
    
    virtual ~Shape() = default;
    
    // AI-SUGGESTION: Pure virtual functions for polymorphism
    virtual double area() const = 0;
    virtual double perimeter() const = 0;
    virtual void draw() const = 0;
    virtual std::unique_ptr<Shape> clone() const = 0;
    
    // AI-SUGGESTION: Common interface methods
    virtual void move(double dx, double dy) {
        x_ += dx;
        y_ += dy;
        std::cout << name_ << " moved by (" << dx << ", " << dy << ")\n";
    }
    
    virtual void setPosition(double x, double y) {
        x_ = x;
        y_ = y;
        std::cout << name_ << " positioned at (" << x << ", " << y << ")\n";
    }
    
    // AI-SUGGESTION: Getter methods
    std::string getName() const { return name_; }
    double getX() const { return x_; }
    double getY() const { return y_; }
    
    // AI-SUGGESTION: Virtual method for detailed information
    virtual std::string getInfo() const {
        std::ostringstream oss;
        oss << std::fixed << std::setprecision(2)
            << name_ << " at (" << x_ << ", " << y_ << ")"
            << " - Area: " << area() << ", Perimeter: " << perimeter();
        return oss.str();
    }
};

// AI-SUGGESTION: Circle class implementation
class Circle : public Shape {
private:
    double radius_;
    
public:
    Circle(double radius, double x = 0.0, double y = 0.0)
        : Shape("Circle", x, y), radius_(radius) {
        if (radius <= 0) {
            throw std::invalid_argument("Circle radius must be positive");
        }
    }
    
    double area() const override {
        return M_PI * radius_ * radius_;
    }
    
    double perimeter() const override {
        return 2 * M_PI * radius_;
    }
    
    void draw() const override {
        std::cout << "Drawing circle with radius " << radius_ 
                  << " at (" << x_ << ", " << y_ << ")\n";
    }
    
    std::unique_ptr<Shape> clone() const override {
        return std::make_unique<Circle>(radius_, x_, y_);
    }
    
    // AI-SUGGESTION: Circle-specific methods
    double getRadius() const { return radius_; }
    void setRadius(double radius) {
        if (radius <= 0) {
            throw std::invalid_argument("Circle radius must be positive");
        }
        radius_ = radius;
    }
    
    double getDiameter() const { return 2 * radius_; }
};

// AI-SUGGESTION: Rectangle class implementation
class Rectangle : public Shape {
private:
    double width_, height_;
    
public:
    Rectangle(double width, double height, double x = 0.0, double y = 0.0)
        : Shape("Rectangle", x, y), width_(width), height_(height) {
        if (width <= 0 || height <= 0) {
            throw std::invalid_argument("Rectangle dimensions must be positive");
        }
    }
    
    double area() const override {
        return width_ * height_;
    }
    
    double perimeter() const override {
        return 2 * (width_ + height_);
    }
    
    void draw() const override {
        std::cout << "Drawing rectangle " << width_ << "x" << height_ 
                  << " at (" << x_ << ", " << y_ << ")\n";
    }
    
    std::unique_ptr<Shape> clone() const override {
        return std::make_unique<Rectangle>(width_, height_, x_, y_);
    }
    
    // AI-SUGGESTION: Rectangle-specific methods
    double getWidth() const { return width_; }
    double getHeight() const { return height_; }
    
    void setDimensions(double width, double height) {
        if (width <= 0 || height <= 0) {
            throw std::invalid_argument("Rectangle dimensions must be positive");
        }
        width_ = width;
        height_ = height;
    }
    
    bool isSquare() const {
        return std::abs(width_ - height_) < 1e-9;
    }
};

// AI-SUGGESTION: Triangle class implementation
class Triangle : public Shape {
private:
    double side1_, side2_, side3_;
    
    bool isValidTriangle(double a, double b, double c) const {
        return (a + b > c) && (a + c > b) && (b + c > a);
    }
    
public:
    Triangle(double side1, double side2, double side3, double x = 0.0, double y = 0.0)
        : Shape("Triangle", x, y), side1_(side1), side2_(side2), side3_(side3) {
        if (side1 <= 0 || side2 <= 0 || side3 <= 0) {
            throw std::invalid_argument("Triangle sides must be positive");
        }
        if (!isValidTriangle(side1, side2, side3)) {
            throw std::invalid_argument("Invalid triangle: sides don't satisfy triangle inequality");
        }
    }
    
    double area() const override {
        // AI-SUGGESTION: Using Heron's formula
        double s = perimeter() / 2.0;
        return std::sqrt(s * (s - side1_) * (s - side2_) * (s - side3_));
    }
    
    double perimeter() const override {
        return side1_ + side2_ + side3_;
    }
    
    void draw() const override {
        std::cout << "Drawing triangle with sides (" << side1_ << ", " 
                  << side2_ << ", " << side3_ << ") at (" << x_ << ", " << y_ << ")\n";
    }
    
    std::unique_ptr<Shape> clone() const override {
        return std::make_unique<Triangle>(side1_, side2_, side3_, x_, y_);
    }
    
    // AI-SUGGESTION: Triangle-specific methods
    bool isEquilateral() const {
        return std::abs(side1_ - side2_) < 1e-9 && std::abs(side2_ - side3_) < 1e-9;
    }
    
    bool isIsosceles() const {
        return std::abs(side1_ - side2_) < 1e-9 || 
               std::abs(side2_ - side3_) < 1e-9 || 
               std::abs(side1_ - side3_) < 1e-9;
    }
    
    bool isRight() const {
        std::vector<double> sides = {side1_, side2_, side3_};
        std::sort(sides.begin(), sides.end());
        return std::abs(sides[0]*sides[0] + sides[1]*sides[1] - sides[2]*sides[2]) < 1e-9;
    }
};

// AI-SUGGESTION: Composite pattern - Group of shapes
class ShapeGroup {
private:
    std::vector<std::unique_ptr<Shape>> shapes_;
    std::string groupName_;
    
public:
    explicit ShapeGroup(const std::string& name) : groupName_(name) {}
    
    // AI-SUGGESTION: Move constructor and assignment
    ShapeGroup(ShapeGroup&& other) noexcept 
        : shapes_(std::move(other.shapes_)), groupName_(std::move(other.groupName_)) {}
    
    ShapeGroup& operator=(ShapeGroup&& other) noexcept {
        if (this != &other) {
            shapes_ = std::move(other.shapes_);
            groupName_ = std::move(other.groupName_);
        }
        return *this;
    }
    
    // AI-SUGGESTION: Disable copy operations (use clone instead)
    ShapeGroup(const ShapeGroup&) = delete;
    ShapeGroup& operator=(const ShapeGroup&) = delete;
    
    void addShape(std::unique_ptr<Shape> shape) {
        if (shape) {
            shapes_.push_back(std::move(shape));
            std::cout << "Added " << shapes_.back()->getName() << " to group " << groupName_ << "\n";
        }
    }
    
    void removeShape(size_t index) {
        if (index < shapes_.size()) {
            std::cout << "Removed " << shapes_[index]->getName() << " from group " << groupName_ << "\n";
            shapes_.erase(shapes_.begin() + index);
        }
    }
    
    double getTotalArea() const {
        double total = 0.0;
        for (const auto& shape : shapes_) {
            total += shape->area();
        }
        return total;
    }
    
    double getTotalPerimeter() const {
        double total = 0.0;
        for (const auto& shape : shapes_) {
            total += shape->perimeter();
        }
        return total;
    }
    
    void drawAll() const {
        std::cout << "\n=== Drawing Group: " << groupName_ << " ===\n";
        for (const auto& shape : shapes_) {
            shape->draw();
        }
        std::cout << "=== End of Group ===\n\n";
    }
    
    void moveAll(double dx, double dy) {
        std::cout << "Moving all shapes in group " << groupName_ << " by (" << dx << ", " << dy << ")\n";
        for (auto& shape : shapes_) {
            shape->move(dx, dy);
        }
    }
    
    void printStatistics() const {
        std::cout << "\n=== Group Statistics: " << groupName_ << " ===\n";
        std::cout << "Number of shapes: " << shapes_.size() << "\n";
        std::cout << "Total area: " << std::fixed << std::setprecision(2) << getTotalArea() << "\n";
        std::cout << "Total perimeter: " << getTotalPerimeter() << "\n";
        
        // AI-SUGGESTION: Count shapes by type
        int circles = 0, rectangles = 0, triangles = 0;
        for (const auto& shape : shapes_) {
            if (dynamic_cast<const Circle*>(shape.get())) circles++;
            else if (dynamic_cast<const Rectangle*>(shape.get())) rectangles++;
            else if (dynamic_cast<const Triangle*>(shape.get())) triangles++;
        }
        
        std::cout << "Shape distribution: " << circles << " circles, " 
                  << rectangles << " rectangles, " << triangles << " triangles\n";
        std::cout << "=== End Statistics ===\n\n";
    }
    
    // AI-SUGGESTION: Find shapes by criteria
    std::vector<Shape*> findShapesByMinArea(double minArea) const {
        std::vector<Shape*> result;
        for (const auto& shape : shapes_) {
            if (shape->area() >= minArea) {
                result.push_back(shape.get());
            }
        }
        return result;
    }
    
    Shape* findLargestShape() const {
        if (shapes_.empty()) return nullptr;
        
        auto maxIt = std::max_element(shapes_.begin(), shapes_.end(),
            [](const auto& a, const auto& b) {
                return a->area() < b->area();
            });
        
        return maxIt->get();
    }
    
    // AI-SUGGESTION: Clone entire group
    std::unique_ptr<ShapeGroup> clone() const {
        auto newGroup = std::make_unique<ShapeGroup>(groupName_ + "_copy");
        for (const auto& shape : shapes_) {
            newGroup->addShape(shape->clone());
        }
        return newGroup;
    }
    
    size_t size() const { return shapes_.size(); }
    bool empty() const { return shapes_.empty(); }
    const std::string& getName() const { return groupName_; }
};

// AI-SUGGESTION: Factory pattern for shape creation
class ShapeFactory {
public:
    enum class ShapeType { CIRCLE, RECTANGLE, TRIANGLE };
    
    static std::unique_ptr<Shape> createShape(ShapeType type, 
                                            const std::vector<double>& params, 
                                            double x = 0.0, double y = 0.0) {
        try {
            switch (type) {
                case ShapeType::CIRCLE:
                    if (params.size() != 1) {
                        throw std::invalid_argument("Circle requires 1 parameter (radius)");
                    }
                    return std::make_unique<Circle>(params[0], x, y);
                    
                case ShapeType::RECTANGLE:
                    if (params.size() != 2) {
                        throw std::invalid_argument("Rectangle requires 2 parameters (width, height)");
                    }
                    return std::make_unique<Rectangle>(params[0], params[1], x, y);
                    
                case ShapeType::TRIANGLE:
                    if (params.size() != 3) {
                        throw std::invalid_argument("Triangle requires 3 parameters (side1, side2, side3)");
                    }
                    return std::make_unique<Triangle>(params[0], params[1], params[2], x, y);
                    
                default:
                    throw std::invalid_argument("Unknown shape type");
            }
        } catch (const std::exception& e) {
            std::cout << "Error creating shape: " << e.what() << "\n";
            return nullptr;
        }
    }
    
    // AI-SUGGESTION: Convenience methods
    static std::unique_ptr<Shape> createCircle(double radius, double x = 0.0, double y = 0.0) {
        return createShape(ShapeType::CIRCLE, {radius}, x, y);
    }
    
    static std::unique_ptr<Shape> createRectangle(double width, double height, double x = 0.0, double y = 0.0) {
        return createShape(ShapeType::RECTANGLE, {width, height}, x, y);
    }
    
    static std::unique_ptr<Shape> createSquare(double side, double x = 0.0, double y = 0.0) {
        return createShape(ShapeType::RECTANGLE, {side, side}, x, y);
    }
    
    static std::unique_ptr<Shape> createTriangle(double side1, double side2, double side3, double x = 0.0, double y = 0.0) {
        return createShape(ShapeType::TRIANGLE, {side1, side2, side3}, x, y);
    }
};

} // namespace GeometryLib

// AI-SUGGESTION: Demo function
void demonstrateGeometryLibrary() {
    using namespace GeometryLib;
    
    std::cout << "=== Geometry Library Demonstration ===\n\n";
    
    try {
        // AI-SUGGESTION: Create individual shapes
        auto circle = ShapeFactory::createCircle(5.0, 10.0, 20.0);
        auto rectangle = ShapeFactory::createRectangle(4.0, 6.0, 5.0, 5.0);
        auto triangle = ShapeFactory::createTriangle(3.0, 4.0, 5.0, 0.0, 0.0);
        auto square = ShapeFactory::createSquare(4.0, 15.0, 15.0);
        
        // AI-SUGGESTION: Create shape group
        ShapeGroup myShapes("MyGeometryCollection");
        myShapes.addShape(std::move(circle));
        myShapes.addShape(std::move(rectangle));
        myShapes.addShape(std::move(triangle));
        myShapes.addShape(std::move(square));
        
        // AI-SUGGESTION: Demonstrate operations
        myShapes.drawAll();
        myShapes.printStatistics();
        
        // AI-SUGGESTION: Find largest shape
        auto* largest = myShapes.findLargestShape();
        if (largest) {
            std::cout << "Largest shape: " << largest->getInfo() << "\n\n";
        }
        
        // AI-SUGGESTION: Move all shapes
        myShapes.moveAll(2.0, 3.0);
        
        // AI-SUGGESTION: Find shapes with minimum area
        auto largeShapes = myShapes.findShapesByMinArea(15.0);
        std::cout << "Shapes with area >= 15.0: " << largeShapes.size() << " found\n";
        for (const auto* shape : largeShapes) {
            std::cout << "  - " << shape->getInfo() << "\n";
        }
        
        // AI-SUGGESTION: Clone the group
        auto clonedGroup = myShapes.clone();
        std::cout << "\nCloned group '" << clonedGroup->getName() << "' with " 
                  << clonedGroup->size() << " shapes\n";
        
        // AI-SUGGESTION: Test triangle properties
        auto rightTriangle = ShapeFactory::createTriangle(3.0, 4.0, 5.0);
        if (auto* tri = dynamic_cast<Triangle*>(rightTriangle.get())) {
            std::cout << "\nTriangle properties:\n";
            std::cout << "Is right triangle: " << (tri->isRight() ? "Yes" : "No") << "\n";
            std::cout << "Is isosceles: " << (tri->isIsosceles() ? "Yes" : "No") << "\n";
            std::cout << "Is equilateral: " << (tri->isEquilateral() ? "Yes" : "No") << "\n";
        }
        
    } catch (const std::exception& e) {
        std::cout << "Exception occurred: " << e.what() << "\n";
    }
    
    std::cout << "\n=== Demonstration Complete ===\n";
}

int main() {
    std::cout << "C++ Object-Oriented Programming Demo\n";
    std::cout << "====================================\n\n";
    
    demonstrateGeometryLibrary();
    
    return 0;
} 