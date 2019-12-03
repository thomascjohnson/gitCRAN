repo_stub <- function(repo_remote) {
  remote_tail <- gsub("^(http[s]?://)?[a-z^.]+[.][a-z]{2,3}/", "",
                      repo_remote)

  gsub("[.]git$", "", remote_tail)
}

get_repo_url <- function(repo) {
  if (dir.exists(repo)) {
    repo_dir <- repo

    if (identical(git2r::remote_url(repo_dir), character(0)))
      stop("Provided repo path has no remotes.")

    repo_url <- make_https_remote(git2r::remote_url(repo_dir))
  } else {
    repo_url <- make_https_remote(repo)
  }

  repo_url
}

get_repo_dir <- function(repo, branch, type) {
  if (dir.exists(repo)) {
    repo_dir <- repo

    git2r::pull(repo_dir)
  } else {
    repo_url <- make_https_remote(repo)

    temp_dir <- tempdir()
    repo_dir <- file.path(temp_dir, "gitCRAN", digest::digest(repo_stub(repo)))
    dir.create(repo_dir, recursive = TRUE)

    token <- get_token(repo_url)

    tryCatch({
      git2r::clone(url = repo_url, local_path = repo_dir, branch = branch,
                   credentials = git2r::cred_token(token))
    }, error = function(e) {
      cat("Issue cloning repo. Initiating repo and adding remote.\n")
      git2r::init(repo_dir)
      git2r::remote_set_url(repo_dir, "origin", repo_url)
    })

    create_CRAN_structure(repo_dir, type = type)
  }

  repo_dir
}

create_CRAN_structure <- function(directory, type = "source") {
  dir.create(file.path(directory, type, "src", "contrib"), recursive = TRUE)
}
