// Set once at app startup (main actor) and thereafter only read during modal construction (main
// actor). `nonisolated(unsafe)` documents that contract: no enforced isolation, but no real race —
// single-writer-at-launch, reader-on-main. Kept non-isolated so consumers set it without an actor hop.
nonisolated(unsafe) public var globalProperties = GBAlertModal.Properties()
