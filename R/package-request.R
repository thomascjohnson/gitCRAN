get_issues <- function(owner, repo, labels = NULL,
                       state = c("open", "closed", "all"),
                       username = Sys.getenv("GITHUB_USER"),
                       token = Sys.getenv("GITHUB_PAT")) {
  state <- match.arg(state)

  uri <- sprintf("/repos/%s/%s/issues", owner, repo)

  if (!is.null(labels)) labels <- paste0(labels, collapse = ",")

  issues_req <- httr::GET(
    paste0("https://api.github.com", uri),
    query = list(labels = labels, state = state),
    httr::authenticate(username, token)
  )

  httr::content(issues_req, as = "parsed")
}

filter_issues <- function(issues) {
  issues
}

get_packages <- function(owner, repo, labels = "package-request",
                         state = "open", username = Sys.getenv("GITHUB_USER"),
                         token = Sys.getenv("GITHUB_PAT")) {
  issues <- filter_issues(
    get_issues(owner, repo, labels, state, username, token)
  )

  raw_requests <- lapply(issues, function(issue) parse_package_request(issue$body))

  Reduce(c, raw_requests)
}

read_dcf_text <- function(txt, fields = NULL, all = FALSE, keep.white = NULL) {
  tf <- tempfile()
  on.exit(file.remove(tf))
  writeLines(txt, tf)
  read.dcf(tf, fields, all, keep.white)
}

parse_package_request <- function(issue_body) {
  issue_dcf <- read_dcf_text(issue_body)[1, 1]

  if (!setequal("Package", names(issue_dcf)))
    stop("Missing 'Package' field from request. Aborting.")

  packages_csv <- issue_dcf[["Package"]]

  unique(strsplit(packages_csv, ",\\s*")[[1]])
}

get_api_user <- function(username, token) {
  user_resp <- httr::GET(
    paste0("https://api.github.com", "/user"),
    httr::authenticate(username, token)
  )

  httr::content(user_resp, as = "parsed")
}

#' Handle Package Requests from Issues Automatically
#'
#' Given the
#'
#' @param owner character - Github organization/user name, defaults to the
#' environment variable GITCRAN_REPO_OWNER
#' @param gh_repository character, the repository name, defaults to the
#' environment variable GITCRAN_REPO
#' @param labels character vector - Github issue labels to search for package
#' requests, defaults to the environment variable GITCRAN_LABELS
#' @param state character - Issue state, "open" or "closed", defaults to the
#' environment variable GITCRAN_STATE or "open"
#' @param username character - Github username that has access to repository
#' issues, defaults to the environment variable GITHUB_USER
#' @param token character - Github Personal Access TOKEN (PAT) for the provided
#' username with repository read and write permissions, defaults to the
#' environment variable GITHUB_PAT
#'
#' @export
package_request_pipeline <- function(
  owner = Sys.getenv("GITCRAN_REPO_OWNER"),
  gh_repository = Sys.getenv("GITCRAN_REPO"),
  labels = Sys.getenv("GITCRAN_LABELS", "package-request"),
  state = Sys.getenv("GITCRAN_STATE", "open"),
  username = Sys.getenv("GITHUB_USER"),
  token = Sys.getenv("GITHUB_PAT")
) {
  stopifnot(nchar(owner) > 0)
  stopifnot(nchar(gh_repository) > 0)
  stopifnot(all(nchar(labels) > 0))
  stopifnot(nchar(state) > 0)
  stopifnot(nchar(username) > 0)
  stopifnot(nchar(token) > 0)

  packages <- do.call(
    get_packages,
    list(owner = owner, repo = gh_repository, labels = labels, state = state,
         username = username, token = token)
  )

  CRAN_repo <- Sys.getenv("CRAN_REPO", "cloud.r-project.org")

  local_repository <- file.path(tempdir(), "gitCRAN")

  dir.create(local_repository)

  repo_remote <- sprintf("https://github.com/%s/%s", owner, gh_repository)

  git2r_repo <- git2r::clone(repo_remote, local_repository)

  api_user <- get_api_user(username, token)

  git2r::config(git2r_repo, user.name = api_user$login,
                user.email = api_user$email)

  CRANpiled::create_repository(local_repository)

  available_packages <- available.packages(repos = CRAN_repo)

  packages_added <- CRANpiled::add_packages(
    packages, local_repository,
    available_packages,
    compile = TRUE,
    quiet = FALSE
  )

  git2r::add(git2r_repo, ".")

  git2r::commit(
    git2r_repo, paste("Adds", packages_added, collapse = ", ")
  )

  git2r::push(git2r_repo, credentials = cred_user_pass(username, token))
}



