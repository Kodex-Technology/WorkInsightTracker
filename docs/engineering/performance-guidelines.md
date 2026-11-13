# Performance guidelines

- Sample on 10s timer — not per-input UI updates for every key
- Batch DB writes where safe (transaction per sample batch)
- Index hot query columns (see database design)
- Screenshot encode off UI isolate/thread
- Avoid Drift queries inside widget `build`
- Profile before adding performance infrastructure
- Target: negligible CPU when paused/stopped; modest when tracking idle desktop
