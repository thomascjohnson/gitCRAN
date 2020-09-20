context("Test repo functions")

repo_gitdir <- make_temp_subdir("repo")

repo_notgitdir <- make_temp_subdir("notrepo")

git2r::clone(correct_remote_https, repo_gitdir, progress = FALSE)

test_that("repo_stub", {
  expect_equal(repo_stub(correct_remote_https), remote_stub)
  expect_equal(repo_stub(correct_remote_ssh), remote_stub)
  expect_error(repo_stub("blah"))
})

test_that("has_remote", {
  expect_error(has_remote(repo_notgitdir))
  expect_true(has_remote(repo_gitdir))
})

test_that("get_repo_url", {
  expect_equal(get_repo_url(repo_gitdir), correct_remote_https)
  expect_equal(get_repo_url(correct_remote_ssh), correct_remote_https)
})


test_that("get_repo_dir", {
  expect_error(get_repo_dir(repo_notgitdir))
  expect_equal(get_repo_dir(repo_gitdir, "master"), repo_gitdir)
  expect_equal(
    git2r::remote_url(get_repo_dir(correct_remote_https, "master", "source")),
    correct_remote_https
  )

  git_init <- make_temp_subdir("gitinit")
  git2r::init(git_init)
  expect_error(get_repo_dir(git_init))

  git_nobranch <- make_temp_subdir("git_nobranch")
  git2r::init(git_nobranch)
  git2r::remote_add(git_nobranch, "origin", correct_remote_https)

  expect_error(get_repo_dir(git_nobranch))

  expect_output(get_repo_dir("github.com/thomascjohnson/thisrepodoesntexist",
                             "master", "source"),
                "Issue cloning repo. Initiating repo and adding remote.",
                fixed = TRUE)
})

test_that("functions work without remote in repo", {
  git2r::remote_remove(repo_gitdir, "origin")

  expect_false(has_remote(repo_gitdir))
  expect_error(get_repo_url(repo_notgitdir))
  expect_error(get_repo_url(repo_gitdir))
  expect_error(get_repo_dir(repo_gitdir))

  git2r::remote_set_url(repo_gitdir, name = "origin",
                        url = correct_remote_https)
})

test_that("create_CRAN_structure", {
  cran_test_dir <- make_temp_subdir("CRANtest")
  create_CRAN_structure(cran_test_dir, "source")
  expect_true(file.exists(file.path(cran_test_dir, "source", "src", "contrib")))
})