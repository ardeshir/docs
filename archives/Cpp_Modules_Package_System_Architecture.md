#### C++20's Module package system and architecture

C++20 introduces a new feature called Modules which aims to provide a better partitioning unit than headers for C++ programs. 

Modules in C++20 make compilation less dependent on the textual inclusion mechanism and improves robustness, scalability, and efficiency of building programs. They provide a type-safe boundary across which code can be imported, improving the encapsulation and interfaces between different parts of a program. It keeps each module in a separated scope, so name clashes are reduced.

The basic C++20 module system architecture contains import declarations, export declarations, module partitions, named modules, and module linkage.

1. Import declaration `import`: This instructs the compiler to include code from another module, similar to what headers did previously but in a more secure way without any name clashing problems or slow compilation times.

2. Export declaration `export`: This keyword makes available parts of a module to other modules. Without this keyword, an entity in a module is only available to that module.

3. Module Partitions: These are parts of a module that can be separately compiled. They are only visible to the module they belong to and not accessible directly by other modules unless exported.

4. Named Modules: These are the most basic form of a module. They are defined in an implementation file, rather than a header, which is declared using a new keyword `module`.

5. Module Linkage: This is introduced to manage the linkage within modules. Anything that is declared or defined within a module interface partition has module linkage unless otherwise specified.

Unfortunately, as of this writing, not all compiler vendors fully support C++20 modules. You'll need to check the documentation of your favorite compiler for this feature.

For more detailed information and examples on C++20 Modules, you could refer to the following resources:

- C++ documentation: (https://en.cppreference.com/w/cpp/language/modules)
- "A Tour of C++ Modules in Visual Studio" by Will Buik: (https://devblogs.microsoft.com/cppblog/a-tour-of-cpp-modules-in-visual-studio/)
- "Modules in C++20" by Bartłomiej Filipek: (https://www.modernescpp.com/index.php/c-20-modules)
