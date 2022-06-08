# Scripts Grid

Helper scripts for developing Grid

## Getting Started

### Dependencies

* Docker
* Grid project checkout

### Installing

* Clone the project
* Add the following to your `~/.zshrc`
```
alias xgrid='SOURCE_DIR/xgrid/build.sh'
```

### Executing program

* Run `xgrid [CARGO_ARGS]` from within the grid checkout. This will build a new `gridd` docker image from your changes.
* You can now start the example docker instance with the new version of gridd
* Subsequent runs will use the same build image and rust incremental compilation to speed the build
