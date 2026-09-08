# reaper Release Notes

## 25.0.47

First tagged reaper release on the OTP 25 branch.

**Versioning note:** from here on, reaper's version number tracks otp23's
scheme (`25.x.y` mirroring otp23's `23.x.y`) instead of continuing its own
independent count, so the two branches' reaper releases stay easy to
compare release-for-release. This release brings otp25's reaper up to par
with otp23's `reaper@23.0.47` for the CA cert fix below.

- Fixed ingestion downloads failing with certificate errors against internal/private HTTPS endpoints, by trusting the image's system CA bundle instead of Mint's built-in default (ported from otp23 `reaper@23.0.47`)
- Fixed the `SECRETS_ENDPOINT` environment variable not actually being wired into Vault configuration, added automatic protocol prefixing when it's given without one, and improved startup logging/validation around Vault/secrets configuration
- Added FQDN-based clustering support for Kubernetes deployment and fixed a libcluster cookie mismatch that could prevent reaper nodes from clustering
- Migrated reaper's build and deploy to Elixir's built-in `mix release` (replacing the deprecated Distillery) as part of the underlying Erlang/OTP 25 + Elixir upgrade
