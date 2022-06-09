# `popgrid`

Populate a [Grid](https://github.com/hyperledger/grid) database with a basic circuit between `gridd-alpha` and `gridd-beta` over [Splinter](https://www.splinter.dev/).

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

* Run `popgrid` from within the [Grid](https://github.com/hyperledger/grid) checkout

### What does it do?

* Sets up a circuit between `gridd-alpha` and `gridd-beta`
* Caches the GS1 xsd
* Creates
  * Organization `MyOrganization`
  * Role `po-partner`
  * Agent with `po-partner` role
  * Purchase order
  * Purchase order version
  * Role `po-buyer`
  * Agent with `po-buyer` role
