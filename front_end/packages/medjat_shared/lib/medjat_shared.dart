/// Code shared by the Medjat employee app and the branch kiosk.
///
/// **Why this package exists.** The employee app and the kiosk are two separate
/// products with separate binaries, but they both extract a face embedding and
/// send it to the same backend, which compares it against a single stored
/// vector per employee (`employees.face_embedding`). If the two products ever
/// extracted embeddings differently — a different model file, a different crop
/// margin, a different normalisation — the server would compare vectors from
/// two incompatible spaces and simply stop matching people, with no error
/// anywhere to explain it. Keeping one copy here makes that class of bug
/// impossible rather than merely unlikely.
///
/// Anything that must be identical across both products belongs here. Anything
/// that is genuinely product-specific — screens, routing, session handling,
/// the employee app's offline queue — does not.
library;

export 'src/face/face_embedder.dart';
export 'src/face/face_liveness.dart';
