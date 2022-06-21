variable "unix_interpreter" {
  type    = string
  default = null
}

locals {
  test_string = "hello world"
}

module "test_1" {
  source                    = "../"
  command_unix              = "echo -n \"$TEST_STRING\""
  fail_on_stderr            = true
  fail_on_nonzero_exit_code = true
  unix_interpreter          = var.unix_interpreter
  environment = {
    TEST_STRING = local.test_string
  }
}

module "check_test_1" {
  source        = "Invicton-Labs/assertion/null"
  version       = "~>0.2.1"
  condition     = module.test_1.stdout == local.test_string
  error_message = "Test 1: Expected stdout of \"${local.test_string}\", but got \"${module.test_1.stdout}\""
}

module "test_2" {
  source                    = "../"
  command_unix              = ">&2 echo -n \"$TEST_STRING\""
  fail_on_stderr            = true
  fail_on_nonzero_exit_code = true
  unix_interpreter          = var.unix_interpreter
  environment = {
    TEST_STRING = local.test_string
  }
}

module "check_test_2" {
  source        = "Invicton-Labs/assertion/null"
  version       = "~>0.2.1"
  condition     = module.test_2.stderr == local.test_string
  error_message = "Test 2: Expected stderr of \"${local.test_string}\", but got \"${module.test_2.stderr}\""
}

locals {
  test_exit_code = 123
}

module "test_3" {
  source                    = "../"
  command_unix              = <<EOF
exit ${test_exit_code}
EOF
  fail_on_stderr            = true
  fail_on_nonzero_exit_code = false
  unix_interpreter          = var.unix_interpreter
  environment = {
    TEST_STRING = local.test_string
  }
}

module "check_test_3" {
  source        = "Invicton-Labs/assertion/null"
  version       = "~>0.2.1"
  condition     = module.test_3.exit_code == local.test_exit_code
  error_message = "Test 3: Expected exit code of \"${local.test_exit_code}\", but got \"${module.test_3.exit_code}\""
}
