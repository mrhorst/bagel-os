# One Rails App With Bounded Modules

Restaurant Operations OS will be built as one Rails application composed of bounded modules, not as separate deployed apps, services, or Rails engines. Inventory, Tasks, and future modules are workflow areas inside the same application shell so restaurant staff can use one operating tool while the codebase still keeps module boundaries clear. This avoids premature user/session/data synchronization work and keeps a later split possible only if real operational pressure justifies it.
