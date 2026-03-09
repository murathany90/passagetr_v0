# Faz 8 Verification

- Yerel kalite kapisi: `scripts/quality_gate.ps1`
- RLS smoke: `scripts/verify_supabase_rls.ps1 -RefreshAccounts`
- CI workflow: `.github/workflows/quality-gates.yml`
- Kapsanan adimlar:
  - `flutter analyze`
  - `flutter test packages/shared_data`
  - `flutter test apps/student_app`
  - `flutter test apps/admin_console`
  - `build_web_firebase.ps1` ile student/admin web build
  - `flutter build apk --debug`
  - Gercek Supabase RLS smoke
