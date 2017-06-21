# Change Log

## [1.3.0] - 2017-06-21

This version requires xcflushd >= v1.2.0.

- Updated to work with Apicast v3.0.0.
- The priority auth renewer now subscribes to the redis pubsub channel before
  publishing to it. We initially had this in the reverse order (creating a race
  condition that needed to be handled in xcflushd) because the API from
  lua-redis used in the tests imposed so. However, the API from resty.redis,
  used in the rest of the codebase, does not. There is no longer a race
  condition and this change allows us to make some performance optimizations
  in xcflushd.
- Makes Redis timeouts configurable.
- Fixes a permissions problem with the Apicast log dir in the Apicast-XC
  dockerfile.

## [1.2.0] - 2017-05-02

- Improves performance when reporting by using Redis pipelines instead of multi/exec.

## [1.1.0] - 2017-04-19

- Updated to work with Apicast v3.0.0-rc1.
