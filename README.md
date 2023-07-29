# aws-global-elasticache-promoter

TLDR: deploy the lambda to each region of a 2-region Global Elasticache datastore; trigger it on a CloudWatch cron schedule, point it to a Route53 alias failover record; it will promote the secondary global ES instance if Route53 fails over the DNS pointer to the secondary region.

Global Elasticache datastores support 2 regions, but only in active/passive mode.  Only one region can be read/write at one time, the other region is read-only. AWS provides no way to automatically promote a secondary region. This lambda was created to support a [Gloo Platform Multi-Region HA Demo in AWS](https://github.com/bdlilley/multi-region-demo/); the demo repo contains Terraform artifacts to deploy a 2-region, 4-cluster Gloo Platform service mesh and demonstrate automated failover Gloo Platform and AWS Global Elasticache during a simulated regional failure.

### Design

On lambda initialization (only happens once per lambda instance the first time it's invoked):

* Recordsets for the specified hosted zone and domain are fetched via the Route53 API and the targets for failover primary and secondary are cached in global memory
* The current Elasticache replication group (RG) members and their current status (primary vs secondary) are cached in global memory

On each lambda triggered invocation:

* A DNS query is performed against the specified domain
* The result is compared to the cached recordsets
  * If any value in global cache is nil, they are refetched via the AWS API
* If the active recordset points to the lambda's region, but the cached RG member in that region is secondary, the lambda attempts to promote its region's Elasticache member to primary
* The cache is cleared after promotion; it takes 1-2 minutes for the promotion to occur, so cached results cannot be used
* The cache is cleared on any error attempting to resolve or promote an RG member - this causes the lambda to re-fetch on the next triggered invocation

The purpose of the in-memory cache is simply to eliminate excessive calls to the AWS API.  Under stable operation when no failovers have occured, the lambda only invokes the AWS APIs once on startup.  This is important because the rate limit for describing recordsets and RG members is 5 rps (a single instance on 1 min timer would not hit this, but if you deploy many promoter lambdas it could become a problem).

The lambda will continue to operate correctly after a failover; it can handle mutiple, bi-directional failovers between two regions. 

### Deployment

The lambda must be deployed to each region of the Global Elasticache datastore and triggered on a schedule (like a CloudWatch event triggered from cron expression - see [this terraform example](https://github.com/bdlilley/multi-region-demo/blob/main/terraform-eks/lambda-redis-promoter.tf)).

**Lambda ENV Vars**

|Var|Description|
|---|---|
|HOSTED_ZONE_ID|the route53 hosted zone id that contains the dns record to watch for failover|
|DNS_NAME|the dns name within the hosted zone to watch for failover|
|GLOBAL_DATASTORE_ID|ID of the Global Elasticache Datastore|