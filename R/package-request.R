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

get_members <- function(github_org,
                        username = Sys.getenv("GITHUB_USER"),
                        token = Sys.getenv("GITHUB_PAT")) {
  response <- httr::GET(
    sprintf("https://api.github.com/orgs/%s/members", github_org),
    httr::authenticate(username, token)
  )

  sapply(httr::content(response, as = "parsed"), `[[`, "login")
}

filter_issues <- function(
  issues,
  github_org = Sys.getenv("GITCRAN_FILTER_ORG"),
  username = Sys.getenv("GITHUB_USER"),
  token = Sys.getenv("GITHUB_PAT")
) {
  if (github_org == username || github_org == "")
    organization_members <- username
  else
    organization_members <- get_members(github_org, username, token)

  Filter(function(x) x$user$login %in% organization_members, issues)
}

get_package_requests <- function(
  owner,
  repo,
  labels = "package-request",
  state = "open",
  filter_org = Sys.getenv("GITCRAN_FILTER_ORG"),
  username = Sys.getenv("GITHUB_USER"),
  token = Sys.getenv("GITHUB_PAT")
) {
  issues <- filter_issues(
    issues = get_issues(owner, repo, labels, state, username, token),
    github_org = filter_org,
    username = username,
    token = token
  )

  raw_requests <- lapply(
    issues,
    function(issue) parse_package_request(issue$body)
  )

  issue_ids <- sapply(issues, `[[`, "number")

  setNames(raw_requests, issue_ids)
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
#' This pipeline fetches issues from a Github repository and if they follow
#' the form of a package request, the pipeline will try to automatically add
#' the pakges to the repository. If the additions fail, it will comment on the
#' issue with the error message, tag the provided username and close the issue.
#'
#' @param owner character - Github organization/user name, defaults to the
#' environment variable GITCRAN_REPO_OWNER
#' @param gh_repository character - the repository name, defaults to the
#' environment variable GITCRAN_REPO
#' @param subpath character - a path relative to the gh_repository root that
#' contains a CRAN repository. Defaults to "": the root of the repository.
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
  subpath = Sys.getenv("GITCRAN_SUBDIR", ""),
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

  package_requests <- do.call(
    get_package_requests,
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

  if (nchar(subpath) > 0)
    local_repository <- file.path(local_repository, subpath)

  available_packages <- available.packages(repos = CRAN_repo)

  for (package_request_id in names(package_requests)) {
    package_request <- package_requests[[package_request_id]]

    tryCatch({
      cat(paste0("Adding packages from request #", package_request_id))
      packages_added <- CRANpiled::add_packages(
        package_request,
        local_repository,
        available_packages,
        compile = TRUE,
        quiet = FALSE
      )

      git2r::add(git2r_repo, ".")

      git2r::commit(
        git2r_repo,
        paste0(
          "Closes #", package_request_id, " Adds:\n ",
          paste(packages_added, collapse = ", ")
        )
      )

      git2r::push(
        git2r_repo,
        credentials = git2r::cred_user_pass(username, token)
      )
    }, error = function(e) {
      error_comment <- paste0(
        "There was an issue processing your package addition request. ",
        "Tagging @", username, " to debug and closing the issue. ",
        "See the logs:\n",
        "```\n",
        trimws(e)
      )

      cat(paste0("Commenting on and closing issue #", package_request_id))
      create_comment(owner, gh_repository, package_request_id, error_comment,
                     username, token)
      close_issue(owner, gh_repository, package_request_id, username, token)
    })
  }

  cat("Pipeline finished.")
}

create_comment <- function(owner, repository, issue_id, comment, username,
                           token) {
  httr::POST(
    sprintf(
      "https://api.github.com/repos/%s/%s/issues/%s/comments",
      owner, repository, issue_id
    ),
    body = jsonlite::toJSON(list(body = comment), auto_unbox = TRUE),
    httr::authenticate(username, token)
  )
}

close_issue <- function(owner, repository, issue_id, username, token) {
  httr::PATCH(
    sprintf(
      "https://api.github.com/repos/%s/%s/issues/%s",
      owner, repository, issue_id
    ),
    body = jsonlite::toJSON(list(state = "closed"), auto_unbox = TRUE),
    httr::authenticate(username, token)
  )
}



