# 8man

Pronounced Hachiman, named after the god of thunder and war in Japanese mythology.
This project is a collection of libraries, curently written in zig, for game development.

## libs

- ecs
  - An entity component system library
  - Archetype based
  - Type erasure
    - Runtime entities
  - Allocator support (you don't have to use the heap)
  - Relatively lightweight
    - 8 bytes + 8 bytes per component on each archetype (could be improved)
