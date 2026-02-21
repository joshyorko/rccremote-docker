<a name="unreleased"></a>
## [Unreleased]


<a name="v0.2.1"></a>
## [v0.2.1] - 2024-11-21
### Docs
- Updated README with custom ROBOCORP_HOME + mermaid graph


<a name="v0.2.0"></a>
## [v0.2.0] - 2024-11-20
### Fix
- RCC entrypoint: build every environment with ROBOCORP_HOME read from .env. After that, export the environment into ZIP files, and import them into the shared holotree. Only in this way the holotree paths are user-definable.
- fixed bug in certificate generation (SERVER:NAME not exported)

### Refactor
- added volumes to containers
- moved the robots

### Style
- added better logging


<a name="v0.1.0"></a>
## v0.1.0 - 2024-11-20
### OK
- self-signed and signed certificates work


[Unreleased]: https://github.com/elabit/rccremote-docker/compare/v0.2.1...HEAD
[v0.2.1]: https://github.com/elabit/rccremote-docker/compare/v0.2.0...v0.2.1
[v0.2.0]: https://github.com/elabit/rccremote-docker/compare/v0.1.0...v0.2.0
