# Astro Contact Form


## Step by Step Setup

### Step 1: Create New Astro Project

```bash
# Create new Astro project
npm create astro@latest my-contact-form

# Navigate to project
cd my-contact-form

# Install dependencies
npm install
```

When prompted during setup:

- Choose “Empty” template
- Select “Yes” for TypeScript
- Choose your preferred options for the other prompts

### Step 2: Project Structure

Your project should look like this:

```
my-contact-form/
├── src/
│ ├── pages/
│ │ └── index.astro
│ └── layouts/
└── public/
```

### Step 3: Create Base Layout

Create `src/layouts/Layout.astro`:

```astro
---
export interface Props {
title: string;
}

const { title } = Astro.props;
---

<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>{title}</title>
<style>
body {
font-family: Arial, sans-serif;
max-width: 600px;
margin: 0 auto;
padding: 20px;
background-color: #f5f5f5;
}

.container {
background: white;
padding: 30px;
border-radius: 8px;
box-shadow: 0 2px 10px rgba(0,0,0,0.1);
}

h1 {
color: #333;
text-align: center;
margin-bottom: 30px;
}

.form-group {
margin-bottom: 20px;
}

label {
display: block;
margin-bottom: 5px;
font-weight: bold;
color: #555;
}

input, textarea {
width: 100%;
padding: 10px;
border: 2px solid #ddd;
border-radius: 4px;
font-size: 16px;
box-sizing: border-box;
}

input:focus, textarea:focus {
outline: none;
border-color: #4CAF50;
}

textarea {
height: 120px;
resize: vertical;
}

button {
background-color: #4CAF50;
color: white;
padding: 12px 24px;
border: none;
border-radius: 4px;
cursor: pointer;
font-size: 16px;
width: 100%;
}

button:hover {
background-color: #45a049;
}

.success {
background-color: #d4edda;
color: #155724;
padding: 15px;
border-radius: 4px;
margin-bottom: 20px;
border: 1px solid #c3e6cb;
}

.error {
background-color: #f8d7da;
color: #721c24;
padding: 15px;
border-radius: 4px;
margin-bottom: 20px;
border: 1px solid #f5c6cb;
}
</style>
</head>
<body>
<div class="container">
<slot />
</div>
</body>
</html>
```

### Step 4: Create Contact Form Page

Replace `src/pages/index.astro` with:

```astro
---
import Layout from '../layouts/Layout.astro';

let message = '';
let messageType = '';

if (Astro.request.method === 'POST') {
try {
const data = await Astro.request.formData();
const name = data.get('name');
const email = data.get('email');
const subject = data.get('subject');
const messageText = data.get('message');

// Basic validation
if (!name || !email || !messageText) {
message = 'Please fill in all required fields.';
messageType = 'error';
} else {
// Here you would typically send the email or save to database
// For this example, we'll just show a success message
console.log('Form submitted:', { name, email, subject, messageText });

message = 'Thank you for your message! We will get back to you soon.';
messageType = 'success';
}
} catch (error) {
message = 'There was an error processing your form. Please try again.';
messageType = 'error';
}
}
---

<Layout title="Contact Us">
<h1>Contact Us</h1>

{message && (
<div class={messageType}>
{message}
</div>
)}

<form method="POST">
<div class="form-group">
<label for="name">Name *</label>
<input 
type="text" 
id="name" 
name="name" 
required 
/>
</div>

<div class="form-group">
<label for="email">Email *</label>
<input 
type="email" 
id="email" 
name="email" 
required 
/>
</div>

<div class="form-group">
<label for="subject">Subject</label>
<input 
type="text" 
id="subject" 
name="subject" 
/>
</div>

<div class="form-group">
<label for="message">Message *</label>
<textarea 
id="message" 
name="message" 
placeholder="Your message here..."
required
></textarea>
</div>

<button type="submit">Send Message</button>
</form>
</Layout>
```

### Step 5: Run the Development Server

```bash
npm run dev
```

Visit `http://localhost:4321` to see your contact form in action!

### Step 6: Add Email Functionality (Optional)

To actually send emails, install a service like Nodemailer:

```bash
npm install nodemailer
npm install @types/nodemailer --save-dev
```

Then update your form processing code to send actual emails:

```astro
---
// Add to the top of index.astro
import nodemailer from 'nodemailer';

// ... existing code ...

if (Astro.request.method === 'POST') {
try {
const data = await Astro.request.formData();
// ... validation code ...

if (name && email && messageText) {
// Configure your email service
const transporter = nodemailer.createTransporter({
// Your email service configuration
service: 'gmail', // or your preferred service
auth: {
user: 'your-email@gmail.com',
pass: 'your-app-password'
}
});

await transporter.sendMail({
from: email,
to: 'your-email@gmail.com',
subject: `Contact Form: ${subject}`,
text: `From: ${name} (${email})\n\n${messageText}`
});

message = 'Thank you! Your message has been sent successfully.';
messageType = 'success';
}
} catch (error) {
// ... error handling ...
}
}
---
```

## Key Features of This Setup

- **Server-side form processing**: Forms work without JavaScript
- **Built-in validation**: Uses HTML5 validation + server-side checks
- **Progressive enhancement**: Fully functional even with JS disabled
- **Responsive design**: Works on all device sizes
- **No external dependencies**: Pure Astro with minimal setup

### Deployment

To deploy:

```bash
npm run build
```

The `dist/` folder contains your static site ready for deployment to any static hosting service like Netlify, Vercel, or GitHub Pages.
