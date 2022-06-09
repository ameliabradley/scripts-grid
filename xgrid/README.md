# `xgrid`

Incremental compiler to create a local `gridd` docker image with a [Grid](https://github.com/hyperledger/grid) debug binary

# How it works

`xgrid` compiles Grid's `examples/splinter` docker image `gridd` using a persistant `grid-builder-instance` docker image in the background. The builder image caches important components to speed up subsequent builds.

The cache includes:
* Rust incremental compile information from `/target`
* gridd linking dependencies

Build output is a *debug* build with `RUST_BACKTRACE=1`

`xgrid` may be faster if the local development branch significantly deviates from the grid `main` branch.

## Getting Started

### Dependencies

* Docker
* Grid project checkout

### Installing

* Clone the project
* Add the following to your `~/.zshrc`
```
export SCRIPTS_GRID=[INSERT SOURCE DIR FOR THIS PROJECT]
alias xgrid="$SCRIPTS_GRID/xgrid/build.sh"
```

### Executing program

* Run `xgrid [CARGO_ARGS]` from within the [Grid](https://github.com/hyperledger/grid) checkout. This will build a new `gridd` docker image from your changes.
* Use the new image by either:
  * Running `docker down; docker up` in `examples/splinter` for a bare-bones setup
  * Or by simply running [popgrid](../popgrid), if you want a preloaded circuit with data
* Subsequent runs of `xgrid` will be faster due to caching
