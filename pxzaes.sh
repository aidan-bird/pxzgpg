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

arg_compress='-c'
arg_help_compress='compress using pixz'

usage="
$(basename "${0}" .sh) version: ${version}
DESCRIPTION:
    Parallel AES256 encryption and pixz compressor

USAGE:
    ${me}: OPTIONS FILE
    password is read from stdin

OPTIONS:
    ${arg_verbosity} ${arg_help_verbosity}
    ${arg_quiet} ${arg_help_quiet}
    ${arg_help} ${arg_help_help}
    ${arg_stdout} ${arg_help_stdout}
    ${arg_compress} ${arg_help_compress}

EXAMPLES
    echo 'password1' | ${me} ${arg_compress} file1
    echo 'password1' | ${me} ${arg_compress} file1 ${arg_stdout} > file2${file_extension}
"

log_detail "parsing args"
isWriteStdout=0
isCompress=0
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
        "${arg_compress}")
            isCompress=1
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

log_detail "creating temporaries"
tmp_dir="$(mktemp -d)"
assert_last_program_ok "cannot create temporary folder"
log_detail "tmpdir: ${tmp_dir}"
trap_cmd="rm -rf '${tmp_dir}' ;"
trap "${trap_cmd}" 0 2 3 15

tmp_file="$(mktemp)"
assert_last_program_ok "cannot create temporary file"
log_detail "tmpfile: ${tmp_file}"
trap_cmd="${trap_cmd} rm -f '${tmp_file}' ;"

log_detail "setting up signal handler"
trap "${trap_cmd}" 0 2 3 15
assert_last_program_ok "cannot setup signal handler"

core_count="$(grep -c ^processor /proc/cpuinfo)"
assert_last_program_ok "cannot get core count"
log_detail "found ${core_count} cores."

# get password
log_detail "getting password from stdin"
password="$(getPassword)"
[ "${password}" = '' ] && { log_error_and_die "empty password" ; }

# compress, and then split into chunks
if [ "${isCompress}" -ne 0 ]
then
    log_detail "compressing and splitting"
    pixz -t -p "${core_count}" -9 -i "${src}" | \
        split -n "${core_count}" - "${tmp_dir}/"
else
    log_detail "splitting"
    split -n "${core_count}" "${src}" "${tmp_dir}/"
fi
assert_last_program_ok "compressing or splitting failed"

# encrypt each chunk
log_detail "encrypting chunks"
ls -f -A --zero "${tmp_dir}" | \
    xargs -0 -P "${core_count}" -I '{}' \
    sh -c "gpg -q --output ${tmp_dir}/{}.gpg --passphrase '${password}' --batch --yes --symmetric --cipher-algo AES256 ${tmp_dir}/{} ; rm -f ${tmp_dir}/{} ;"
assert_last_program_ok "encrypt chunks failed"

# combine results sequentially and in-place
log_detail "combining chunks"
tar -cf "${tmp_file}" -T /dev/null
find "${tmp_dir}" -name "*gpg" -print0 | xargs -0 -P 1 -I '{}' \
    sh -c "tar -rf ${tmp_file} -C ${tmp_dir} \$(basename {}) ; rm -f {} ;"
assert_last_program_ok "combining chunks failed"

# write results
if [ "${isWriteStdout}" -ne 0 ] 
then
    outfile=/dev/stdout
else
    outfile="${src}"
fi
log_detail "writing results to ${outfile}"
log_detail "writing magic: ${magic}"
printf '%s' "${magic}" > "${outfile}"
pwHash="$(printf '%s' "${password}" | argon2 "${magic}" -id -r)"
log_detail "writing hash: ${pwHash}"
printf '%s' "${pwHash}" >> "${outfile}"
log_detail "writing main content"
cat "${tmp_file}" >> "${outfile}"

if [ "${isWriteStdout}" -eq 0 ]
then
    log_detail "updating output extension"
    mv "${outfile}" "${outfile}${file_extension}"
fi

exit 0

