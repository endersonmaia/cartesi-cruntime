# EXPERIMENTAL

This is an experimental Cartesi App to show how to use a container image as an app without the need bundling `cartesi-machine-guest-tools` to the app container.

This way, you can use a stock container image as source of the application and the `cruntime` will take care of runnig this app just like Docker does with any container on your host.

The latest alpha for @cartesi/cli make it possible to create a cartesi machine with multiple drives, and this functionality is used to bundle a cruntime, the OCI bundle for tha app contaienr with  `rootfs/` and a `config.yaml`


Using the latest `@cartesi/cli` prerelease:


```shell
> cartesi --version
2.0.0-alpha.15

> cartesi build
...

         .
        / \
      /    \
\---/---\  /----\
 \       X       \
  \----/  \---/---\
       \    / CARTESI
        \ /   MACHINE
         '

[INFO  rollup_http_server] starting http dispatcher service...
[INFO  rollup_http_server::http_service] starting http dispatcher http service!
[INFO  actix_server::builder] starting 1 workers
[INFO  actix_server::server] Actix runtime found; starting in Actix runtime
[INFO  actix_server::server] starting service: "actix-web-service-127.0.0.1:5004", workers: 1, listening on: 127.0.0.1:5004
[INFO  rollup_http_server::dapp_process] starting dapp: crun run --config /container/config/config.json --bundle /container app
HTTP rollup_server url is http://127.0.0.1:5004

Manual yield rx-accepted (1) (0x000020 data)
Cycles: 5057448724
5057448724: 2b2ce7b68b0e627f4af263fffa0164fab2b601a11ed310f12223b2e5e1623445
Storing machine: please wait

> cartesi shell --command "crun --version"
Running in unreproducible mode!

         .
        / \
      /    \
\---/---\  /----\
 \       X       \
  \----/  \---/---\
       \    / CARTESI
        \ /   MACHINE
         '

crun version 1.22
commit: 4de19b63a85efd9ea8503452179c371181750130
rundir: /run/crun
spec: 1.0.0
+SELINUX +APPARMOR +CAP +SECCOMP +EBPF +YAJL

Halted
Cycles: 114237693
```
