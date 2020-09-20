#' Add packages to a repository
#'
#' To use this, the user must have a personal access token (PAT) from the git
#' provider must be generated for reading and writing.
#'
#' @param repo character - A repository URL or local directory with a remote.
#' @param packages character - R packages in a directory, a git remote to a
#' repo containing an R package, or a link to a package in a CRAN repo.
#' @param branch character - The branch of the gitCRAN repository to write to.
#' @param subrepo character - What directory to group the repository under. If
#' not "source", the default, then it compiles the package as a binary but
#' still adds it to the {type}/src/contrib/ directory.
#' @param image character - A Docker image name, either
#' @param token character - The personal access token (PAT) for reading/writing
#' to the repository.
#' @param save_subrepo_config logical - Whether or not to save the build and
#' image options to a .gitCRAN-config file in the subrepo root.
#'
#' @export
#'
#' @examples
#' \dontrun{
#'   add_packages(
#'     "github.com/thomascjohnson/testCRAN",
#'     "github.com/thomascjohnson/gitCRAN",
#'     branch = "dev",
#'     name = "cflinuxfs3"
#'   )
#' }
add_packages <- function(repo = ".", packages, branch = "master",
                         subrepo = "source", build = FALSE, image = NULL,
                         token = NULL, save_subrepo_config = TRUE,
                         update_image = TRUE, lib_dir = NULL) {
  repo_dir <- get_repo_dir(repo = repo, branch = branch, type = subrepo)

  repo_url <- get_repo_url(repo)

  repo_config <- get_repo_config(repo_dir, subrepo, image, build,
                                 save = save_subrepo_config)

  image <- repo_config$DockerImage
  build <- repo_config$Build

  subrepo_dir <- file.path(repo_dir, subrepo)

  repo_package_dir <- file.path(subrepo_dir, "src", "contrib")

  if (!is.null(image)) {
    tryCatch({
      docker_client <- stevedore::docker_client()
    }, error = function(e) {
      stop("Must install Docker and the stevedore R package to build images with Docker.")
    })

    container_exec <- make_container_exec(docker_client, image,
                                          get_gitCRAN_tempdir(), repo_dir,
                                          update_image, lib_dir)

    available_packages <- get_available_packages(container_exec)

    packages <- normalize_packages(packages, get_package_build_dir(),
                                   available_packages)
    install_packages(get_packages_deps(packages, available_packages),
                     container_exec, file.path(repo_dir, subrepo))
    packages_info <- lapply(packages, prepare_package, subrepo_dir, subrepo,
                            build, available_packages, container_exec)
  } else {
    packages_info <- lapply(packages, prepare_package, subrepo_dir,
                            subrepo, build)
  }

  tools::write_PACKAGES(repo_package_dir)

  if (is.null(token))
    token_var <- get_token(repo_url)
  else {
    set_token(get_provider(repo_url), token)
    token_var <- get_token(repo_url)
  }

  #r_version <- with(R.Version(), paste0(major, ".", minor))

  #repo_path <- file.path(subrepo, "src", "contrib", r_version)

  withr::with_dir(repo_dir, {
    package_files <- dir(repo_package_dir, pattern = "PACKAGES*",
                         full.names = TRUE)

    git2r::add(repo = repo_dir, path = package_files)

    package_names <- c()

    git2r::add(repo = repo_dir, path = dir(repo_package_dir,
                                           pattern = "*.tar.gz",
                                           full.names = TRUE))

    git2r::add(repo = repo_dir,
               path = dir(file.path(repo_package_dir, "Archive"),
                          pattern = "*.tar.gz",
                          full.names = TRUE)
    )

    for (package_info in packages_info) {
      for (package_name in package_info$package_name)
        package_names <- c(package_names, package_name)
    }
  })

  # Add .gitCRAN-config file
  git2r::add(repo = repo_dir,
             path = file.path(repo_dir, subrepo, gitCRAN_repo_config_name))

  package_names_string <- paste(package_names, collapse = "\n")

  commit_message <- paste("Adds the followig packages to", subrepo,
                          "sub-repository:\n", package_names_string)

  git2r::commit(repo = repo_dir, commit_message)
  git2r::push(object = repo_dir, credentials = git2r::cred_token(token_var),
              name = "origin", refspec = paste0("refs/heads/", branch))
}