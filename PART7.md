# Part 7 — Supabase auth + cloud sync (COMPLETE)

## Init
- Loads SUPABASE_URL + ANON key from assets/env.json
- Fallback to project URL/key so cloud works in release APK

## Auth
- Email + password sign in / sign up (existing screen)
- After login: upload local docs to cloud, open home

## Sync
- Offline-first local cache remains
- When logged in: list merges cloud + local
- Save updates cloud when authenticated
- syncLocalToCloud on login

## Required in Supabase
- Auth email enabled
- Tables: profiles, documents with RLS (user_id = auth.uid())

## Test
1. Settings / Auth → register with email
2. Create doc offline, then login → should upload
3. Another device same account → see docs (if documents table OK)
