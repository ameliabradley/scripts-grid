# popgrid

Populate a [grid](https://github.com/hyperledger/grid) database with a basic setup alpha / beta connection over splinter

## Getting Started

### Dependencies

* Docker
* Grid project checkout

### Installing

* Clone the project
* Add the following to your `~/.zshrc`
```
export SCRIPTS_GRID=[INSERT SOURCE DIR FOR THIS PROJECT]
alias popgrid="$SCRIPTS_GRID/popgrid/popgrid.sh"
```

### Executing program

* Run `popgrid` from within the [grid](https://github.com/hyperledger/grid) checkout. This will recreate the images and populate the db
