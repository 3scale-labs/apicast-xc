# XC


## Description

XC is a module for [Apicast](https://github.com/3scale/apicast), 3scale's API Gateway.
Apicast performs one call to 3scale's backend for each request that it
receives. The goal of XC is to reduce latency and increase throughput by
significantly reducing the number of requests made to 3scale's backend. In order
to achieve that, XC caches authorization statuses and reports.


## Development environment and testing

You will need [Docker](https://www.docker.com/) and GNU make.

First, clone the project:
```
$ git clone git@github.com:3scale/xc.lua.git
```

Next, cd into the directory, `cd xc.lua`

Run the tests with:
```
$ make test
```

That will run the unit test suite and also a code linter inside a Docker
container.
The unit tests suite uses [Busted](https://github.com/Olivine-Labs/busted).
For code linting we use [Luacheck](https://github.com/mpeterv/luacheck).

Develop:
```
$ make bash
```

That will create a Docker container and run bash inside it. The project's
source code will be available in `~/app` and synced with your local apicast-xc
directory. You can edit files in your preferred environment and still be able
to run whatever you need inside the Docker container.


## How it works

XC uses Redis as a cache to reduce the number of queries to the 3scale backend.
When a requests comes in:

- If the authorization is cached:
    1. The authorization status is retrieved from Redis.
    2. If the request is authorized, the usage report is cached in Redis and
       will later be send to 3scale backend in a batch.
    3. XC returns authorized/denied to the Gateway.

- If the request is not cached:
    1. The authorization status is retrieved from 3scale.
    2. The authorization status is cached in Redis.
    3. If the request is authorized, the usage report is cached in Redis and
       will later be send to 3scale backend in a batch.
    4. XC returns authorized/denied to the Gateway.

XC only takes care of the Redis accesses part. To work correctly, it needs
to be deployed along with [xcflushd](https://github.com/3scale/xcflushd).
xcflushd is a daemon that basically takes care of:

1. Reporting the cached reports in batches.
2. Updating the status of the cached authorizations.
3. Retrieving an authorization status from 3scale backend when it is not
   cached.

For further details about xcflushd, please go to its [GitHub repo](https://github.com/3scale/xcflushd).

A detailed design document will be provided later.


## Deployment

At the moment, deploying Apicast with XC is not as convenient as we would like.
We are currently working on offering an easy way to deploy it on [Openshift](https://www.openshift.com).

In the meanwhile, you can use Docker or deploy XC locally. Deploying Apicast
with XC is very similar to deploying Apicast. The only difference is that XC
needs two environment variables not required in Apicast:
```
APICAST_MODULE=apicast_xc
REDIS_HOST=your_redis_host.com:6379
```

### Docker

Build the image:
```
$ docker build -t apicast-xc -f Dockerfile-apicast .
```

Run:
```
$ docker run --name apicast --rm -p 8080:8080 -e REDIS_HOST=your_redis_host.com:6379 -e APICAST_MODULE=apicast_xc -e THREESCALE_PORTAL_ENDPOINT=https://access-token@account-admin.3scale.net apicast-xc
```

### Locally

- Run `make apicast.xc` to install XC's dependencies.
- Copy `apicast_xc.lua` and the `xc` directory of this repo into the `src`
  directory of Apicast.

Apicast can then be executed like this:
```
$ REDIS_HOST=your_redis_host.com:6379 APICAST_MODULE=apicast_xc THREESCALE_CONFIG_FILE=config.json bin/apicast
```

For a more detailed explanation about deploying Apicast and running it, please
check its [GitHub repo](https://github.com/3scale/apicast).

Remember that you'll also need [xcflushd](https://github.com/3scale/xcflushd) running.

## Trade-offs

Compared to Apicast:

### Pros
- Considerably lower latencies and higher throughput.
- If 3scale is unreachable, applications can still be authorized using the
  cache.

### Cons
- Needs two extra components to work: Redis and the flusher.
- Going over the defined usage limits is easier. Apicast reports to 3scale
  every time it receives a request. Reports are asynchronous and that
  means that we can go over the limits for a brief window of time. On the other
  hand, XC reports every X minutes (configurable) to 3scale. The window of time
  in which we can get over the limits is wider in this case.


## Limitations

These are some of the current limitations. They will be fixed if there is a need.

- 3scale supports three authentication modes. However, currently XC only
  supports the `user_key` one.
- XC can only hit one application per request.
- XC is not compatible with 3scale's request logs feature.
- The timestamp of the reported transactions loses resolution. Transactions
  are assigned a timestamp when they are reported to 3scale. With Apicast this
  happens in every request. On the other hand, with XC this happens when the
  flusher sends the reports. This happens every X minutes (configurable).


## Contributing

1. Fork the project
2. Create your feature branch: `git checkout -b my-new-feature`
3. Commit your changes: `git commit -am 'Add some feature'`
4. Push to the branch: `git push origin my-new-feature`
5. Create a new Pull Request


## License
[Apache-2.0](https://www.apache.org/licenses/LICENSE-2.0)