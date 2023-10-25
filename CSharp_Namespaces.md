##### Q: what's the best way to organize the CSharp Namespaces and folders in a project, without Visual Studio, but using dotnet cli?

A: Organizing Namespaces and folders in a C# project is opinionated and can be done in many ways depending on the size, nature, and complexity of the project. However, the commonly accepted way is to match your Namespaces to the folder structure, and using a logical and structured approach to group common and related classes together.

To organize your project without Visual Studio but using the dotnet CLI, consider the following steps:

1. ***Create Solution File:*** Use the `dotnet new sln -n MySolution` command to create a solution file. Substitute "MySolution" with your desired solution name.
   
2. ***Create Project(s):*** For each project you want to add to the solution, use `dotnet new classlib -n MyProject`. Substitute "MyProject" with your desired project name. This will create a class library. If you want another project type (like a console app), replace "classlib" with the type you want.

3. ***Add Project(s) to solution:*** Use `dotnet sln add MyProject` to add each project to the solution.

4. ***Create Folders:*** Inside each project, create a folder structure that makes sense for your application's organization. For instance, you may have folders like "Models", "Controllers", "Services", etc.

5. ***Add Classes:*** Inside each of these folders, add classes as needed. You can create new classes with `dotnet new class -n MyClass`. You can move the created class into a desired folder manually.

6. ***Namespace naming:*** Generally, the namespace of these classes should correspond to the folder structure. So if you had a "Models" folder and a "User.cs" class inside this folder, the namespace would be `MyProject.Models`.

This naming and organizational strategy makes it straightforward to find the code files corresponding with certain classes or components in your codebase.

Resources for further details:
1. Dotnet CLI documentation: https://docs.microsoft.com/en-us/dotnet/core/tools/
2. Namespace Naming Guidelines: https://docs.microsoft.com/en-us/dotnet/standard/design-guidelines/names-of-namespaces
3. Organizing and testing projects with the .NET Core command line: https://andrewlock.net/organising-and-testing-projects-with-the-net-core-command-line/
