# Modern C++ Patterns 

Modern C++ utilizes features introduced in C++11 and later versions (C++14, C++17, C++20, etc.) to write cleaner, more efficient, and more maintainable code. Here are some best practices and examples to follow for Modern C++:

### 1. Use the `auto` Keyword
With `auto`, the compiler deduces the type of the variable, making code simpler and reducing redundancy.
```cpp
auto x = 10;   // x is deduced to be int
auto y = 5.0;  // y is deduced to be double
```

### 2. Prefer `nullptr` to `NULL`
`nullptr` is a type-safe null pointer introduced in C++11.
```cpp
int* ptr = nullptr;
```

### 3. Use Range-Based for Loops
Range-based for loops simplify iteration over containers.
```cpp
std::vector<int> vec = {1, 2, 3, 4, 5};
for (const auto& elem : vec) {
    std::cout << elem << " ";
}
```

### 4. Use Smart Pointers
Smart pointers handle automatic memory management and help avoid memory leaks.
```cpp
#include <memory>
std::unique_ptr<int> p1(new int(5));         // unique_ptr
std::shared_ptr<int> p2 = std::make_shared<int>(10); // shared_ptr
```

### 5. Prefer `std::thread` and High-Level Concurrency
For creating threads, `std::thread` provides a clearer and safer API.
```cpp
#include <thread>
void threadFunction() {
    // Do some work
}
std::thread t(threadFunction);
t.join();  // Wait for the thread to finish
```

### 6. Use `constexpr` for Compile-Time Constants
`constexpr` can be used to perform computations at compile time.
```cpp
constexpr int square(int x) {
    return x * x;
}
int area = square(5);  // Computed at compile time
```

### 7. Make Use of `enum class` Over Traditional `enum`
`enum class` offers better type safety.
```cpp
enum class Color { Red, Green, Blue };
Color c = Color::Red;
```

### 8. Use `==` and `!=` for Comparison Operations
Leverage default comparison operators where `==` and `!=` can be synthesized by the compiler in newer C++ versions.
```cpp
struct Point {
  int x, y;
  auto operator<=>(const Point&) const = default; // Adds all comparison operators
};
```

### 9. Prefer `std::array` Over Built-In Arrays
`std::array` provides the benefits of a statically-sized array with improved safety and functionality.
```cpp
#include <array>
std::array<int, 5> nums = {1, 2, 3, 4, 5};
```

### 10. Use `std::optional` for Nullable Return Types
`std::optional` represents optional values that may or may not exist.
```cpp
#include <optional>
std::optional<int> getValue(bool condition) {
    if (condition) return 42;
    else return std::nullopt;
}
```

### Resources for Learning Modern C++:

1. **Books:**
   - *"Effective Modern C++"* by Scott Meyers
   - *"C++ Primer (5th Edition)"* by Stanley B. Lippman, Josée Lajoie, and Barbara E. Moo

2. **Online Courses:**
   - [C++ Nanodegree Program](https://www.udacity.com/course/c-plus-plus-nanodegree--nd213) by Udacity
   - [C++ Fundamentals](https://www.pluralsight.com/courses/cplusplus-fundamentals) by Pluralsight

3. **Online Documentation and Tutorials:**
   - [cppreference.com](https://cppreference.com/): A comprehensive online resource for C++ standard library documentation.
   - [cplusplus.com](http://www.cplusplus.com/): Another widely-used resource for C++ documentation and tutorials.

4. **Video Tutorials:**
   - [C++ Programming Playlist](https://www.youtube.com/playlist?list=PLAE85DE8440AA6B83) by The Cherno
   - [C++ Weekly](https://www.youtube.com/user/lefticus1): Weekly video series on Modern C++ features and best practices.

By adhering to these best practices and using the suggested resources, you can significantly improve your proficiency in Modern C++.

