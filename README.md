# AMP - API Markup Processor

**AMP** is a free markup processor for API definitions.
It aims to be partially compatible with [API Blueprint](https://apiblueprint.org/).

## Installation

Install [Drafter](https://github.com/apiaryio/drafter) according to its documentation.

Clone the repository and compile it:

```sh
$ git clone https://github.com/voidblaster/AMP.git
$ cd AMP
$ dub build --build=release --arch=x86_64

$ bin/amp --help
```


## Dependencies

- [Drafter](https://github.com/apiaryio/drafter)
    - (c) Apiary Inc.
    - License: MIT
    - Used for parsing API Blueprint files.
- [Mustache-D](https://github.com/repeatedly/mustache-d)
    - (c) Masahiro Nakagawa
    - License: BSL-1.0
    - Used for generating HTML files.
