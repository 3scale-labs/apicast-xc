# DESIGN

## Description

XC is a module for [Apicast](https://github.com/3scale/apicast), 3scale's API
Gateway.

When Apicast receives a request, it performs an `authrep` call to 3scale's
backend. This `authrep` call consists of:

1. Checking whether the request is authorized. 3scale lets its users define
   authorization rules based on a keys, rate limits and other criteria. The
   3scale backend checks those rules and decides whether the call should be
   authorized or denied.
2. If the call is authorized, then it increases its associated metrics. 3scale
   lets its users define mapping rules that associate metrics with API
   endpoints. This allows the users to keep track of the hits made to their
   APIs and define rate limits based on them.

This model is perfectly fine for lots of use cases. However, notice that it
implies calling 3scale's backend for each request that the gateway receives. We
can make this flow more efficient and reduce the latencies that the users of
our APIs experience, if we are willing to make some trade-offs.

Suppose that we have an API with high usage limits, in the range of millions of
calls per day for a particular application. In this scenario, it seems wasteful
to call 3scale backend for every request. What we could do instead is check
whether the application is authorized and cache that authorization status for
some seconds or minutes. This is precisely what XC does.

The goal of XC is to reduce latencies and increase throughput by significantly
reducing the number of requests made to 3scale's backend. In order to achieve
that, XC caches authorization statuses and reports.

XC has another benefit. In the rare event of a 3scale outage, the users are
still able to authorize the applications that use their APIs by checking the
cached authorization statuses.

There are some use cases for which XC might not be a great fit. XC makes a
trade-off between performance and accuracy of the rate limits applied, as it
does not check whether the rate limits are exceeded on each request. It only
does so at fixed, configurable intervals. This means that the usage limits could
be exceeded in the window of time where only cached authorizations statuses are
applied for a particular application.

This is usually not a problem. Imagine that you define a limit of thousands of
requests per hour and you configure XC to cache authorizations for one minute.
In a scenario like that, XC would take at most a minute to realize that limits
have been exceeded.

If you want to learn more about the 3scale platform, you can check the
[3scale support website](https://support.3scale.net/).


## How does XC work

XC uses two software components that are not needed when using vanilla Apicast:

- [Redis](https://redis.io/): in-memory database where authorizations and usage
  reports are cached.
- [xcflushd](https://github.com/3scale/xcflushd): the XC module mainly takes
  care of accessing the Redis cache to check for cached authorization statuses
  and cache usage reports. xcflushd is the daemon that contacts 3scale. It
  takes care of three things:
    1. Reporting the cached reports in batches.
    2. Updating the status of the cached authorizations.
    3. Retrieving an authorization status from 3scale backend when it is not
       cached.

XC receives from Apicast all the information needed to authorize and report the
usage of an application. This includes: a service ID, credentials, and the
metrics to be reported. The credentials received depend on the authorization
mode used. XC supports three authentication modes from 3scale: app ID, app key,
and oauth.

XC looks for the authorization status of the `(service_ID, credentials)` pair
in Redis. The authorization can be OK, denied, or unknown if not cached.

If the authorization is OK, XC also caches the usage. It will be reported in the
next batch of the xcflushd daemon. The default behaviour consists of just
returning 200 when the app is authorized and 403 when it is not, but this is
configurable.

If the authorization status is unknown because it was not stored in Redis, XC
needs to retrieve it from 3scale. To do so, it publishes a message specifying
the authorization details in Redis using its pubsub capabilities. The flusher
will be listening for that message, and it will retrieve the authorization
status from 3scale's backend, return it to XC, and also cache it. XC will then
return 200 or 403 according to the authorization status.


## Redis keys format

This section details the data type used for each of the Redis keys used.
The format that each keys follows is detailed in `storage_keys.lua`.


### Cached authorizations

The authorizations for a `(service_id, credentials)` pair are stored in a hash.
The keys of that hash are metrics. The values can be `0` (auth denied) or `1`
(auth ok). In case of auth denied, there is an optional reason specified
following this format: `0:a_reason`.


### Cached usage reports

The reports for a `(service_id, credentials)` pair are stored in a hash. The
keys of the hash are metrics. The values are the number of hits reported to
that metric.


### Set of cached reports keys

This is a Redis set. Every time a report is cached, the key where it is stored
is added to this set. This set is important so xcflushd knows where to find the
cached reports that it needs to flush. If we did not define a set like this, we
would need to perform a scan through all the database, which would be slower.

When the flusher sends to the 3scale backend the cached reports, it removes from
the set the keys where they are stored. This way the set contains, at any
given point of time, the keys of the reports that need to be sent to 3scale in
the next batch.


### Pubsub

When the authorization for a specific `(service_id, credentials)` pair is not
cached, XC publishes a message in the `xc_channel_auth_requests` pubsub channel.

That message contains enough information to identify a `(service_id,
credentials, metric)` tuple. After publishing the message, the thread subscribes
to a pubsub channel specific for that tuple. xcflushd will receive the message,
query 3scale's backend to know the status of the authorization, and then publish
the result in that pubsub channel. xcflushd will also renew all the
authorizations in the cache related to those `service_id` and `credentials`.


## Performance analysis

When an authorization is cached, we just need one `hget` call to Redis to get
it. If the authorization is OK, then we'll need two more calls to Redis: an
`hincrby` call to increase the value in the cached report, and a `sadd`, to
add the hash key for the `(service_id, credentials)` pair to the set of cached
report keys. All this should be pretty fast.

Obviously, when the authorization is not cached, latencies will increase.
xcflushd will need to ask 3scale's backend and come back. xcflushd is optimized
to make just one call to 3scale's backend when it's asked for the same
authorization more than once at a time. The idea is that the authorization for
most requests would be cached, so this should not be a problem.

For a detailed explanation of how the xcflushd works, check its
[repo](https://github.com/3scale/xcflushd).
