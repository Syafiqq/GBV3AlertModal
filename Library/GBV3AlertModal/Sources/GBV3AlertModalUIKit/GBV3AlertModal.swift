import GBV3AlertModalCore

// Set once at app startup (main actor) and thereafter only read during modal construction (main
// actor) — that contract is now ENFORCED, not just documented: every real read/write site in this
// library was already main-actor-isolated (`GBAlertModal` via `UIView`; all 4 `ModalRenderer`
// conformers via an explicit `@MainActor`), so `@MainActor` here costs this library nothing and
// closes the one gap `nonisolated(unsafe)` left open — a consumer setting this from a background
// thread used to be a silent, uncaught data race; it is now a compile error.
@MainActor public var globalProperties = GBAlertModal.Properties()
