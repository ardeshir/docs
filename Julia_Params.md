## How does Julia pass arguments in functions()

In Julia, the parameter passing mechanism is somewhat nuanced. It commonly follows the "pass-by-sharing" model, which means that:

1. **Immutable objects** (e.g., integers, floats, strings) are effectively passed by value because their state cannot be altered. Any change to a function argument inside the function will not affect the original variable.
2. **Mutable objects** (e.g., arrays, dictionaries) are passed by reference, and changes to these objects within the function will affect the original object outside the function.

Hence, for mutable objects, sharing is enabled with the caller.

Here's an illustration:

```julia
# Immutable example
x = 10

function foo(y)
    y = y + 5
end

foo(x)
println(x)  # Output: 10

# Mutable example
arr = [1, 2, 3]

function bar(lst)
    append!(lst, 4)
end

bar(arr)
println(arr)  # Output: [1, 2, 3, 4]
```

In the `foo` example, the integer `x` remains unchanged because integers (immutable) are passed by value-like semantics. In the `bar` example, the array `arr` is modified because arrays (mutable) are passed by reference-like semantics.

### Creating Static Copies

If you want to ensure that a function works with a copy of an object (thus simulating "pass-by-value" for mutable objects), you can create a copy of the object when passing it to the function. Use functions like `copy()` or `deepcopy()` in Julia to achieve this:

- `copy()` performs a shallow copy.
- `deepcopy()` performs a deep copy.

Here's an example:

```julia
arr = [1, 2, 3]

function qux(lst)
    lst_copy = copy(lst)
    append!(lst_copy, 4)
    return lst_copy
end

new_arr = qux(arr)
println(arr)     # Output: [1, 2, 3]  (original array remains unchanged)
println(new_arr) # Output: [1, 2, 3, 4]  (copied and modified array)
```

In this code, `qux` makes a shallow copy of `arr` and modifies the copy, leaving the original array unchanged.

### Relevant Resources
- [Julia Documentation on Functions](https://docs.julialang.org/en/v1/manual/functions/)
- [Julia Documentation on Working with Arrays](https://docs.julialang.org/en/v1/manual/arrays/)
- [Julia Documentation on Copying and Deep Copying](https://docs.julialang.org/en/v1/base/collections/#copy)

By understanding the difference and the behavior of mutable and immutable objects in Julia, you can effectively control whether a function argument should reflect changes outside the function or not.
