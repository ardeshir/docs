# Docker Compose Services in React

When running a React client and a Node.js server in the same Docker container (which is not a very common practice, but let's proceed with it for the sake of this example), the services still need to communicate efficiently. However, typically in Docker, you would have multiple services in separate containers and manage them using Docker Compose.

#### Here's how to handle the situation:

1. **Base URL for HTTP Calls When Running in the Same Container:**

If both the React app and the Node.js server are running in the same Docker container, you can use `localhost` for the server calls, as they share the same network space.

2. **Docker Compose Configuration:**

However, a better practice is to separate the services into different containers and use Docker Compose to define and link them. Below is an example `docker-compose.yml` for separating the services:

```yaml
version: '3.8'
services:
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    ports:
      - "3000:3000"
    depends_on:
      - backend

  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    ports:
      - "4000:4000"
```

3. **Base URL in React Application:**
With the Docker Compose setup, you would specify the backend service name defined in the Docker Compose file as the base URL in your React application. Update the `base_url` in your React app’s HTTP calls (during the development stage):

```javascript
// For example, use an environment variable
const baseURL = process.env.REACT_APP_API_URL || 'http://localhost:4000';
axios.get(`${baseURL}/api/some-endpoint`);
```

And in your `.env` file for React:

```
REACT_APP_API_URL=http://backend:4000
```

4. **Dockerfile Example for Node and React:**
Sample Dockerfiles for building your services separately:

- **Frontend (React) Dockerfile:**

```dockerfile
# ./frontend/Dockerfile
FROM node:14

WORKDIR /app

COPY package.json /app/package.json
RUN npm install

COPY . /app

CMD ["npm", "start"]
```

- **Backend (Node.js server) Dockerfile:**

```dockerfile
# ./backend/Dockerfile
FROM node:14

WORKDIR /app

COPY package.json /app/package.json
RUN npm install

COPY . /app

CMD ["node", "server.js"]
```

5. **Accessing Services by Name:**
With Docker Compose, services are accessible by their service names. Hence your React app can communicate with your Node server by using the service name defined in `docker-compose.yml`, which in this case is `backend`.

In summary, setting the `base_url` to `http://backend:4000` should ensure that your React app running in its container can successfully reach your Node.js server running in its dedicated container.


