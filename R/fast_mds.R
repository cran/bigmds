#'@title Fast MDS
#'
#'@description Fast MDS uses recursive programming in combination with a divide 
#'and conquer strategy in order to obtain an MDS configuration for a given
#'large data set \code{x}.
#'
#'@details Fast MDS randomly divides the whole sample data set, \code{x}, of size \eqn{n}
#'into \eqn{p=}\code{l/s_points} data subsets, where \code{l} \eqn{\leq \bar{l}} being \eqn{\bar{l}}
#'the limit size for which classical MDS is applicable. Each one of the \eqn{p} data subsets
#'has size \eqn{\tilde{n} = n/p}. If \eqn{\tilde{n} \leq \code{l}} then classical MDS is applied 
#'to each data subset. Otherwise, fast MDS is recursively applied.
#'In either case, a final MDS configuration is obtained for each data subset.
#'
#'In order to align all the partial solutions, a small subset of size \code{s_points}
#'is randomly selected from each data subset. They are joined
#'to form an alignment set, over which classical MDS is performed giving rise to an
#'alignment configuration. Every data subset shares \code{s_points} points with the alignment 
#'set. Therefore every MDS configuration can be aligned with the alignment configuration 
#'using a Procrustes transformation. 
#'
#'@param x A matrix with \eqn{n} individuals (rows) and \eqn{k} variables (columns).
#'@param l The size for which classical MDS can be computed efficiently 
#'(using `cmdscale` function). It means that if \eqn{\bar{l}} is the limit 
#'size for which classical MDS is applicable, then \code{l}\eqn{\leq \bar{l}}.
#'@param s_points Number of points used to align the MDS solutions obtained by 
#'the division of \code{x} into \eqn{p} submatrices. Recommended value: \code{5·r}.
#'@param r Number of principal coordinates to be extracted.
#'@param n_cores Number of cores wanted to use to run the algorithm.
#'
#'@return Returns a list containing the following elements:
#' \describe{
#'   \item{points}{A matrix that consists of \eqn{n} individuals (rows) 
#'   and \code{r} variables (columns) corresponding to the principal coordinates. Since 
#'   we are performing a dimensionality reduction, \code{r}\eqn{<<k}}
#'   \item{eigen}{The first \code{r} largest eigenvalues: 
#'   \eqn{\bar{\lambda}_i, i \in  \{1, \dots, r\} }, where
#'   \eqn{\bar{\lambda}_i = 1/p \sum_{j=1}^{p}\lambda_i^j/n_j},
#'   being \eqn{\lambda_i^j} the \eqn{i-th} eigenvalue from partition \eqn{j}
#'   and \eqn{n_j} the size of the partition \eqn{j}.}
#'}
#'
#'@examples
#'set.seed(42)
#'x <- matrix(data = rnorm(4 * 10000), nrow = 10000) %*% diag(c(9, 4, 1, 1))
#'mds <- fast_mds(x = x, l = 200, s_points = 5 * 2, r = 2, n_cores = 1)
#'head(mds$points)
#'mds$eigen
#'
#'@references
#'Delicado P. and C. Pachón-García (2021). *Multidimensional Scaling for Big Data*.
#'\url{https://arxiv.org/abs/2007.11919}.
#'
#'Yang, T., J. Liu, L. McMillan and W.Wang (2006). *A fast approximation to multidimensional scaling*. 
#'In Proceedings of the ECCV Workshop on Computation Intensive Methods for Computer Vision (CIMCV).
#' 
#'Borg, I. and P. Groenen (2005). *Modern Multidimensional Scaling: Theory and Applications*. Springer.
#'
#'@importFrom parallel mclapply
#'@importFrom stats cov
#'
#'@export
fast_mds <- function(x, l, s_points, r, n_cores) {
  
  n <- nrow(x)
  # Make sure we run the recursive part is everything is big enough.
  if (n <= l | n <= s_points | (n * s_points)/l <=r) {
    mds <- classical_mds(x = x, r = r)
    mds$eigen <- mds$eigen / nrow(x)
    return(mds)
  } else {
    # Split x
    index_partition <- get_partitions_for_fast(n = n, l = l, s_points = s_points, r = r)
    num_partition <- length(index_partition)
    
    # Get MDS for each partition recursively
    mds_partition <- parallel::mclapply(
      index_partition,
      main_fast_mds,
      matrix = x,
      l = l,
      s_points = s_points,
      r = r,
      n_cores = n_cores,
      mc.cores = n_cores
    )
    
    mds_partition_points <- parallel::mclapply(mds_partition, function(x) x$points, mc.cores = n_cores)
    mds_partition_eigen <- parallel::mclapply(mds_partition, function(x) x$eigen, mc.cores = n_cores)
    
    # take a sample for each partition
    length_partition <- parallel::mclapply(index_partition, length, mc.cores = n_cores)
    sample_partition <- parallel::mclapply(
      length_partition,
      sample,
      size = s_points,
      replace = FALSE,
      mc.cores = n_cores
    )
    
    indexes_filtered <- parallel::mcmapply(
      function(idx, sample) idx[sample],
      idx = index_partition,
      sample = sample_partition,
      SIMPLIFY = FALSE,
      mc.cores = n_cores
    )
    
    length_sample <- parallel::mclapply(sample_partition, length, mc.cores = n_cores)
    indexes_scaled <- parallel::mcmapply(
      function(i, long) ((i - 1) * long + 1):(i * long),
      i = 1:num_partition,
      long = length_sample,
      SIMPLIFY = FALSE,
      mc.cores = n_cores
    )
    
    # Join all the points
    x_partition_sample <- parallel::mclapply(
      indexes_filtered,
      function(index_partitions, matrix) {matrix[index_partitions, , drop = FALSE]},
      matrix = x,
      mc.cores = n_cores
    )
    
    x_M <- do.call(rbind, x_partition_sample)
    
    # Apply MDS to the subsampling points
    mds_M <- classical_mds(x = x_M, r = r)
    mds_M_points <- mds_M$points
    
    # Extract the MDS configuration for the sampling points from mds_M_points 
    mds_M_sampling_points <- parallel::mclapply(
      indexes_scaled,
      function(indexes_scaled, matrix) {matrix[indexes_scaled, , drop = FALSE]},
      matrix = mds_M_points,
      mc.cores = n_cores
    )
    
    # Extract the MDS configuration for the sampling points from mds_partition_points
    mds_partition_sampling_points <- parallel::mcmapply(
      function(matrix, index_partitions, idx) {matrix[idx, , drop = FALSE]},
      matrix = mds_partition_points,
      idx = sample_partition,
      SIMPLIFY = FALSE,
      mc.cores = n_cores
    )
    
    # Apply Procrustes
    procrustes <- parallel::mcmapply(
      perform_procrustes,
      x = mds_partition_sampling_points,
      target = mds_M_sampling_points,
      matrix_to_transform = mds_partition_points,
      translation = FALSE,
      SIMPLIFY = FALSE,
      mc.cores = n_cores
    )
    
    # Build the list to be returned
    idx_order <- Reduce(c, index_partition)
    idx_order <- order(idx_order)
    mds <-do.call(rbind, procrustes)
    mds <- mds[idx_order, ,drop = FALSE]
    mds <- mds %*% base::eigen(stats::cov(mds))$vectors
    eigen <- Reduce(`+`, mds_partition_eigen)/num_partition
    return(list(points = mds, eigen = eigen))
  }
}

