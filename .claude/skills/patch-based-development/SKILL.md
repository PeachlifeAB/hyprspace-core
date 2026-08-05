---
name: patch-based-development
description: "Use when setting up upstream patch stacks, adding or revising patches, recovering unexported edits, upgrading upstream, validating a stack or releasing."
---

# Patch-Based Development

The workspace is output. Canonical inputs must reproduce every intended change.

## 1. Establish evidence

Read workflow instructions, task definitions and invoked implementations, including helpers and
recovery paths.

Record:

- **State:** current pin/resolved identity, requested target, manifest order/count, control/workspace
  status.
- **Operations:** replay, export, validation, tests, upgrade and metadata entry points.
- **Contracts:** exact commands, arguments, working directories, input/output trees, preconditions
  and side effects.

**Gate:** Required contracts are verified. Missing tooling routes to setup; contradictions block edits.
Recheck this record after interruptions.

## 2. Classify before editing

Read relevant patches; identify each behavior's owner, dependencies and tests.

| Change            | Action                                                                     |
| ----------------- | -------------------------------------------------------------------------- |
| Initial setup     | Define canonical inputs and operations; prove an export/replay round-trip. |
| Control files     | Edit directly; run affected checks; skip patch export.                     |
| Existing behavior | Replace its owner; preserve patch identity and manifest position.          |
| New behavior      | Add one patch after dependencies; register its exact identity once.        |
| Multiple or mixed | Update owners in order, replay between exports, then add new behavior.     |
| Upstream upgrade  | Follow §5.                                                                 |

**Gate:** Every change has a destination. Ownership follows behavior, not filenames.

## 3. Preserve work and establish baseline

1. Separate expected applied patches from unexported work before cleanup.
2. Back up staged/untracked/ignored edits and local history outside cleanup targets.
3. Verify restoration preserves paths, contents, deletions, file types, modes and staged state.
4. For existing stacks, record strict replay/validation at the current pin.

**Gate:** Recovery is verified; unrelated baseline failures are resolved before further changes.
Serialize top-level operations sharing a workspace or output locations.

## 4. Edit and export one behavior

1. Establish the **parent**: pinned base plus predecessors, excluding the target and successors.
2. Register files as required; edit implementation/tests in the exporter's verified input tree.
3. Run focused checks; export the COMPLETE intended behavior against its parent using explicit paths/hunks.
4. Review every hunk and provenance; update the destination selected in §2; replay.

**Gate:** The stored patch contains the complete revised behavior, excluding unrelated and successor
changes.

A fix-only delta above the fully patched tree cannot replace its owning patch.

- Alternate trees require a verified export or transfer path before edits.
- Source-level tests travel with patches; workflow tests remain control files.
- Repair affected successors separately; preserve each patch's behavioral boundary.

## 5. Upgrade upstream

1. Confirm the exact target, authorized side effects and entry-point preconditions before changing inputs.
2. Use the established upgrade flow; a documented manual flow updates the pin before reconstruction.
3. At failure, inspect partial application and follow the actual recovery instructions.
4. Export the repaired owner using §4's boundary against the new base plus predecessors.
5. Replay after each export; repeat until the entire stack passes.

**Gate:** The complete stack passes at the new pin.

- Label findings with the tested base; candidate incompatibility is distinct from pinned-baseline failure.
- A first-failure report covers only the attempted prefix.
- Retire a patch only after proving upstream equivalence or obtaining authorization to remove its behavior.

## 6. Verify and finish

1. Before long runs, inspect assertions and previous logs; align artifact paths and search failure strings.
2. Generate required metadata; perform clean replay, full validation and required builds/tests.
3. Verify every prefix builds and passes applicable tests.
4. Review canonical diffs; changes to verified inputs require fresh affected checks.
5. Report base/stack-content identities, exact commands, outcomes and unrun checks.

**Gate:** All required checks pass on reconstructed sources; unrun required checks mean incomplete.
Release only the verified state, within authorized version/commit/tag/push scope.

## Replay contract

- Canonical inputs: immutable upstream revision/content digest, ordered manifest, patches and tracked
  configuration/tooling.
- Reconstruct a clean workspace without stale outputs; replay leaves the pin unchanged.
- Parse the manifest's actual grammar; reject missing/duplicate entries and paths outside declared storage.
- Apply each patch to its predecessors' output; stop non-zero at the first named failure.
- Require zero fuzz and exact context/whitespace; reject skipped hunks and implicit merge fallbacks.
- Inspect offsets and regenerate affected patches before acceptance.
- Exporter/applicator compatibility must preserve required binary, mode, symlink, rename and deletion
  semantics.
- Keep disposable workspace artifacts and internal tool state outside canonical inputs.
- Unsupported contracts block acceptance: correct the tooling explicitly rather than silently
  substituting workflows.
