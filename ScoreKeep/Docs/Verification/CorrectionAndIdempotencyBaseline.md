# Correction and Idempotency Baseline

<!-- MARK: - 1. Scope -->
## 1. Scope

Tasks 2.12 through 2.16 introduce non-routed canonical authority for correction planning, in-memory correction application, downstream replay recalculation, invalid-correction rejection, and duplicate command prevention.

<!-- MARK: - 2. Authority -->
## 2. Authority

The foundation describes correction intent with stable target and invocation evidence, resolves targets by event and game identity, applies one accepted correction to value facts, and classifies repeated scoring or correction intent without creating a persistent deduplication store.

<!-- MARK: - 3. Boundaries -->
## 3. Boundaries

The foundation has no SwiftData, UI, report generation, PDF generation, import, export, purchase, allowance, or production scoring route. Legacy scoring, correction, persistence, reports, imports, exports, and UI remain active.

<!-- MARK: - 4. Verification -->
## 4. Verification

Focused tests cover planning, target resolution, replacement and removal, atomic rejection, downstream replay recalculation, unsafe downstream replay classification, idempotency classification, and repeated invocation prevention.

<!-- MARK: - 5. Deferred Work -->
## 5. Deferred Work

Long-game verification, legacy comparison, production routing, SwiftData writes, persistent audit, persistent idempotency storage, undo and redo, report regeneration, export regeneration, import correction, and scoring cutover remain deferred.