get_partitions_for_fast <- function(n, l, s_points, r) {
  p <- floor(l/s_points)
  min_sample_size <- max(r + 2, s_points)
  size_partition <- floor(n/p)
  last_sample_size <- n - (p-1) * size_partition
  
  # Make sure each partition is enough populated
  while (
    p >= 1 & 
    (size_partition < min_sample_size | last_sample_size < min_sample_size) & 
    last_sample_size > 0
  ) {
    p <- p - 1
    size_partition <- floor(n/p)
    last_sample_size <- n - (p-1) * size_partition
  }
  
  if (p > 1) {
    permutation <- sample(x = n, size = n, replace = FALSE)
    permutation_all <- permutation[1:((p - 1) * size_partition)]
    permutation_last <- permutation[((p - 1) * size_partition + 1):n]
    list_indexes <- split(x = permutation_all, f = 1:(p - 1))
    names(list_indexes) <- NULL
    list_indexes[[p]] <- permutation_last
  } else {
    permutation <- 1:n
    list_indexes <- list(permutation)
  }
  return(list_indexes)
}

main_fast_mds <- function(idx, matrix, l, s_points, r, n_cores) {
  
  # Partition the matrix
  x_partition <- matrix[idx, , drop = FALSE]
  
  # Apply the method
  mds <- fast_mds(x = x_partition, l = l, s_points = s_points, r = r, n_cores = n_cores)
  return(mds)
}
