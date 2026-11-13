# Screen specifications

Phase 1 screens (wire real behavior as milestones unlock):

| Screen | Route (planned) | Milestone |
|---|---|---|
| Splash | `/splash` | M0 |
| Welcome | `/welcome` | M0/M1 |
| Login | `/login` | M1 |
| Auth pending / callback | `/auth/pending`, `/auth/callback` | M1 (prepared) |
| Permissions onboarding | `/onboarding/permissions` | M1 |
| Dashboard | `/app/dashboard` | M0 shell / M5 data |
| Active session | `/app/session` | M3+ |
| Timeline | `/app/timeline` | M5 |
| Screenshots | `/app/screenshots` | M4 |
| App usage | `/app/apps` | M5 |
| Daily / weekly reports | `/app/reports/daily`, `…/weekly` | M5 |
| Account | `/app/account` | M1 |
| Settings groups | `/app/settings/...` | M2 |
| Diagnostics | `/app/diagnostics` | M6 |
| Offline / sync status | `/app/sync` | M2+ |
| Error / recovery | `/recovery` | M6 |

Shell: premium sidebar + compact top bar. Empty states until data layer exists — never fake metrics.
