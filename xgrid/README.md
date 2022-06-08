# ❌GRID

Super fast incremental cross compiler for [Grid](https://github.com/hyperledger/grid) development

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
* Subsequent runs of `xgrid` will be way faster due to caching! 🎉
