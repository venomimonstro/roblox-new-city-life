# Sprint 06 (partial) — safe 3D asset intake

ModelAssetValidator.Validate(model) rejects executable Script/LocalScript/ModuleScript descendants, remotes, bindables, empty models, excessive parts/meshes and unreasonable dimensions. Accepted only for **manual review**; validation does not make a model safe or optimized.

Remaining: Cube 4D Studio authoring workflow, actual import UI, asset approval storage, material/texture budgets, collision setup, LOD, memory profiling and user-facing car catalog. No asset imports have been verified in Roblox Studio.

Required testing: a valid test Model accepted, embedded Script rejected, excessive geometry rejected, empty Model rejected, negative/oversized dimensions rejected, texture memory and mesh collision checks. Tests are not yet run in Studio. No CI.
