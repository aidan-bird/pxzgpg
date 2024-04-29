#!/bin/sh
#
# Aidan Bird (C) 2024
#
# test pxzaes and dpxzaes tools
#

. "$(dirname "${0}")/common.sh"

verbosity_level=2

test_password='123'
test_password2='321'
random_data_source='/dev/urandom'
compression_tool="pxzaes.sh"
decompression_tool="dpxzaes.sh"
source_size='1M'

# setup temporary files
log_detail "setting up temporaries"
source_tmp_file="$(mktemp)"
assert_last_program_ok "cannot create temporary file"
trap_cmd="rm -f '${source_tmp_file}' ;"
trap "${trap_cmd}" 0 2 3 15

test1_tmp_file="$(mktemp)"
assert_last_program_ok "cannot create temporary file"
trap_cmd="${trap_cmd} rm -f '${test1_tmp_file}' ;"
trap "${trap_cmd}" 0 2 3 15

test2_tmp_file="$(mktemp)"
assert_last_program_ok "cannot create temporary file"
trap_cmd="${trap_cmd} rm -f '${test2_tmp_file}' ;"
trap "${trap_cmd}" 0 2 3 15

test3_tmp_file="$(mktemp)"
assert_last_program_ok "cannot create temporary file"
trap_cmd="${trap_cmd} rm -f '${test3_tmp_file}' ;"
trap "${trap_cmd}" 0 2 3 15

test4_tmp_file="$(mktemp)"
assert_last_program_ok "cannot create temporary file"
trap_cmd="${trap_cmd} rm -f '${test4_tmp_file}' ;"
trap_cmd="${trap_cmd} rm -f ${source_tmp_file}${file_extension} ${test1_tmp_file}${file_extension} ${test2_tmp_file}${file_extension} ${test3_tmp_file}${file_extension} ${test4_tmp_file}${file_extension} ;"

trap "${trap_cmd}" 0 2 3 15

log_detail "source: ${source_tmp_file}"
log_detail "test1: ${test1_tmp_file}"
log_detail "test2: ${test2_tmp_file}"
log_detail "test3: ${test3_tmp_file}"
log_detail "test4: ${test4_tmp_file}"
log_detail "final trap command: ${trap_cmd}"

# get random data for use as source
log_detail "setting up source data"
dd if="${random_data_source}" of="${source_tmp_file}" bs="${source_size}" count=1
assert_last_program_ok "cannot get random data from ${random_data_source}"
cp -f "${source_tmp_file}" "${test1_tmp_file}"

# compress & encrypt source and write to another file

log_detail "compressing and encrypting to file"
printf '%s' "${test_password}" | ./"${compression_tool}" -c "${test1_tmp_file}"
assert_last_program_ok "${compression_tool} failed"

# compress & encrypt source and write to stdout
log_detail "compressing and encrypting to stdout"
printf '%s' "${test_password}" | ./"${compression_tool}" -c "${source_tmp_file}" -O > "${test2_tmp_file}"
assert_last_program_ok "${compression_tool} failed"

# decrypt and decompress
printf '%s' "${test_password}" | ./"${decompression_tool}" "${test1_tmp_file}${file_extension}" -O > "${test4_tmp_file}"
assert_last_program_ok "${decompression_tool} failed"

printf '%s' "${test_password}" | ./"${decompression_tool}" "${test1_tmp_file}${file_extension}"
assert_last_program_ok "${decompression_tool} failed"

printf '%s' "${test_password}" | ./"${decompression_tool}" "${test2_tmp_file}" -O > "${test3_tmp_file}"
assert_last_program_ok "${decompression_tool} failed"

# compare results with source
diff "${test3_tmp_file}" "${test1_tmp_file}" || { log_error_and_die "decompressed results differs" ; }
diff "${test3_tmp_file}" "${test4_tmp_file}" || { log_error_and_die "decompressed results differs" ; }
diff "${test3_tmp_file}" "${source_tmp_file}" || { log_error_and_die "decompressed result differs from source" ; }

