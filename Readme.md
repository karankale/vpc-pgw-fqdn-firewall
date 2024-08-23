In today's cloud-driven world, securing virtual environments is paramount. As businesses migrate to cloud infrastructures like IBM Cloud Virtual Private Cloud (VPC), the need to manage and secure egress traffic effectively becomes a critical concern. One effective method is building a public gateway Fully Qualified Domain Name (FQDN) firewall using a Squid Transparent Proxy. This setup helps filter egress traffic and enforce security policies, ensuring that only authorized connections are made to the internet from your cloud resources.

### Understanding the Key Components

1.  **IBM Cloud VPC -** A Virtual Private Cloud (VPC) is a logically isolated section of the IBM Cloud where you can launch IBM Cloud resources in a virtual network that you define. A VPC allows you to have greater control over your network environment, including selection of your own IP address range, creation of subnets, and configuration of route tables and gateways.
2.  **Public Gateway -** A public gateway within IBM Cloud VPC that allows instances within the VPC to access the internet. It's a key component for managing outbound traffic from your VPC resources.
3.  **FQDN Firewall -**  A Fully Qualified Domain Name (FQDN) firewall enables filtering traffic based on domain names instead of IP addresses. This allows more granular control over the destinations that your cloud resources can access.
4.  **Squid Transparent Proxy -**  Squid is an open-source caching and forwarding HTTP proxy. When configured as a transparent proxy, Squid intercepts and handles traffic without requiring any client-side configuration. This makes it an ideal tool for enforcing web access policies, such as filtering based on FQDN.
5.  **VPC Routing Table -** A VPC Routing Table is a critical component in a Virtual Private Cloud (VPC) that determines how network traffic is directed within the VPC and between the VPC and other networks, such as the internet or other VPCs.

### Why Use a Squid Transparent Proxy for FQDN Filtering?

Squid provides several advantages when used as a transparent proxy for FQDN filtering:

*   **Ease of Deployment-**   Since it doesn't require client-side configuration, Squid can be easily integrated into your existing VPC setup.
*   **Granular Control** -  Squid allows for detailed rules based on domain names, helping you block or allow specific sites.
*   **Logging and Monitoring** - Squid can log all HTTP requests, giving you insights into the traffic flowing through your VPC.
*   **Scalability** -  Squid can be scaled according to the needs of your organization, making it suitable for both small and large-scale deployments.

### Steps to Build a Public Gateway FQDN Firewall with Squid

1.  **Set Up IBM Cloud VPC -** Begin by creating a VPC in IBM Cloud. Define the network segments and subnets according to your architecture needs. Create a dedicated subnet for hosting the Squid Proxy and ensure that this subnet has a public gateway configured for internet-bound traffic. All other subnets do not need a public gateway.
2.  **Deploy and Configure the Squid Proxy -**
    *   Provision a virtual server instance within your VPC to host the Squid proxy. You can use a standard Linux distribution like Ubuntu or CentOS.
    *   Install Squid on the server. This can typically be done using the package manager of your Linux distribution (e.g., \`apt-get install squid\` for Ubuntu).
    *   Configure Squid to run in transparent mode. Update the Squid configuration file (\`/etc/squid/squid.conf\`) with appropriate settings. Here’s a basic example. This configuration intercepts HTTP traffic on port HTTP traffic on 3129 and HTTPS traffic on 3129 and allows access only to the specified domains.
        
        ```
         visible_hostname squid

         sslcrtd_program /usr/lib/squid/security_file_certgen -s /var/lib/ssl_db -M 16MB
         sslcrtd_children 10

         # Define ports
         http_port 3128
         http_port 3129 intercept
         https_port 3130 intercept ssl-bump generate-host-certificates=on \
            dynamic_cert_mem_cache_size=4MB \
            cert=/etc/squid/ssl/squid.pem \
            key=/etc/squid/ssl/squid.key

         # Allowlist configuration
         acl allowed_http_sites dstdomain .ibm.com
         acl allowed_http_sites dstdomain .docker.com
         acl allowed_http_sites dstdomain .google.com
         http_access allow allowed_http_sites

         acl allowed_https_sites ssl::server_name .ibm.com
         acl allowed_https_sites ssl::server_name .docker.com
         acl allowed_https_sites ssl::server_name .google.com

         # SSL Bump configuration
         acl SSL_port port 443
         http_access allow SSL_port
         acl step1 at_step SslBump1
         acl step2 at_step SslBump2
         acl step3 at_step SslBump3
         ssl_bump peek step1 all
         ssl_bump peek step2 allowed_https_sites
         ssl_bump splice step3 allowed_https_sites
         ssl_bump terminate step2 all

         # Logging
         access_log /var/log/squid/access.log squid
         cache_log /var/log/squid/cache.log

         http_access deny all
        ```
        
3.  **Redirect Traffic through the Squid Proxy -** Use iptables or the firewall tool of your choice to redirect outbound HTTP traffic to the Squid proxy. This ensures that all outgoing traffic passes through Squid, allowing it to enforce your FQDN-based rules. Example iptables command:
    
    ```
    iptables -t nat -I PREROUTING 1 -s 10.64.0.0/16 -p tcp --dport 80 -j REDIRECT --to-port 3129 
    iptables -t nat -I PREROUTING 1 -s 10.64.0.0/16 -p tcp --dport 443 -j REDIRECT --to-port 3130
    ```
    
4.  **Integrate with VPC Routing Tables -**  Ensure that your public gateway is routing all outbound traffic from your VPC through the instance running the Squid proxy. This may require adjustments in your VPC route tables.
    
5.  **Testing and Validation -** Test the configuration by attempting to access different domains from instances within your VPC. Verify that only the allowed domains can be accessed, and other domains are blocked. Monitor Squid logs to ensure that it’s properly intercepting and filtering traffic.
    
6.  **Scaling and Optimization -** Depending on your traffic load, consider deploying multiple Squid instances and using a load balancer to distribute traffic across them. Regularly update the allowed domains in your Squid configuration to adapt to changing business requirements.
    

### Conclusion

Building a public gateway FQDN firewall using a Squid Transparent Proxy in IBM Cloud VPC provides a powerful and flexible way to control and secure outbound traffic. This setup not only enhances security but also gives you granular control over the internet resources that your cloud environment can access. By following the steps outlined above, you can create a robust firewall solution tailored to your specific needs, leveraging the capabilities of IBM Cloud and the versatility of Squid.  
