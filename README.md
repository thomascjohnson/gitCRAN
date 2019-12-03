# gitCRAN

Create your own CRAN repo with git and a git provider (Github, Bitbucket, Gitlab). 

Github, Bitbucket and Gitlab all allow the committed files to a repo to be viewed as raw. This means that they can function as a file server, which is what a CRAN repo needs. 

This is currently on tested with Github, has no automated testing, and lacks the functionality for using private repositories as CRAN repos. That will be added later. In the mean time, for public repos, simple use the following URL pattern for your CRAN repo list: 

    https://raw.githubusercontent.com/{org/username}/{git repo name}/master/{repo type - see below}
    
## Usage

To use this package, you will need to do a few things:

1) Have an existing git repository on Github, Bitbucket or Gitlab to be used as a CRAN repository.
2) Have a Personal Access Token from [Github](https://help.github.com/en/github/authenticating-to-github/creating-a-personal-access-token-for-the-command-line), [Bitbucket](https://confluence.atlassian.com/bitbucketserver/personal-access-tokens-939515499.html), or 
[Gitlab](https://docs.gitlab.com/ce/user/profile/personal_access_tokens.html)
3) Have an R package as either a local path, a github repository url (such as github.com/thomascjohnson/gitCRAN), or a link to a package in a CRAN repository (such as http://cloud.r-project.org/src/contrib/quietR_0.1.0.tar.gz)

Optionally, you can also have the following:

* The branch of the CRAN git repository you want to commit to
* Specify a type (other than "source") to compile a binary package and, in the repo, put it under:
```
/{type}/src/contrib/{package tarball}
```

Once you have all of that, you can set your PAT:
```
set_token("github", "my_github_pat")
```

And then run the following (with github.com/thomascjohnson/myCRAN as the CRAN git repo and github.com/thomascjohnson/myRpackage as the R package):

```
add_package(repo = "github.com/thomascjohnson/myCRAN", package = "github.com/thomascjohnson/myRpackage")
```

In this case, which is the simplest one, the package will be written to the /source/src/contrib directory of the git repository in the master branch, and the function will automatically pull your token that you set earlier. 

### Additional examples

Specifying a branch
```
add_package(repo = "github.com/thomascjohnson/myCRAN", package = "github.com/thomascjohnson/myRpackage", branch = "dev")
```

Specifying a type and branch
```
add_package(repo = "github.com/thomascjohnson/myCRAN", package = "github.com/thomascjohnson/myRpackage", type = "alpine3.10.3", branch = "dev-pr-3")
```

Specifying a type and token
```
add_package(repo = "github.com/thomascjohnson/myCRAN", package = "github.com/thomascjohnson/myRpackage", type = "alpine3.10.3", token = "fancy_token")
```
    
## Type

One feature of this is the ability to specify a repository "type". This is essentially whether to compile binary packages or not. The default is "source", which doesn't compile binary packages and creates the repository under the source folder in the specified git repository. Anything else will create a folder with the specified type as the name, and compile binary packages and add them to a repository structure under that folder. For example:

If the type is source and the package is ggplot2 version 1, there will be the following structure:
```
/source/src/contrib/ggplot2_1.0.0.tar.gz
/source/src/contrib/PACKAGES
```
If the user then adds ggplot2 for alpine linux under the type "alpine", the structure will then be:
```
/source/src/contrib/ggplot2_1.0.0.tar.gz
/source/src/contrib/PACKAGES
/alpine/src/contrib/ggplot2_1.0.0.tar.gz
/alpine/src/contrib/PACKAGES
```

and the file `/alpine/src/contrib/ggplot2_1.0.0.tar.gz` will be a binary R package compiled for alpine linux.

The specified type itself is entirely user-driven, so be careful with it. 

## To do

There's a lot to do here, so use this knowing that:

* Tests need to be added.
* Documentation needs to be improved.
* Useability surrounding credentials currently relies on personal access tokens. This is because using private repos as CRAN repos will depend on this.
* Functionality may change around the types feature.
* The project needs more formality (contribution guidelines, feature roadmap, etc.)
 