# test with no compression
#
log_detail "setting up source data"
dd if="${random_data_source}" of="${source_tmp_file}" bs="${source_size}" count=1
assert_last_program_ok "cannot get random data from ${random_data_source}"
cp -f "${source_tmp_file}" "${test1_tmp_file}"

log_detail "compressing and encrypting to file"
printf '%s' "${test_password}" | ./"${compression_tool}" "${test1_tmp_file}"
assert_last_program_ok "${compression_tool} failed"

log_detail "compressing and encrypting to stdout"
printf '%s' "${test_password}" | ./"${compression_tool}" "${source_tmp_file}" -O > "${test2_tmp_file}"
assert_last_program_ok "${compression_tool} failed"

printf '%s' "${test_password}" | ./"${decompression_tool}" "${test1_tmp_file}${file_extension}" -O > "${test4_tmp_file}"
assert_last_program_ok "${decompression_tool} failed"

printf '%s' "${test_password}" | ./"${decompression_tool}" "${test1_tmp_file}${file_extension}"
assert_last_program_ok "${decompression_tool} failed"

printf '%s' "${test_password}" | ./"${decompression_tool}" "${test2_tmp_file}" -O > "${test3_tmp_file}"
assert_last_program_ok "${decompression_tool} failed"

diff "${test3_tmp_file}" "${test1_tmp_file}" || { log_error_and_die "decompressed results differs" ; }
diff "${test3_tmp_file}" "${test4_tmp_file}" || { log_error_and_die "decompressed results differs" ; }
diff "${test3_tmp_file}" "${source_tmp_file}" || { log_error_and_die "decompressed result differs from source" ; }

# test with bad password and no compression
#
log_detail "setting up source data"
dd if="${random_data_source}" of="${source_tmp_file}" bs="${source_size}" count=1
assert_last_program_ok "cannot get random data from ${random_data_source}"
cp -f "${source_tmp_file}" "${test1_tmp_file}"

log_detail "compressing and encrypting to file"
printf '%s' "${test_password}" | ./"${compression_tool}" "${test1_tmp_file}"
assert_last_program_ok "${compression_tool} failed"

log_detail "compressing and encrypting to stdout"
printf '%s' "${test_password}" | ./"${compression_tool}" "${source_tmp_file}" -O > "${test2_tmp_file}"
assert_last_program_ok "${compression_tool} failed"

if printf '%s' "${test_password2}" | ./"${decompression_tool}" "${test1_tmp_file}${file_extension}" -O > "${test4_tmp_file}"
then
    log_error_and_die "bad password test failed"
fi

if printf '%s' "${test_password2}" | ./"${decompression_tool}" "${test1_tmp_file}${file_extension}"
then
    log_error_and_die "bad password test failed"
fi

if printf '%s' "${test_password2}" | ./"${decompression_tool}" "${test2_tmp_file}" -O > "${test3_tmp_file}"
then
    log_error_and_die "bad password test failed"
fi

# test with bad password with compression
#
log_detail "setting up source data"
dd if="${random_data_source}" of="${source_tmp_file}" bs="${source_size}" count=1
assert_last_program_ok "cannot get random data from ${random_data_source}"
cp -f "${source_tmp_file}" "${test1_tmp_file}"

log_detail "compressing and encrypting to file"
printf '%s' "${test_password}" | ./"${compression_tool}" -c "${test1_tmp_file}"
assert_last_program_ok "${compression_tool} failed"

log_detail "compressing and encrypting to stdout"
printf '%s' "${test_password}" | ./"${compression_tool}" -c "${source_tmp_file}" -O > "${test2_tmp_file}"
assert_last_program_ok "${compression_tool} failed"

if printf '%s' "${test_password2}" | ./"${decompression_tool}" "${test1_tmp_file}${file_extension}" -O > "${test4_tmp_file}"
then
    log_error_and_die "bad password test failed"
fi

if printf '%s' "${test_password2}" | ./"${decompression_tool}" "${test1_tmp_file}${file_extension}"
then
    log_error_and_die "bad password test failed"
fi

if printf '%s' "${test_password2}" | ./"${decompression_tool}" "${test2_tmp_file}" -O > "${test3_tmp_file}"
then
    log_error_and_die "bad password test failed"
fi

log_info 'All tests passed!'

