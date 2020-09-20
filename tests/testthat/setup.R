make_temp_subdir <- function(name) {
  repo_dir <- file.path(normalized_tempdir(),  "gitCRAN-tests", name)

  dir.create(repo_dir, recursive = TRUE)

  repo_dir
}

remote_stub <- "thomascjohnson/gitCRAN"
remote_stripped <- "github.com/thomascjohnson/gitCRAN"
correct_remote_https <- "https://github.com/thomascjohnson/gitCRAN.git"
correct_remote_ssh <- "git@github.com:thomascjohnson/gitCRAN.git"