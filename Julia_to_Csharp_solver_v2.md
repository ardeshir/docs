# Building a linear optimizer function with Julia

Calling Julia optimizer() from a C# application :

#### Step 1: Set Up Julia Environment
1. Install Julia: Download and install Julia from the official website.
2. Install Required Packages: Start Julia and install the necessary packages for optimization and for creating a shared library.

```julia 
using Pkg  
Pkg.add("JuMP")  
Pkg.add("GLPK")  
Pkg.add("PackageCompiler")  
``` 

#### Step 2: Write the Julia Linear Optimizer Function

Create a Julia script for your linear optimizer. Let's call this script linear_optimizer.jl.

```julia 
using JuMP  
using GLPK  
  
function solve_linear_problem(c::Vector{Float64}, A::Matrix{Float64}, b::Vector{Float64})  
    model = Model(GLPK.Optimizer)  
    @variable(model, x[1:length(c)] >= 0)  
    @objective(model, Min, dot(c, x))  
    @constraint(model, A * x .<= b)  
    optimize!(model)  
      
    if termination_status(model) == MOI.OPTIMAL  
        return value.(x)  
    else  
        error("Optimization did not succeed")  
    end  
end  
``` 

#### Step 3: Compile Julia Function to a Shared Library
- Use the PackageCompiler package to compile the Julia function to a shared library (.so for Linux, .dylib for macOS, or .dll for Windows).

- Create a file compile.jl to compile the function:

```julia 
using PackageCompiler  
  
create_library("LinearOptimizer", ["linear_optimizer.jl"]; lib_name="linear_optimizer")  
``` 
- Run this script from the Julia REPL:

```julia 
include("compile.jl")  
``` 
This will create a shared library file named linear_optimizer.dll (or .so/.dylib depending on your operating system).

#### Step 4: Use the Shared Library in C#
Now, create a C# application that calls the Julia shared library.

1. Create a C# Project: Use your preferred IDE (like Visual Studio) to create a new C# Console Application.
2. Add DllImport: Use the DllImport attribute to import the function from the shared library.

```csharp
using System;  
using System.Runtime.InteropServices;  
  
class Program  
{  
    [DllImport("linear_optimizer.dll", CallingConvention = CallingConvention.Cdecl)]  
    public static extern IntPtr solve_linear_problem(double[] c, int c_len, double[,] A, int A_rows, int A_cols, double[] b, int b_len);  
  
    static void Main()  
    {  
        double[] c = { 1.0, 2.0 };  
        double[,] A = { { 1.0, 1.0 }, { 2.0, 0.5 } };  
        double[] b = { 1.5, 1.0 };  
          
        IntPtr resultPtr = solve_linear_problem(c, c.Length, A, A.GetLength(0), A.GetLength(1), b, b.Length);  
        double[] result = new double[c.Length];  
        Marshal.Copy(resultPtr, result, 0, c.Length);  
          
        Console.WriteLine("Optimal solution:");  
        foreach (var x in result)  
        {  
            Console.WriteLine(x);  
        }  
    }  
}  
``` 

#### Step 5: Build and Run the C# Application
1. Ensure the Shared Library is Accessible: Copy the linear_optimizer.dll to the output directory of your C# project.
2. Build and Run: Build and run your C# application to see the results. 

#### The .NET CLI is a powerful tool for building and running .NET applications from the command line. Here are the steps to build and run the C# application using the .NET CLI:

- Prerequisites
- Ensure you have the .NET SDK installed on your machine. You can download it from the .NET download page.

#### Step 1: Create a New .NET Project
Open your terminal or command prompt and navigate to the directory where you want to create your project. Then, run the following command to create a new console application:

```bash
dotnet new console -n LinearOptimizerApp  
```

- This will create a new directory called LinearOptimizerApp with a basic console application inside.

##### Step 2: Navigate to the Project Directory
Change your directory to the newly created project directory:

```bash
cd LinearOptimizerApp  
``` 

#### Step 3: Copy the Shared Library
Copy your linear_optimizer.dll (or the appropriate shared library for your OS) to the LinearOptimizerApp directory.

- Optionally, you can create a directory within your project to keep things organized:

```bash
mkdir lib  
cp /path/to/linear_optimizer.dll lib/  
``` 

#### Step 4: Modify the C# Code
Open the Program.cs file in your favorite text editor and replace its contents with the following code:

```csharp 
using System;  
using System.Runtime.InteropServices;  
  
class Program  
{  
    // Import the solve_linear_problem function from the DLL  
    [DllImport("lib/linear_optimizer.dll", CallingConvention = CallingConvention.Cdecl)]  
    public static extern IntPtr solve_linear_problem(double[] c, int c_len, double[,] A, int A_rows, int A_cols, double[] b, int b_len);  
  
    // Import a function to free the memory allocated in Julia (if you have implemented one)  
    [DllImport("lib/linear_optimizer.dll", CallingConvention = CallingConvention.Cdecl)]  
    public static extern void free_result(IntPtr ptr);  
  
    static void Main()  
    {  
        // Define the coefficients for the linear problem  
        double[] c = { 1.0, 2.0 };  
        double[,] A = { { 1.0, 1.0 }, { 2.0, 0.5 } };  
        double[] b = { 1.5, 1.0 };  
  
        // Call the Julia function  
        IntPtr resultPtr = solve_linear_problem(c, c.Length, A, A.GetLength(0), A.GetLength(1), b, b.Length);  
  
        // Check if the resultPtr is not null  
        if (resultPtr == IntPtr.Zero)  
        {  
            Console.WriteLine("Optimization failed.");  
            return;  
        }  
  
        // Allocate memory for the result  
        double[] result = new double[c.Length];  
        Marshal.Copy(resultPtr, result, 0, c.Length);  
  
        // Print the optimal solution  
        Console.WriteLine("Optimal solution:");  
        foreach (var x in result)  
        {  
            Console.WriteLine(x);  
        }  
  
        // Free the allocated memory  
        free_result(resultPtr);  
    }  
}  
``` 

#### Step 5: Build the Project
Run the following command to build your project:


` dotnet build `  
 
- This will compile your C# code and generate the necessary binaries.

- Run the following command to execute your application:


` dotnet run  `
 
You should see the output of the linear optimization process printed to the console.

#### Additional Notes
1. Path Adjustments: Ensure the path to linear_optimizer.dll in the [DllImport] attribute is correct. If you placed the DLL in a different directory, adjust the path accordingly.
2. Platform-Specific Libraries


### References

- [Julia documentation on calling C from Julia](https://docs.julialang.org/en/v1/manual/calling-c-and-fortran-code/)
- [P/Invoke documentation](https://docs.microsoft.com/en-us/dotnet/standard/native-interop/pinvoke)