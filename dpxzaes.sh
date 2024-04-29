#!/bin/sh
#
# Aidan Bird (C) 2024
#

# FILE FORMAT
#
# magic
# argon2id of password
# tar containing AES256 encrypted chunks
#

. "$(dirname "${0}")/common.sh"

usage="
$(basename "${0}" .sh) version: ${version}
DESCRIPTION:
    Parallel AES256 decryption and pixz decompressor

USAGE:
    ${me}: OPTIONS FILE${file_extension}
    password is read from stdin

OPTIONS:
    ${arg_verbosity} ${arg_help_verbosity}
    ${arg_quiet} ${arg_help_quiet}
    ${arg_help} ${arg_help_help}
    ${arg_stdout} ${arg_help_stdout}

EXAMPLES
    echo 'password1' | ${me} file1${file_extension}
    echo 'password1' | ${me} file1${file_extension} ${arg_stdout} > file1
"

log_detail "parsing args"
isWriteStdout=0
src=''
[ "${#}" -eq 0 ] && { log_usage_and_die ; }
for x in "${@}"
do
    case "${x}" in
        "${arg_verbosity}")
            verbosity_level=2
            ;;
        "${arg_quiet}")
            verbosity_level=0
            ;;
        "${arg_help}")
            log_usage_and_die
            ;;
        "${arg_stdout}")
            isWriteStdout=1
            ;;
        *)
            src="${x}"
            ;;
    esac
done

log_detail "Version: ${version}"

[ "${src}" = '' ] && { log_error_and_die "empty input file" ; }
log_detail "Target: ${src}"

# check magic
log_detail "checking magic"
log_detail "expected magic: ${magic}"
magicLen="$(printf '%s' "${magic}" | wc -c)"
inputMagic="$(dd count="${magicLen}" if="${src}" bs=1 status=none)"
log_detail "file magic: ${inputMagic}"
[ "${magic}" != "${inputMagic}" ] && { log_error_and_die "bad magic; not a pxzgpg file?" ; }

# get password
log_detail "getting password from stdin"
password="$(getPassword)"

# check password
log_detail "checking password"
pwHash="$(printf '%s' "${password}" | argon2 "${magic}" -id -r)"
log_detail "password hash: ${pwHash}"
expectedHash="$(dd skip="${magicLen}" count="${pwHashLen}" if="${src}" bs=1 status=none)"
log_detail "expected hash: ${expectedHash}"
[ "${expectedHash}" != "${pwHash}" ] && { log_error_and_die "bad password" ; }

# extract main content
log_detail "creating temporaries"
tmp_dir="$(mktemp -d)"
assert_last_program_ok "cannot create temporary folder"
log_detail "tmpdir: ${tmp_dir}"
tmp_file="$(mktemp --suffix=.xz)"
assert_last_program_ok "cannot create temporary file"
log_detail "tmpfile: ${tmp_file}"
decompressed_path="$(dirname "${tmp_file}")/$(basename "${tmp_file}" .xz)"

log_detail "setting up signal handler"
trap "rm -rf '${tmp_dir}' ; rm -f '${tmp_file}' '${decompressed_path}' ;" 0 2 3 15
assert_last_program_ok "cannot setup signal handler"

tarStartIdx=$(("${magicLen}" + "${pwHashLen}" + 1))

tail -c "+${tarStartIdx}" "${src}" | tar -xf - -C "${tmp_dir}"
assert_last_program_ok "extracting tar failed"

core_count="$(grep -c ^processor /proc/cpuinfo)"
assert_last_program_ok "cannot get core count"
log_detail "found ${core_count} cores."

# decrypt chunks
log_detail "decrypting chunks"
ls -f -A --zero "${tmp_dir}" | \
    xargs -0 -P "${core_count}" -I '{}' \
    sh -c "gpg -q --output ${tmp_dir}/\$(basename {} .gpg) --passphrase '${password}' -q --batch --yes -d ${tmp_dir}/{} ; rm -f ${tmp_dir}/{} ;"
assert_last_program_ok "decrypting chunks failed"

# assemble chunks in order
log_detail "assembling chunks"
for x in $(find "${tmp_dir}" -type f -print0 | xargs -0 -I '{}' basename '{}' | sort -g)
do
    y="${tmp_dir}/${x}"
    cat "${y}" >> "${tmp_file}"
    rm -f "${y}"
done

if file "${tmp_file}" | grep -q 'XZ compressed data'
then
    # decompress
    pixz -d "${tmp_file}"
    decompressed_path="$(dirname "${tmp_file}")/$(basename "${tmp_file}" .xz)"
else
    decompressed_path="${tmp_file}"
fi

# write results
if [ "${isWriteStdout}" -ne 0 ] 
then
    outfile=/dev/stdout
else
    outfile="${src}"
fi

# save results
cp -f "${decompressed_path}" "${outfile}"

if [ "${isWriteStdout}" -eq 0 ]
then
    log_detail "remove output extension"
    rename "${file_extension}" '' "${outfile}"
fi

exit 0

