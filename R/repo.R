repo_stub <- function(repo_remote) {
  repo_regex <- "^(((ssh://)?git@)|(http[s]?://))?[a-z^.]+[.][a-z]{2,3}[/:]([^/]+/[^/^.]+)([/.]git)?$"

  if (!grepl(repo_regex, repo_remote))
    stop("Repository remote incorrectly formatted")

  gsub(repo_regex, "\\5", repo_remote)
}

has_remote <- function(repo_dir) {
  if (identical(git2r::remote_url(repo_dir), character(0)))
    FALSE
  else
    TRUE
}

get_repo_url <- function(repo) {
  if (dir.exists(repo)) {
    if (!has_remote(repo))
      stop("Provided repo path has no remotes.")

    repo_url <- make_https_remote(git2r::remote_url(repo))
  } else {
    repo_url <- make_https_remote(repo)
  }

  repo_url
}

get_repo_dir <- function(repo, branch = NULL, type = NULL) {
  if (dir.exists(repo)) {
    if (!has_remote(repo))
      stop("No remote for the repository at ", repo)

    repo_dir <- repo

    repo_dir_branch <- git2r::repository_head(repo_dir)$name

    # Doesn't handle the case that the repo isn't able to checkout the selected
    # branch due to git repo config issues
    if (is.null(branch) && is.null(repo_dir_branch))
      stop("Provide branch as argument or set it in ", repo_dir)
    else if (!is.null(branch))
      git2r::checkout(repo_dir, branch = branch)

    git2r::pull(repo_dir)
  } else {
    repo_url <- make_https_remote(repo)

    temp_dir <- normalized_tempdir()
    repo_dir <- file.path(temp_dir, "gitCRAN", digest::digest(repo_stub(repo)))
    dir.create(repo_dir, recursive = TRUE)

    token <- get_token(repo_url)

    tryCatch({
      git2r::clone(url = repo_url, local_path = repo_dir, branch = branch,
                   credentials = git2r::cred_token(token), progress = FALSE)
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

  file.path(directory, type, "src", "contrib")
}

# initiate_gitCRAN <- function(repo_url, subrepo_name = "source", build = FALSE,
#                              docker_image = NULL) {
#
# }