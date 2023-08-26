# engine

an engine serving as a kind of intermediary between something like raylib and unity.

## roadmap

- [ ] video/platform modules
  - [ ] win32
  - [ ] ~~linux~~
  - [ ] ~~macos~~
  - [ ] ~~android~~
  - [ ] ~~ios~~
- [ ] render modules
  - [ ] d3d11
  - [ ] ~~vulkan~~
  - [ ] ~~metal~~
  - [ ] ~~d3d12~~
- [ ] audio module
  - [ ] win32
  - [ ] ~~macos~~
  - [ ] ~~linux~~
  - [ ] ~~android~~
  - [ ] ~~ios~~
- [ ] scene graph
  - [ ] mesh optimiser
  - [ ] level streaming
- [ ] physics system (probably will fork jolt physics)
- [ ] animation system
- [ ] ui system (centau_ri's vide)
- [ ] networking
- [ ] basic editor
- [ ] ecs (centau_ri's ecr)
- [ ] scripting
  - [ ] transpile luau vm to zig
  - [ ] reworked syntax and semantics
  - [ ] improve type system
    - [ ] algebraic data types
  - [ ] AoT compilation
- [ ] shader programming
  - [ ] use modified luau
- [ ] game packaging

note: some things are striked out, like linux and vulkan support; this is because I want to get a minimum windows version running before I work on cross platform support.
  