context("Tests remote processing")

remote_gitdir <- make_temp_subdir("remote-repo")

git2r::init(remote_gitdir)
git2r::remote_set_url(remote_gitdir, name = "origin",
                      url = correct_remote_https)

test_that("make_https_remote", {
  expect_equal(make_https_remote(correct_remote_https), correct_remote_https)

  expect_equal(make_https_remote(remote_stripped), correct_remote_https)

  expect_equal(make_https_remote("http://github.com/thomascjohnson/gitCRAN"),
               correct_remote_https)

  expect_equal(make_https_remote(correct_remote_ssh), correct_remote_https)

  expect_equal(make_https_remote(correct_remote_ssh), correct_remote_https)

  expect_error(make_https_remote("blah"))
})

test_that("remote_from_repo generates correct remote", {
  expect_equal(remote_from_repo(remote_stripped), correct_remote_ssh)
  expect_equal(remote_from_repo(remote_stripped, type = "ssh"),
               correct_remote_ssh)
  expect_equal(remote_from_repo(remote_stripped, type = "https"),
               correct_remote_https)
  expect_error(remote_from_repo("google.com"))
})

test_that("is_https_remote and is_ssh_remote", {
  expect_true(is_ssh_remote(correct_remote_ssh))
  expect_false(is_ssh_remote(correct_remote_https))

  expect_true(is_https_remote(correct_remote_https))
  expect_false(is_https_remote(correct_remote_ssh))
})
