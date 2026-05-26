# RedHat Capsule RPM

This repository includes a one-off helper for packaging `RedHat.cap` as a
minimal architecture-independent RPM.

The generated RPM mirrors the public `redhat-cap-1.0.0-1.noarch.rpm` structure:

- package name: `redhat-cap`
- version-release: `1.0.0-1`
- architecture: `noarch`
- target OS header: `linux`
- install path: `/usr/share/redhat-cap/RedHat.cap`
- payload: one directory and one capsule file
- scripts: none
- dependencies: RPM internal `rpmlib(...)` requirements only

## Requirements

Install `rpmbuild` and one SHA-256 tool:

- `sha256sum`
- or `shasum`

## Build

From the repository root:

```bash
packaging/build-capsule-rpm.sh RedHat.cap
```

The output is written to `dist/`:

```text
dist/redhat-cap-1.0.0-1.noarch.rpm
dist/redhat-cap-1.0.0-1.noarch.rpm.sha256
dist/SHA256SUMS
```

## Verify

Verify the RPM's internal digests:

```bash
rpm --checksig --verbose dist/redhat-cap-1.0.0-1.noarch.rpm
```

Expected result:

```text
Header SHA256 digest: OK
Payload SHA256 digest: OK
MD5 digest: OK
```

Verify the release checksum:

```bash
cd dist
sha256sum -c SHA256SUMS
```

Expected result:

```text
redhat-cap-1.0.0-1.noarch.rpm: OK
```

## Optional Overrides

The defaults match the intended `redhat-cap` release artifact. They can be
overridden if needed:

```bash
CAPSULE_RPM_VERSION=1.0.1 \
CAPSULE_RPM_RELEASE=1 \
packaging/build-capsule-rpm.sh RedHat.cap
```

Supported variables:

- `CAPSULE_RPM_NAME`
- `CAPSULE_RPM_VERSION`
- `CAPSULE_RPM_RELEASE`
- `CAPSULE_INSTALL_DIR`
- `CAPSULE_RPM_OUTPUT_DIR`
- `CAPSULE_RPM_TMPDIR`
- `CAPSULE_RPM_TARGET`
