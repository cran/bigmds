% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/divide_conquer_mds.R
\name{divide_conquer_mds}
\alias{divide_conquer_mds}
\title{Divide-and-conquer MDS}
\usage{
divide_conquer_mds(x, l, c_points, r, n_cores)
}
\arguments{
\item{x}{A matrix with \eqn{n} points (rows) and \eqn{k} variables (columns).}

\item{l}{The size for which classical MDS can be computed efficiently
(using \code{cmdscale} function). It means that if \eqn{\bar{l}} is the limit
size for which classical MDS is applicable, then \code{l}\eqn{\leq \bar{l}}.}

\item{c_points}{Number of points used to align the MDS solutions obtained by the
division of \code{x} into \eqn{p} data subsets. Recommended value: \code{5·r}.}

\item{r}{Number of principal coordinates to be extracted.}

\item{n_cores}{Number of cores wanted to use to run the algorithm.}
}
\value{
Returns a list containing the following elements:
\describe{
\item{points}{A matrix that consists of \eqn{n} points (rows)
and \code{r} variables (columns) corresponding to the principal coordinates. Since
a dimensionality reduction is performed, \code{r}\eqn{<<k}}
\item{eigen}{The first \code{r} largest eigenvalues:
\eqn{\bar{\lambda}_i, i \in  \{1, \dots, r\} }, where
\eqn{\bar{\lambda}_i = 1/p \sum_{j=1}^{p}\lambda_i^j/n_j},
being \eqn{\lambda_i^j} the \eqn{i-th} eigenvalue from partition \eqn{j}
and \eqn{n_j} the size of the partition \eqn{j}.}
}
}
\description{
Roughly speaking, a large data set, \code{x}, of size \eqn{n}
is divided into parts, then classical MDS is performed over every part and,
finally, the partial configurations are combined so that all the points lie
on the same coordinate system with the aim to obtain a global MDS configuration.
}
\details{
The divide-and-conquer MDS starts dividing the \eqn{n} points into
\eqn{p} partitions: the first partition contains \code{l} points and the others
contain \code{l-c_points} points. Therefore, \eqn{p = 1 + (n-}\code{l)/(l-c_points)}.
The partitions are created at random.

Once the partitions are created, \code{c_points} different random
points are taken from the first partition and concatenated to the other
partitions After that, classical MDS is applied to each partition,
with target low dimensional configuration \code{r}.

Since all the partitions share \code{c_points}
points with the first one, Procrustes can be applied in order to align all
the configurations. Finally, all the configurations are
concatenated in order to obtain a global MDS configuration.
}
\examples{
set.seed(42)
x <- matrix(data = rnorm(4 * 10000), nrow = 10000) \%*\% diag(c(9, 4, 1, 1))
mds <- divide_conquer_mds(x = x, l = 200, c_points = 5 * 2, r = 2, n_cores = 1)
head(mds$points)
mds$eigen

}
\references{
Delicado P. and C. Pachón-García (2021). \emph{Multidimensional Scaling for Big Data}.
\url{https://arxiv.org/abs/2007.11919}.

Borg, I. and P. Groenen (2005). \emph{Modern Multidimensional Scaling: Theory and Applications}. Springer.
}
