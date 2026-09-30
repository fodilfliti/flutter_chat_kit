# Agent memory map

| File | Read when |
| --- | --- |
| [package.md](package.md) | Starting any task |
| [invariants.md](invariants.md) | Changing models, cache, sync, controllers, exports |
| [decisions.md](decisions.md) | Architecture trade-offs, adding a dependency |
| [tasks/](tasks/) | Build order; one task file per session |

## Truth order

1. Code in `lib/`
2. This folder
3. `CHANGELOG.md`
4. `README.md` (humans only)
