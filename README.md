# aws-global-elasticache-promoter

Manages promotion of Global Elasticache datastores from secondary to primary based on route53 failover recordset status.  

Required env vars

|Var|Description|
|---|---|
|HOSTED_ZONE_ID|the route53 hosted zone id that contains the dns record to watch for failover|
|DNS_NAME|the dns name within the hosted zone to watch for failover|
|GLOBAL_DATASTORE_ID|ID of the Global Elasticache Datastore|

### Design

The lambda should be deployed to each region that has a datastore member.  Global Elasticache is limited to 2 regions, so for example if you deployed the primary member to us-east-1 and the secondary member to us-east-2, you would deploy this lambda to us-east-1 and us-east-2.  The lambda must exist in both regions to protect against entire region failure.

Each lambda will attempt to modify the current primary member only if the supplied DNS name resolves to a resource in the same region as the lambda, and that member is not the current primary.

The lambda is configured with a DNS name it should check for changes; this DNS name must be in Route53 and contain alias targets to AWS resources like NLB / ALB.  

**Caching to reduce AWS API calls**

The AWS APIs for describing the Route53 recordset and Elasticache members are rate limited to 5 requests per second.  Results of these APIs are cached in global lambda memory and only refreshed if the DNS answer for the watched domain contains IPs that are not in the cached API results.  The results are also refreshed after a failover event.

On lambda, startup the results are cached once.  Subsequent invocations only check the DNS answer of the watched domain name using a stanard DNS query.

### Deployment

