# Firebase Data Connect

**Last updated:** 2026-04-03 UTC

## Repo configuration

| Artifact | Location / value |
|----------|-------------------|
| Firebase default project | `.firebaserc` → **`envi-by-informal-staging`** |
| `firebase.json` | **Not present** in repo — CLI hosting/functions/dataconnect wiring may need to be added for standard `firebase deploy` flows |
| Data Connect spec | `dataconnect/dataconnect.yaml` |

## Service (`dataconnect.yaml`)

- **specVersion:** `v1`
- **serviceId:** `envi-ios-v20`
- **location:** `us-west2`
- **Database:** PostgreSQL `fdcdb` on Cloud SQL instance id **`envi-ios-v20-fdc`**
- **Connectors:** `./example` only

## GraphQL schema summary

File: `dataconnect/schema/schema.gql`

Tables: **User**, **Project**, **MediaAsset**, **ProjectClip**, **Effect**, **Template** (see [Models & data](Models-and-Data) for field list).

## Example connector operations (`example/queries.gql`)

| Operation | Type | `@auth` | Description |
|-----------|------|---------|-------------|
| `ListAllProjects` | query | USER | Lists projects with id, name, createdAt, user.displayName |
| `CreateMediaAsset` | mutation | USER | Inserts media row; `userId_expr: auth.uid`, `createdAt_expr: request.time` |
| `GetTemplateDetails` | query | PUBLIC | Template by UUID — **review for production** (`insecureReason` in source) |
| `UpdateProjectName` | mutation | USER | Updates project name + `updatedAt` |

## Seed data (`seed_data.gql`)

- **Mutation:** `CreateDemoData`
- **`@transaction`**, **`@auth(level: PUBLIC)`** — inserts fixed UUID demo users, project, media, clip, effect, template
- **Warning:** Public seed — not for production exposure without hardening

## iOS integration status

- **No** Swift imports of Firebase / Data Connect.
- **No** `GoogleService-Info.plist` in repository (as of doc date).
- **Next steps to integrate:** Add Firebase iOS SDK, Data Connect client per current Firebase docs, plist, generated connector SDK from `example` connector, and map app models to GraphQL operations.

---

Update this page when `firebase.json` is added, connectors change, or the app begins calling these operations.
