# AMP - API Markup Processor

**AMP** is a free markup processor for API definitions.
It aims to be partially compatible with [API Blueprint](https://apiblueprint.org/).


## Installation

1. Install [Drafter v4](https://github.com/apiaryio/drafter) (just stick to its docs)

2. ```sh
# Clone this repository and navigate into it:
git clone --recurse-submodules https://github.com/voidblaster/AMP.git
cd AMP


# (optional)
# Build the factory template in the `factory-template` directory
#   --> check its own README for help


# Build AMP using DUB:
cd AMP
dub build --build=release


# Show usage information:
bin/amp --help
```


## Dependencies

-[AMP Factory Template](https://github.com/MarkusLei22/AMP-Template)
    - (c) Markus Leimer
    - License: CC-BY-4.0
    - Used as template for HTML files.
- [Drafter](https://github.com/apiaryio/drafter)
    - (c) Apiary Inc.
    - License: MIT
    - Used for parsing API Blueprint files.
- [Mustache-D](https://github.com/repeatedly/mustache-d)
    - (c) Masahiro Nakagawa
    - License: BSL-1.0
    - Used for generating HTML files.
