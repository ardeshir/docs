Sure, here's a simple function in Python that writes a string to a file named "text.md". 

```python
def write_to_file(content):
    with open('text.md', 'w') as file:
        file.write(content)
```

You can use this function like this:

```python
write_to_file("Hello, World!")
```

This will create a file named "text.md" in the same directory as your python script, and write "Hello, World!" into it. If the file already exists, this function will overwrite the existing content.

If you want to append the content to the existing file instead of overwriting it, you can use 'a' instead of 'w' in the open function:

```python
def append_to_file(content):
    with open('text.md', 'a') as file:
        file.write(content)
```

Here's how you can use this function:

```python
append_to_file("\nThis is a new line.")
```

This will add "This is a new line." to the next line of the file, keeping the existing content intact.