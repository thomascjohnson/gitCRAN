context("Test gitCRAN repo config functions")

example_config <- list(
  Build = FALSE,
  DockerImage = "ubuntu"
)

invalid_config <- list(
  Build = NA,
  DockerImage = "ubuntu"
)

repo_config_file <- tempfile()
invalid_repo_config_file <- tempfile()

test_that("valid_repo_config", {
  expect_true(valid_repo_config(example_config))
  expect_false(valid_repo_config(invalid_config))
  expect_error(valid_repo_config(invalid_config, error_on_invalid = TRUE))
  expect_error(valid_repo_config(list(), error_on_invalid = TRUE))
  expect_true(valid_repo_config(list(), error_on_invalid = FALSE))
})

test_that("write_repo_config writes config correctly", {
  write_repo_config(example_config, repo_config_file)
  expect_error(write_repo_config(invalid_config, invalid_repo_config_file))
  expect_null(
    write_repo_config(invalid_config, invalid_repo_config_file,
                      validate = FALSE)
  )
})

test_that("read_repo_config reads config correctly", {
  expect_equal(read_repo_config(repo_config_file), example_config)
  gitCRAN_config_file <- file.path(dirname(repo_config_file),
                                   gitCRAN:::gitCRAN_repo_config_name)
  file.copy(repo_config_file, gitCRAN_config_file)
  expect_equal(read_repo_config(dirname(gitCRAN_config_file)), example_config)

  writeLines("", gitCRAN_config_file)
  expect_error(read_repo_config(gitCRAN_config_file))
  expect_equal(read_repo_config(gitCRAN_config_file, validate = FALSE), list())
})


test_that("read_repo_config throws error on incorrect config", {
  expect_error(read_repo_config(invalid_repo_config_file))
  expect_equal(read_repo_config(invalid_repo_config_file, validate = FALSE),
               list("DockerImage" = "ubuntu"))
})

test_that("get_repo_config gets correct repo config", {
  expect_error(get_repo_config("/blah"))
  test_repo <- make_temp_subdir("test_repo")
  image <- "ubuntu"
  repo_name <- "testrepo"
  build <- TRUE
  create_CRAN_structure(test_repo, repo_name)
  test_repo_config <- get_repo_config(test_repo, repo_name, image, build)
  expect_equal(test_repo_config$DockerImage, image)
  expect_equal(test_repo_config$Build, build)

  write_repo_config(test_repo_config, test_repo)
  expect_equal(get_repo_config(test_repo), test_repo_config)
})

