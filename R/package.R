is_cran_repo_url <- function(package_input) {
  is_tarball <- grepl("[.]tar[.]gz$", package_input)

  has_src_contrib <- grepl("/src/contrib/", package_input)

  is_tarball && has_src_contrib
}

is_git_repo_url <- function(package_input) {
  tryCatch({
    is.character(get_provider(package_input))
  }, error = function(e) {
    FALSE
  })
}

normalize_package <- function(package) {
  if (is_cran_repo_url(package)) {
    package_dir <- file.path(tempfile(), digest::digest(repo_stub(package)))

    utils::download.file(package, package_dir)
  } else if (is_git_repo_url(package)) {
    token <- get_token(package)

    package_dir <- file.path(tempfile(), digest::digest(repo_stub(package)))
    git2r::clone(url = package, local_path = package_dir,
                 credentials = git2r::cred_token(token))
  } else if (file.exists(package)) {
    package_dir <- package
  } else {
    stop("Not able to identify source type of ", package)
  }

  package_dir
}

#' Add a package to a repository
#'
#' To use this, the user must have a personal access token (PAT) from the git
#' provider must be generated for reading and writing.
#'
#' @param repo character - A repository URL or local directory with a remote.
#' @param package character - An R package in a directory, a git remote to a
#' repo containing an R package, or a link to a package in a CRAN repo.
#' @param branch character - The branch of the gitCRAN repository to write to.
#' @param type character - What directory to group the repository under. If not
#' "source", the default, then it compiles the package as a binary but still
#' adds it to the {type}/src/contrib/ directory.
#' @param token character - The personal access token (PAT) for reading/writing
#' to the repository.
#'
#' @export
#'
#' @examples
#' \dontrun{
#'   add_package(
#'     "github.com/thomascjohnson/testCRAN",
#'     "github.com/thomascjohnson/gitCRAN",
#'     branch = "dev",
#'     type = "cflinuxfs3"
#'   )
#' }
add_package <- function(repo = ".", package, branch = "master",
                        type = "source", token = NULL) {
  repo_dir <- get_repo_dir(repo = repo, branch = branch, type = type)

  repo_url <- get_repo_url(repo)

  package <- normalize_package(package)

  package_tmp <- devtools::build(package, binary = (type != "source"))
  cat("Package built\n")
  package_name <- gsub("_.+$", "", basename(package_tmp))

  package_dir <- file.path(repo_dir, type, "src", "contrib")
  package_version <- as.character(read.dcf(file.path(package, "DESCRIPTION"),
                                           fields = "Version"))

  package_tarball <- paste0(package_name, "_", package_version, ".tar.gz")

  file.copy(package_tmp, file.path(package_dir, package_tarball))
  file.remove(package_tmp)

  tools::write_PACKAGES(package_dir)
  cat("PACKAGES written to", file.path(package_dir, "PACKAGES"), "\n")

  if (is.null(token)) {
    token_var <- get_token(repo_url)
  } else {
    Sys.setenv("PACKAGE_TOKEN" = token)
    token_var <- "PACKAGE_TOKEN"
  }

  withr::with_dir(repo_dir, {
    git2r::add(repo = repo_dir,
               path = file.path(type, "src", "contrib", "PACKAGES*"))

    git2r::add(repo = repo_dir,
               path = file.path(type, "src", "contrib", package_tarball))
  })


  git2r::commit(repo = repo_dir, paste("Adds", package_name))
  git2r::push(object = repo_dir, credentials = git2r::cred_token(token_var),
              name = "origin", refspec = "refs/heads/master")
}
