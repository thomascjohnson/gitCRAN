context("token related functionality")

git_cran_config <- Sys.getenv("GIT_CRAN_CONFIG")
Sys.setenv("GIT_CRAN_CONFIG" = tempfile())
set_token("github", "1234")
askpass_option <- getOption("askpass")

test_that("set_token", {
  expect_error(set_token("blah", "blah"))
})

test_that("git_token", {
  expect_error(git_token("blah"))
  .gitCRAN$config$tokens <<- NULL
  expect_error(git_token("blah"))
  expect_equal(git_token("github"), "GITHUB_TOKEN")
})

test_that("token functionality works with empty config", {
  .gitCRAN$config$tokens <<- NULL
  file.remove(Sys.getenv("GIT_CRAN_CONFIG"))

  expect_error(git_token("blah"))
  expect_null(set_token("github", "blah"))
  expect_error(git_token("gitlab"))

  options("askpass" = function(x) { "blah" })
  expect_equal(set_token("github"), NULL)
  options("askpass" = askpass_option)
})

test_that("get_token", {
  expect_error(get_token("google.com"))
  expect_equal(get_token("github.com/blah/blah"), "GITHUB_TOKEN")
})


Sys.setenv("GIT_CRAN_CONFIG" = git_cran_config)