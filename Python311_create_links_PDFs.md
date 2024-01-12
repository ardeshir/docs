#### Python script does the same job as the previous programs: it scans the "./data" directory for PDF files, sorts them in alphabetical order, generates an HTML file with links to each PDF file, and writes the HTML content to the "index.html" file.

The glob.glob function is used to find all PDF files in the directory. The os.path.basename and os.path.splitext functions are used to get the file name without the directory path and to remove the extension, respectively.

The sorted function is used to sort the filenames in alphabetical order. Then, the script opens the output file with open and writes the HTML content to it.

Please note that this code uses Python's f-string formatting (introduced in Python 3.6), which is a very readable way to include expressions inside string literals. If you're using an older version of Python, you'll need to use the format method of strings instead.

```python
import os
import glob

# directory path
dir_path = './data'

# output file path
output_path = './index.html'

# check if directory exists
if not os.path.isdir(dir_path):
    print(f"Directory '{dir_path}' does not exist.")
else:
    # get pdf files
    pdf_files = sorted(glob.glob(os.path.join(dir_path, '*.pdf')))

    with open(output_path, 'w') as file:
        file.write('<html><title> PDF files</title>\n')
        file.write('<body>\n')
        file.write('<h1>List of ebooks</h1>\n')
        file.write('<ul>\n')

        # create a list item for each pdf file
        for pdf_file in pdf_files:
            file_name = os.path.basename(pdf_file)
            link_text = os.path.splitext(file_name)[0].replace('_', ' ')  # Replace underscores with spaces
            file.write(f'<li><a href="{file_name}">{link_text}</a></li>\n')

        file.write('</ul>\n')
        file.write('</body>\n')
        file.write('</html>\n')

    print("index.html has been created.")


```
