## Helper Function 
Sure, here is a simple Python function that does exactly that. This function will open the file in 'write' mode, which will overwrite any existing content in the file. If you would like to append to an existing file instead, you can use 'append' mode by replacing 'w' with 'a' in the open() function.

```python
def write_to_file(content):
    with open('text.md', 'w') as f:
        f.write(content)

# Use the function
write_to_file('This is some text.')
```

This function takes a string argument 'content' and writes it to a file named 'text.md' in the same directory. The 'with' keyword is used here to handle the file. This is a good practice as it automatically closes the file after it is no longer needed.

Remember that this function will overwrite the file 'text.md' every time it is called. If you want to add text to the existing file, you should open the file in 'append' mode by replacing 'w' with 'a' in the open() function.
