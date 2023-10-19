######Q: What's the easiest and fastest way to take Web Page, HTML and Images and turn it into PDF file using free services or Open Source tooling? 

A: To convert HTML or web pages to PDF, you can use a variety of open source tools and libraries. Here are a few options:

Puppeteer: Puppeteer is a Node library which provides a high-level API to control Chrome or Chromium over the DevTools Protocol. Puppeteer runs headless by default but can be configured to run non-headless. You can generate a PDF of any web page that Puppeteer can browse.


Here is a simple example of how to use Puppeteer to generate a PDF from a webpage:

```javascript
const puppeteer = require('puppeteer');  

(async () => {  
  const browser = await puppeteer.launch();  
  const page = await browser.newPage();  
  await page.goto('http://example.com', {waitUntil: 'networkidle2'});  
  await page.pdf({path: 'example.pdf', format: 'A4'});  
  
  await browser.close();  
})();
```  
- Puppeteer Github Repo: https://github.com/puppeteer/puppeteer

- wkhtmltopdf: wkhtmltopdf is an open source command line tool to render HTML into PDF using the Qt WebKit rendering engine. It runs entirely "headless" and does not require a display or display service.

#####Here is a simple example of how to use wkhtmltopdf:

- wkhtmltopdf http://google.com google.pdf  
- wkhtmltopdf Github Repo: https://github.com/wkhtmltopdf/wkhtmltopdf
- WeasyPrint: WeasyPrint is a visual rendering engine for HTML and CSS that can export to PDF. It aims to support web standards for printing. It is based on various libraries but not on a full rendering engine like Blink, Gecko or WebKit. The CSS layout engine is written in Python, designed for pagination, and meant to be easy to hack on.


Here is a simple example of how to use WeasyPrint:

```python
from weasyprint import HTML  

HTML('http://weasyprint.org/').write_pdf('/tmp/weasyprint-website.pdf')  
WeasyPrint Github Repo: https://github.com/Kozea/WeasyPrint
```

Please note that for images, you can use libraries like ImageMagick or PIL/Pillow in Python to convert images to PDF. These tools are open source and can be easily used in your projects.

For ImageMagick, the command would look like this:
- convert image.jpg output.pdf  
 
For Pillow, the Python code would look like this:
```python
from PIL import Image  
  
image1 = Image.open(r'pathwhere the image is stored\image name.file extension')  
im1 = image1.convert('RGB')  
im1.save(r'path where the pdf will be stored\new file name.pdf')  
```
 
- Again, please be aware of the limitations and legal implications of scraping and generating PDFs from web pages. Always respect copyright and terms of service.


