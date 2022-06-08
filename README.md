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
export SCRIPTS_GRID=[INSERT SOURCE DIR FOR THIS PROJECT]
alias xgrid="$SCRIPTS_GRID/xgrid/build.sh"
```

### Executing program

* Run `xgrid [CARGO_ARGS]` from within the grid checkout. This will build a new `gridd` docker image from your changes.
* You can now start the example docker instance with the new version of gridd
```
cd $GRID_SOURCE_DIR
cd examples/splinter
docker-compose down # Stop if already running
docker-compose up # Fire it up again
```
* Subsequent runs of `xgrid` will use the same build image and rust incremental compilation to speed gridd builds
