# Face embedding model

`FaceEmbedder` (`lib/core/services/face_embedder.dart`) expects:

```
assets/models/mobilefacenet.tflite
```

## Installed model (2026-08-01)

| | |
|---|---|
| Source | [MCarlomagno/FaceRecognitionAuth](https://github.com/MCarlomagno/FaceRecognitionAuth) `assets/mobilefacenet.tflite` |
| Licence | BSD 3-Clause (see `mobilefacenet.LICENSE.txt`) — commercial use permitted, notice must be retained |
| SHA-256 | `be4bc7cfc53f7bc336d0f28b1ab92535f618c913a422b683210750f6b5354854` |
| Size | 5,233,552 bytes |
| Verified graph | input `input` `[1,112,112,3]` float32 → output `embeddings` `[1,192]` float32 |

**Provenance caveat:** the repo ships the file under BSD-3 but does not name the
training run it came from. If a customer contract needs a documented model
lineage, retrain or buy one — this is good enough to ship, not to warrant.

### Measured on LFW (800 standard pairs, 400 same / 400 different)

Fixed centre crop, not ML Kit's box, so read the *separation* rather than the
absolute numbers. Same-person mean cosine **0.597**, different-person mean
**0.044** — the model separates cleanly.

| threshold | impostor accepted | employee rejected | accuracy |
|---|---|---|---|
| 0.30 | 4.2% | 6.5% | 94.6% |
| 0.40 | 0.8% | 16.0% | 91.6% |
| 0.45 | 0.2% | 19.2% | 90.2% |
| **0.65** (`DEFAULT_THRESHOLD`) | **0.0%** | **52.5%** | 73.8% |

**`FaceMatchService::DEFAULT_THRESHOLD = 0.650` is too strict for this model.**
Switching a company to `enforce` at 0.65 would block roughly half of genuine
attempts. LFW is harsher than a deliberate front-facing check-in selfie, so the
real rejection rate will be lower — but not by 50 points. Tune on
`face_verification_logs` before enforcing; ~0.45 is the sane starting point.

## What the model must be

| Property | Required value |
|---|---|
| Format | TensorFlow Lite (`.tflite`) |
| Input | `[1, 112, 112, 3]` float32, normalised to `[-1, 1]` |
| Output | `[1, 192]` float32 embedding |
| Size | ~5 MB |

A MobileFaceNet-style network trained with ArcFace loss is the usual choice.
If you use a model with a different embedding size (FaceNet emits 128), update
`FaceEmbedder._embeddingSize` — the backend already accepts 128, 192 and 512
(`FaceMatchService::ALLOWED_DIMS`).

## Before you ship it

1. **Check the licence.** Many published face models are research-only and are
   not licensed for commercial use. This is a paid product, so the licence has
   to permit it.
2. **Test on real faces first.** Enrol 20–30 people who actually represent your
   users — including darker skin tones, glasses, and hijab — and look at the
   score distribution before trusting the default threshold. Open-source face
   models are known to perform unevenly across demographics.
3. **Keep `mobilefacenet_v1` in sync.** `FaceEmbedder.modelVersion` and
   `FaceMatchService::MODEL_VERSION` must match. Swapping the model without
   bumping both invalidates every enrolled embedding, and employees will be
   told to re-enrol (which is the correct behaviour — but do it deliberately).

## Tuning the threshold

Leave the company in `log_only` mode for ~2 weeks after launch. Every attempt
is scored and stored in `face_verification_logs`; read the distribution with
`v1/attendance/face-logs` (`view: "distribution"`), then set the threshold
on real data and switch to `enforce`.
