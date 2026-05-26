#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<EOF
Usage: $0 [CAPSULE_FILE]

Build a noarch RPM containing a single capsule file.

Environment overrides:
  CAPSULE_RPM_NAME        Package name (default: redhat-cap)
  CAPSULE_RPM_VERSION     Package version (default: 1.0.0)
  CAPSULE_RPM_RELEASE     Package release (default: 1)
  CAPSULE_INSTALL_DIR     Install directory inside RPM (default: /usr/share/redhat-cap)
  CAPSULE_RPM_OUTPUT_DIR  Output directory (default: dist)
  CAPSULE_RPM_TMPDIR      Temporary build parent (default: /private/tmp)
  CAPSULE_RPM_TARGET      RPM target platform (default: noarch-linux)
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
    exit 0
fi

package_name="${CAPSULE_RPM_NAME:-redhat-cap}"
package_version="${CAPSULE_RPM_VERSION:-1.0.0}"
package_release="${CAPSULE_RPM_RELEASE:-1}"
install_dir="${CAPSULE_INSTALL_DIR:-/usr/share/redhat-cap}"
output_dir="${CAPSULE_RPM_OUTPUT_DIR:-dist}"
tmp_parent="${CAPSULE_RPM_TMPDIR:-/private/tmp}"
rpm_target="${CAPSULE_RPM_TARGET:-noarch-linux}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "${script_dir}/.." && pwd)"
capsule_arg="${1:-${repo_dir}/RedHat.cap}"

if ! command -v rpmbuild >/dev/null 2>&1; then
    echo "error: rpmbuild is required" >&2
    exit 1
fi

if [ ! -f "${capsule_arg}" ]; then
    echo "error: capsule file not found: ${capsule_arg}" >&2
    exit 1
fi

capsule_dir="$(cd "$(dirname "${capsule_arg}")" && pwd)"
capsule_base="$(basename "${capsule_arg}")"
capsule_path="${capsule_dir}/${capsule_base}"

case "${capsule_base}" in
    *[!A-Za-z0-9._+-]*)
        echo "error: capsule filename must contain only letters, numbers, dot, underscore, plus, or dash: ${capsule_base}" >&2
        exit 1
        ;;
esac

case "${package_name}" in
    *[!A-Za-z0-9._+-]*)
        echo "error: package name must contain only letters, numbers, dot, underscore, plus, or dash: ${package_name}" >&2
        exit 1
        ;;
esac

if [[ "${package_version}" == *-* ]]; then
    echo "error: CAPSULE_RPM_VERSION must not contain '-': ${package_version}" >&2
    exit 1
fi

if [[ "${package_release}" == *-* ]]; then
    echo "error: CAPSULE_RPM_RELEASE must not contain '-': ${package_release}" >&2
    exit 1
fi

mkdir -p "${tmp_parent}"
workdir="$(mktemp -d "${tmp_parent}/capsule-rpm.XXXXXX")"
trap 'rm -rf "${workdir}"' EXIT

mkdir -p "${workdir}/BUILD" "${workdir}/BUILDROOT" "${workdir}/RPMS" "${workdir}/SOURCES" "${workdir}/SPECS" "${workdir}/SRPMS" "${workdir}/tmp"
case "${output_dir}" in
    /*)
        mkdir -p "${output_dir}"
        ;;
    *)
        mkdir -p "${repo_dir}/${output_dir}"
        output_dir="${repo_dir}/${output_dir}"
        ;;
esac

output_dir="$(cd "${output_dir}" && pwd)"

cp "${capsule_path}" "${workdir}/SOURCES/${capsule_base}"

spec_file="${workdir}/SPECS/capsule-rpm.spec"
{
    printf '%%{!?capsule_filename:%%global capsule_filename RedHat.cap}\n'
    printf '%%{!?capsule_install_dir:%%global capsule_install_dir /usr/share/redhat-cap}\n'
    printf '%%{!?capsule_rpm_name:%%global capsule_rpm_name redhat-cap}\n'
    printf '%%{!?capsule_rpm_version:%%global capsule_rpm_version 1.0.0}\n'
    printf '%%{!?capsule_rpm_release:%%global capsule_rpm_release 1}\n\n'
    printf 'Name: %%{capsule_rpm_name}\n'
    printf 'Version: %%{capsule_rpm_version}\n'
    printf 'Release: %%{capsule_rpm_release}\n'
    printf 'Summary: RedHat.cap data file packaged for distribution\n'
    printf 'License: Proprietary\n'
    printf 'URL: https://github.com/openshift-dpf\n'
    printf 'BuildArch: noarch\n'
    printf 'AutoReqProv: no\n'
    printf 'Source0: %%{capsule_filename}\n\n'
    printf '%%description\n'
    printf 'Packages the RedHat.cap data file and installs it under\n'
    printf '%%{capsule_install_dir}/ on the target system.\n\n'
    printf '%%prep\n'
    printf '# Nothing to prepare.\n\n'
    printf '%%build\n'
    printf '# Nothing to build.\n\n'
    printf '%%install\n'
    printf 'rm -rf %%{buildroot}\n'
    printf 'install -Dpm 0644 %%{SOURCE0} %%{buildroot}%%{capsule_install_dir}/%%{capsule_filename}\n\n'
    printf '%%files\n'
    printf '%%dir %%{capsule_install_dir}\n'
    printf '%%{capsule_install_dir}/%%{capsule_filename}\n'
} > "${spec_file}"

rpmbuild -bb "${spec_file}" \
    --target "${rpm_target}" \
    --define "_topdir ${workdir}" \
    --define "_tmppath ${workdir}/tmp" \
    --define "capsule_filename ${capsule_base}" \
    --define "capsule_install_dir ${install_dir}" \
    --define "capsule_rpm_name ${package_name}" \
    --define "capsule_rpm_version ${package_version}" \
    --define "capsule_rpm_release ${package_release}"

rpm_path="$(find "${workdir}/RPMS/noarch" -type f -name '*.rpm' -print -quit)"
if [ -z "${rpm_path}" ]; then
    echo "error: rpmbuild completed but no noarch RPM was found" >&2
    exit 1
fi

rpm_file="$(basename "${rpm_path}")"
cp "${rpm_path}" "${output_dir}/${rpm_file}"

if command -v sha256sum >/dev/null 2>&1; then
    (cd "${output_dir}" && sha256sum "${rpm_file}" > "${rpm_file}.sha256")
elif command -v shasum >/dev/null 2>&1; then
    (cd "${output_dir}" && shasum -a 256 "${rpm_file}" > "${rpm_file}.sha256")
else
    echo "error: sha256sum or shasum is required" >&2
    exit 1
fi

cp "${output_dir}/${rpm_file}.sha256" "${output_dir}/SHA256SUMS"

echo "RPM: ${output_dir}/${rpm_file}"
echo "SHA256: ${output_dir}/${rpm_file}.sha256"
echo "SHA256SUMS: ${output_dir}/SHA256SUMS"
