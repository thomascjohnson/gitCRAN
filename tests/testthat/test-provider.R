context("Test providers functionality")

test_that("get_provider gets correct git provider", {
  expect_equal(get_provider("github.com/blah/blah"), "github")
  expect_error(get_provider("gitblub.com/blah/blah"))
  expect_equal(get_provider("gitlab"), "gitlab")
})