context("Test package-related functionality")

cran_url <- "https://cloud.r-project.org/src/contrib/quietR_0.1.0.tar.gz"

# test_that("", {
#
# })

test_that("tarball_to_package_dir", {
  expect_error(tarball_to_package_dir("google.com"))
  package_dir <- tarball_to_package_dir(cran_url)
  expect_true(devtools::is.package(devtools::as.package(package_dir)))
})