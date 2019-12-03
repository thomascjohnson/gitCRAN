#' gitCRAN: A package for keeping your internal/custom CRAN repo in a git
#' provider like Github, Gitlab, Bitbucket, etc.
#'
#' @section Concept:
#' Creating and maintaining a custom/internal CRAN repository requires setting
#' up a file server and a way of adding/removing packages, as well as updating
#' the PACKAGES file that registers the available packages.
#'
#' Furthermore, a simple file server lacks any version control, history, etc.
#' By taking advantage of a git repository and git repository viewer, a CRAN
#' repo can be created, browsed, rolled-back, access controlled, etc.
#'
#' @section Usage:
#' The usage of this package is currently limited and based on usage with
#' Github, though there is the ability to use it with Bitbucket and Gitlab,
#' though it isn't tested (and I'm not sure if it will work at all).
#'
#' What you need:
#' \enumerate{
#'   \item A repository on Github (or Bitbucket, or Gitlab)
#'   \item A personal access token from the git provider that can read/write
#'   \item An R package that you'd like to add to the repository
#' }
#'
#' What's optional:
#' \describe{
#'   \item{type}{Setting the repository type - this is essentially whether to
#'   compile the package as a binary or as source. The default is "source",
#'   which will not compile the package as a binary and simple run the package
#'   build step. If not "source", then specify the directory you want to group
#'   the binaries under. For example, suppose you want to build a binary
#'   package for Centos 7 (and you're running this on Centos 7), then the type
#'   could be "centos7" and the result would be a binary package under
#'   /centos7/src/contrib/.}
#'   \item{branch}{The branch of the repository you want to write to.}
#' }
#'
#' An example would then be:
#' \itemize{
#'   \item repo: github.com/thomascjohnson/testCRAN
#'   \item package: github.com/thomascjohnson/gitCRAN (this package)
#'   \item branch: master
#'   \item type: source
#'   \item token: My Github PAT
#' }
#'
#' And the actual code:
#' \preformatted{
#'   add_package(
#'     "github.com/thomascjohnson/testCRAN",
#'     "github.com/thomascjohnson/gitCRAN",
#'     branch = "dev",
#'     type = "cflinuxfs3",
#'     token = my_github_pat
#'   )
#' }
#'
#' Alternatively, you can set your
#'
#' @docType package
#' @name gitCRAN
NULL
