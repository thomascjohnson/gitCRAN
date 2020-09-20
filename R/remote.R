remote_from_repo <- function(repo_url, type = c("ssh", "https")) {
  type <- match.arg(type)

  remote_converter <- list(
    "ssh" = function(url) {
      paste0("git@", gsub("^([^/]+)/(.+)$", "\\1:\\2", repo_url), ".git")
    },
    "https" = function(url) {
      paste0("https://", repo_url, ".git")
    }
  )

  remote_regex <- "^[a-z^.]{3,}[.][a-z]{2,3}/\\w+/\\w+$"

  if (grepl(remote_regex, repo_url)) {
    remote_converter[[type]](repo_url)
  } else {
    stop("Remote not valid. Should be {provider}.{tld}/{org}/{repo}")
  }
}

make_https_remote <- function(remote_url) {
  remote_regex <- "[a-z^.]{3,}[a-z]{2,3}/[-a-z0-9_^/]+/[-a-z0-9_^.]+"

  if (is_ssh_remote(remote_url)) {
    remote_url <- gsub("^ssh://", "", remote_url)
    remote_url <- gsub("^git@", "", remote_url)
    remote_url <- gsub(":", "/", remote_url)
    remote_url <- paste0("https://", remote_url)
  } else if (grepl(sprintf("^%s$", remote_regex), remote_url, ignore.case = TRUE)) {
    remote_url <- paste0("https://", remote_url)
  } else if (is_https_remote(remote_url)) {
    remote_url <- gsub("http://", "https://", remote_url)
  }

  if (!grepl("[.]git$", remote_url))
    remote_url <- paste0(remote_url, ".git")

  if (!grepl(sprintf("^https://%s[.]git$", remote_regex),
             remote_url, ignore.case = TRUE))
    stop("Unable to convert remote to https remote: ", remote_url)

  remote_url
}

is_ssh_remote <- function(remote) {
  grepl("^git@", remote, ignore.case = TRUE) ||
    grepl("^ssh://", remote, ignore.case = TRUE)
}

is_https_remote <- function(remote) {
  grepl("^https?://", remote, ignore.case = TRUE)
}