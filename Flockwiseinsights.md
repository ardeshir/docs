Yes, I can help you with the steps to move your domain servers to AWS Route53 while keeping the original registrar. Here are the steps you can follow:
Sign in to the AWS Management Console and open the Route 53 console.
Create a hosted zone in Route 53 for your domain. This will give you the necessary name server (NS) records that you'll need to update at your registrar.
Note down the name servers provided by Route 53 for your hosted zone.
Sign in to your registrar's website (in this case, Mark Monitor) and locate the DNS management section.
Update the NS records for your domain with the name servers provided by Route 53. Remove any existing NS records and add the new ones.
Wait for the DNS changes to propagate. This typically takes a few hours or up to 48 hours depending on the TTL (Time to Live) settings of your domain.
Once the DNS changes have propagated, go back to the Route 53 console and verify that your domain is active and the status is "Hosted Zone Active".
Set up any necessary DNS records in your Route 53 hosted zone, such as A records, CNAME records, etc.
Test your domain's DNS resolution to ensure that it is now being served by Route 53.
Finally, monitor the domain and DNS resolution for a few days to ensure everything is functioning as expected.

Remember, in this setup, your DNS management will be handled by Route 53, but your domain registration will still be with Mark Monitor.
