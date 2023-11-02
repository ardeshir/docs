##### Q: I would like to understand the CSharp 10 inheritance use between to POCO with methods? Give examples of OO programming inheritance technique and how to use methods from two inherited Objects?

A: In C#, inheritance is a fundamental concept of object-oriented programming (OOP) that allows a class to inherit properties and behavior from a base class. In the context of Plain Old CLR Objects (POCO), you can use inheritance to define a relationship between two classes and reuse methods defined in the base class.

Here's an example to illustrate inheritance and using methods from two inherited objects:

```csharp
public class Animal
{
    public void Eat()
    {
        Console.WriteLine("Animal is eating.");
    }
}

public class Dog : Animal
{
    public void Bark()
    {
        Console.WriteLine("Dog is barking.");
    }
}

public class Cat : Animal
{
    public void Meow()
    {
        Console.WriteLine("Cat is meowing.");
    }
}

class Program
{
    static void Main(string[] args)
    {
        Dog dog = new Dog();
        dog.Eat();  // Animal is eating.
        dog.Bark(); // Dog is barking.

        Cat cat = new Cat();
        cat.Eat();  // Animal is eating.
        cat.Meow(); // Cat is meowing.
    }
}
```

In the example above, the `Animal` class acts as the base class, and the `Dog` and `Cat` classes inherit from it using the `:` symbol.

The `Animal` class has a method called `Eat()`, which is accessible to both `Dog` and `Cat` classes because they inherit from `Animal`. Each subclass can also have its own methods (`Bark()` in `Dog` and `Meow()` in `Cat`).

To use methods from inherited objects, you simply create instances of the derived classes (`Dog` and `Cat`) and call their respective methods (`Eat()`, `Bark()`, and `Meow()`). The base class's method (`Eat()`) can also be accessed from the derived classes.

Keep in mind that C# 10 is not released as of now, so syntax or features might change from this example as future versions are introduced.

