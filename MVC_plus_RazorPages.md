# Can you help me build a CSharp program that works both with MVC Controller based views, and Rage Pages views? I would like to be updated to use .net6 and abve with just Program.cs file, and not Startup.cs file.

Sure, to build a C# program that works with both MVC Controller based views and Razor Pages views using .NET 6 and above (including just a Program.cs file without a Startup.cs file), you'll need to include the configuration and service setup that was traditionally in the Startup.cs file inside of your Program.cs.

Here's an example of how to set up your project:

1. Ensure you have the latest version of .NET by using the following command in terminal:

```bash
dotnet --version
```

Or download from here: https://dotnet.microsoft.com/download

2. Create a new Web Application that includes both MVC and Razor Pages:

```bash
dotnet new webapp -o MyWebApp
```

3. Open Program.cs file. With the new updates from .NET 6, this file will be your main entry point for everything including adding controllers, razor pages, and setting up middleware. Ensure you have a `ConfigureServices` and `Configure` method set up like this:

```csharp
var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

// For MVC
builder.Services.AddControllersWithViews(); 

// For Razor Pages 
builder.Services.AddRazorPages();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.MapRazorPages();

app.Run();
```

4. Now, you can add your MVC Controllers in the Controllers folder and Razor Pages in the Pages folder and it will work with both.

5. To test MVC, create HomeController in Controllers folder.

```csharp
public class HomeController : Controller
{
    public IActionResult Index()
    {
        return View();
    }
}
```

Similarly, to test Razor Pages, you can add `Index.cshtml` file inside the Pages folder with model class of `IndexModel`.

Detailed documentation on migrating from Startup.cs to Program.cs in .NET 6 can be found here: https://docs.microsoft.com/en-us/aspnet/core/fundamentals/minimal-apis?view=aspnetcore-6.0

Please note: If there are any compilation errors, you may need to ensure correct packages are installed and namespaces are included.
