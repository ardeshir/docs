# How does FastAPI manage 100 simultaneous POST Requests?

- Using FastAPI that calls an optimizer function called Solve() from 100 simultaneous POST http requests, what happens exactly inside service running in Azure Container Applications with min two instances and max 10 instance?  

- When you deploy a FastAPI application in Azure Container Apps and handle simultaneous HTTP POST requests, several things happen under the hood, especially when your service scales between two and ten instances:

1. **Load Balancing**: Azure Container Apps will distribute incoming requests across the available instances of your application. With a minimum of two instances running, the load balancer will route requests to these instances to balance the load and prevent any single instance from becoming a bottleneck.

2. **Concurrency Handling**:
   - FastAPI itself is built on top of Starlette, which runs on ASGI (Asynchronous Server Gateway Interface) servers like `uvicorn`. These servers handle multiple requests concurrently using asynchronous programming. When a POST request hits your FastAPI endpoint, it will be handled by one of the worker threads or event loops available in the ASGI server.
   - If each of the current instances can handle, for example, 20 requests concurrently, the two initial instances can together handle 40 simultaneous requests. If there are more than 40 simultaneous requests, the rest may queue up, waiting for free capacity unless additional instances are scaled up.

3. **Auto-scaling**:
   - Azure Container Apps can automatically scale up the number of running instances depending on the load. If the load increases (e.g., you get 100 simultaneous requests), Azure will start additional instances to accommodate the extra load, up to the maximum limit of 10 instances.
   - The scaling is generally based on metrics like CPU usage, memory usage, or custom metrics like the number of requests per second.

4. **Solve() Function Execution**:
   - Each incoming POST request will invoke the `Solve()` optimizer function. Since FastAPI and uvicorn handle these requests asynchronously, each instance of your application can process multiple `Solve()` function calls concurrently, limited by the server’s resource constraints (CPU, memory).
   - Keep in mind that the actual concurrency limit can be influenced by factors like the available hardware resources (vCPU, memory) and the efficiency of the `Solve()` function itself.

5. **Response Handling**:
   - Upon completion of the `Solve()` function for each request, the results are sent back to the respective clients via HTTP responses. The FastAPI server manages the entire lifecycle of request handling—from receiving, invoking `Solve()`, to returning the response.

6. **Instance Tearing Down**:
   - When the load decreases, Azure Container Apps will scale down the number of instances. However, at least two instances will remain running if that is your defined minimum. This ensures some baseline capacity for handling incoming requests without incurring latency due to cold starts.

### Potential Issues
1. **Cold Starts**: As Azure scales out your application by adding new instances, there might be a slight delay (known as a cold start) as these additional instances start up and become ready to handle requests.
2. **State Management**: Ensure that your `Solve()` function and overall architecture are stateless or manage state appropriately, as requests might be routed to different instances which do not share the same memory space.

For more detailed information, you can refer to the following resources:
- [Official FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Azure Container Apps Documentation](https://docs.microsoft.com/en-us/azure/container-apps/)

These documents provide comprehensive guidance on developing applications with FastAPI and managing deployments in Azure Container Apps, including auto-scaling, concurrency handling, and best practices.

Incoming Requests:
The 100 simultaneous POST requests arrive at your FastAPI service endpoint hosted in Azure Container Applications.
Load Balancer:
Azure Container Applications use a load balancer to distribute incoming traffic across the available instances. Initially, with two instances running, the load balancer will attempt to distribute the requests evenly across these two instances.
Handling Requests per Instance:
Each instance of your FastAPI application will start handling the requests. Given two instances, each will initially attempt to process 50 requests simultaneously.
Concurrency Limits:
If each instance has limited resources (CPU, memory), handling 50 simultaneous requests may overwhelm the instance, leading to increased response times, potential timeouts, or resource contention issues.
Auto-Scaling:
Azure Container Applications monitor the resource utilization of each instance (CPU, memory, etc.). If the load (number of requests, CPU usage, etc.) exceeds a certain threshold defined in your auto-scaling policies, Azure will start spinning up additional instances.
In this case, if the two instances are overloaded, Azure might start additional instances, scaling up towards the maximum of 10 instances.
Redistribution of Requests:
As new instances come online, the load balancer will begin to distribute incoming requests to these new instances, helping to alleviate the load on the initial two instances.
Over time, the 100 requests will be distributed across the available instances. If all 10 instances are up, each instance would handle approximately 10 requests simultaneously.
Execution of Solve() Function:
Each request triggers the Solve() optimizer function within the FastAPI application. The nature of this function (CPU-bound, I/O-bound) affects how well it scales.
If Solve() is CPU-bound, the number of available CPU cores will limit how many requests can be processed concurrently on each instance.
If Solve() is I/O-bound (e.g., waiting for network responses or disk I/O), the instance may handle more concurrent requests using asynchronous programming provided by FastAPI.
Completion and Response:
Each instance processes its assigned requests by executing the Solve() function and returns the appropriate responses to the clients.
As requests are completed, the load on instances reduces, potentially triggering a scale-down operation if the load is significantly reduced and below the scale-down threshold.
### Best Practices and Considerations
 

#### Optimize Solve() Function:
Ensure that the Solve() function is optimized for performance to handle concurrent executions efficiently.
Consider using asynchronous programming if the function involves I/O operations.
#### Resource Allocation:
Allocate sufficient resources (CPU, memory) to each instance to handle the expected load.
Monitor resource usage and adjust instance size or auto-scaling policies accordingly.
#### Auto-Scaling Policies:
Define appropriate auto-scaling policies to handle spikes in traffic, ensuring that instances are added quickly when needed and scaled down when the load decreases.
#### Testing:
Perform load testing to understand how your application behaves under high load and to fine-tune your auto-scaling policies.

By considering these factors, you can ensure that your FastAPI service running on Azure Container Applications handles simultaneous POST requests effectively, providing optimal performance and reliability.
