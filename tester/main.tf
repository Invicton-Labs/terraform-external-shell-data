locals {
  test_file_path = "${path.module}/../tests/"
  // The ternary within the fileset just forces TF to wait for the delete_existing_files module before going any further
  test_files = fileset(local.test_file_path, "${local.test_file_path}**.json")
  platform   = dirname("/") == "\\" ? "windows" : "unix"
  tests = {
    for test_file in local.test_files :
    replace(replace(trimsuffix(trimprefix(test_file, local.test_file_path), ".json"), "\\", "/"), "/", "_") => jsondecode(file("${local.test_file_path}${test_file}"))
  }

  tests_fields = {
    for name, config in local.tests :
    name => keys(config)
  }

  expected_output_fields = ["expected_stdout", "expected_stderr", "expected_exit_code", "expected_stdout_sensitive", "expected_stderr_sensitive"]

  tests_invalid_fields = {
    for name, keys in local.tests_fields :
    name => [
      for field in keys :
      field
      if !contains(concat([
        "command_unix",
        "command_windows",
        "environment",
        "environment_sensitive",
        "working_dir",
        "timeout",
        "fail_on_nonzero_exit_code",
        "fail_on_stderr",
        "fail_on_timeout",
        "suppress_console",
        "platforms",
      ], local.expected_output_fields), field)
    ]
  }

  invalid_fields_errs = [
    for name, fields in local.tests_invalid_fields :
    "${name} (${join(", ", fields)})"
    if length(fields) > 0
  ]

  invalid_fields_err_msg = length(local.invalid_fields_errs) > 0 ? "The following tests have invalid fields: ${join("; ", local.invalid_fields_errs)}" : null

  tests_without_expected_output = [
    for name, keys in local.tests_fields :
    name
    if length(setintersection(keys, local.expected_output_fields)) == 0
  ]

  missing_expected_output_err_msg = length(local.tests_without_expected_output) > 0 ? "The following tests are missing an expected output field (each test must have one of: ${join(", ", local.expected_output_fields)}): ${join(", ", local.tests_without_expected_output)}" : null

  tests_to_run = {
    for name, config in local.tests :
    name => config
    if contains(lookup(config, "platforms", ["windows", "unix"]), local.platform)
  }
}

module "assert_test_fields_valid" {
  source        = "Invicton-Labs/assertion/null"
  version       = "~>0.2.3"
  condition     = local.invalid_fields_err_msg == null
  error_message = local.invalid_fields_err_msg
}

module "assert_expected_output_fields" {
  source        = "Invicton-Labs/assertion/null"
  version       = "~>0.2.3"
  condition     = local.missing_expected_output_err_msg == null
  error_message = local.missing_expected_output_err_msg
}

module "tests" {
  source                    = "../"
  for_each                  = module.assert_test_fields_valid.checked && module.assert_expected_output_fields.checked ? local.tests_to_run : null
  command_unix              = lookup(each.value, "command_unix", null)
  command_windows           = lookup(each.value, "command_windows", null)
  environment               = lookup(each.value, "environment", null)
  environment_sensitive     = lookup(each.value, "environment_sensitive", null)
  working_dir               = lookup(each.value, "working_dir", null)
  timeout                   = lookup(each.value, "timeout", null)
  fail_on_nonzero_exit_code = lookup(each.value, "fail_on_nonzero_exit_code", null)
  fail_on_stderr            = lookup(each.value, "fail_on_stderr", null)
  fail_on_timeout           = lookup(each.value, "fail_on_timeout", null)
  suppress_console          = lookup(each.value, "suppress_console", null)
  unix_interpreter          = var.unix_interpreter
  //force_wait_for_apply      = true
  //execution_id              = each.key
}

locals {
  tf_version_supports_nonsensitive = can(nonsensitive(sensitive("hello world")))

  incorrect_outputs = {
    for name, config in local.tests_to_run :
    name => flatten([
      contains(local.tests_fields[name], "expected_stdout") ? config.expected_stdout != module.tests[name].stdout ? ["Incorrect value for stdout: expected \"${config.expected_stdout}\", got \"${module.tests[name].stdout}\""] : [] : [],
      contains(local.tests_fields[name], "expected_stderr") ? config.expected_stderr != module.tests[name].stderr ? ["Incorrect value for stderr: expected \"${config.expected_stderr}\", got \"${module.tests[name].stderr}\""] : [] : [],
      contains(local.tests_fields[name], "expected_exit_code") ? config.expected_exit_code != module.tests[name].exit_code ? ["Incorrect value for exit code: expected \"${config.expected_exit_code == null ? "null" : config.expected_exit_code}\", got \"${module.tests[name].exit_code == null ? "null" : module.tests[name].exit_code}\""] : [] : [],
      local.tf_version_supports_nonsensitive ? [
        contains(local.tests_fields[name], "expected_stdout_sensitive") ? (
          config.expected_stdout_sensitive ? (
            // If we expect it to be sensitive, make sure we can nonsensitive it
            !can(nonsensitive(module.tests[name].stdout)) ? ["Incorrect sensitivity for stdout: expected a sensitive value, but received a non-sensitive value."] : []
            ) : (
            // If we expect it to be nonsensitive, make sure we can NOT nonsensitive it
            can(nonsensitive(module.tests[name].stdout)) ? ["Incorrect sensitivity for stdout: expected a non-sensitive value, but received a sensitive value."] : []
          )
        ) : [],
        contains(local.tests_fields[name], "expected_stderr_sensitive") ? (
          config.expected_stderr_sensitive ? (
            // If we expect it to be sensitive, make sure we can nonsensitive it
            !can(nonsensitive(module.tests[name].stderr)) ? ["Incorrect sensitivity for stderr: expected a sensitive value, but received a non-sensitive value."] : []
            ) : (
            // If we expect it to be nonsensitive, make sure we can NOT nonsensitive it
            can(nonsensitive(module.tests[name].stderr)) ? ["Incorrect sensitivity for stderr: expected a non-sensitive value, but received a sensitive value."] : []
          )
        ) : [],
      ] : []
    ])
  }

  incorrect_output_err_msgs = {
    for name, incorrect_outputs in local.incorrect_outputs :
    name => join("\n", incorrect_outputs)
    if length(incorrect_outputs) > 0
  }

  incorrect_output_err_msg = length(local.incorrect_output_err_msgs) > 0 ? "At least one test has outputs that do not match the expected values.\n${join("\n\n", [for k, v in local.incorrect_output_err_msgs : "${k}:\n${v}"])}" : null
}

module "assert_expected_output" {
  source        = "Invicton-Labs/assertion/null"
  version       = "~>0.2.3"
  condition     = local.incorrect_output_err_msg == null
  error_message = try(nonsensitive(local.incorrect_output_err_msg), local.incorrect_output_err_msg)
}

output "checked" {
  value = module.assert_expected_output.checked
}
