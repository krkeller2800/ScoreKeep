# Frozen V2 Fixture Support

<!-- MARK: - 1. Purpose -->
## 1. Purpose

`GenerateFrozenV2SyntheticFixture.swift.txt` is a standalone Task 3.22B fixture generator. It is copied from the seven-model source shape at commit `91dd5c3fd26301e47f898dfaeedbde9cde35a3d9`, the immediate pre-V3 runtime boundary inspected for this task. The `.txt` suffix prevents Xcode's synchronized project structure from compiling the support generator into the app target.

<!-- MARK: - 2. Boundary -->
## 2. Boundary

The generator is not part of the app target, is not a production migration path, does not launch ScoreKeep, does not launch a simulator, does not use a production store, and does not link the five V3 canonical scoring models. It exists only to regenerate the synthetic fixture family and metadata evidence under `RepresentativeSyntheticV2`.

<!-- MARK: - 3. Regeneration -->
## 3. Regeneration

From this directory:

`cp GenerateFrozenV2SyntheticFixture.swift.txt /tmp/GenerateFrozenV2SyntheticFixture.swift`

`xcrun swiftc -Xfrontend -disable-sandbox /tmp/GenerateFrozenV2SyntheticFixture.swift -o generate-v2`

Then run:

`./generate-v2 /tmp/FrozenV2Synthetic/FrozenV2Synthetic.sqlite`

After the process exits, preserve all emitted files named `FrozenV2Synthetic.sqlite` or starting with `FrozenV2Synthetic.sqlite-`, recompute digests, and update `FrozenV2SyntheticEvidence.json` only when the semantic evidence is intentionally accepted.
