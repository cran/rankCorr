#' Total, between-, and within-cluster Spearman rank correlations for clustered data
#'
#' \code{rankCorrCluster} computes the total, between-, and within-cluster Spearman rank correlations between two variables using two-level clustered data. It can be used with any orderable variable, including continuous and discrete variables. Two weighting methods are provided, including assigning equal weights to observations or to clusters.
#' @param x a numeric or factor vector.
#' @param y a numeric or factor vector.
#' @param cluster a vector of cluster index corresponding to \code{x} and \code{y}.
#' @param link.x,link.y the link family to be used for the ordinal models of
#' \code{x} and \code{y} on cluster index. Defaults to \samp{logit}. Other options are
#' \samp{probit}, \samp{cloglog}, \samp{cauchit}, and \samp{logistic} (equivalent with \samp{logit}).
#' @param weights a character string indicating which weighting method is used.
#' Should be one of the strings \code{"obs"} and \code{"clusters"}. Default is \code{"obs"}. See Details.
#' @param methods_between_corr a character string indicating which estimation method of the between-cluster correlation is used.
#' Should be one of the strings \code{"cluster-median"}, \code{"approx"}, and \code{"both"}. Default is \code{"cluster-median"}. See Details.
#' @param conf.int numeric specifying confidence interval level.
#' @param fisher logical, indicating whether to apply Fisher transformation to compute confidence intervals.
#' @param na.rm logical. Should missing values be removed?
#' @details The weighting method \code{"obs"} assigns equal weights to observations; \eqn{w_{ij} = 1/N}, where \var{N} is the total number of observations. The weighting method \code{"clusters"} assigns equal weights to clusters; \eqn{w_{ij} = 1/(nk_i)}, where \var{n} is the total number of clusters and k_i is the cluster size.
#' The estimation method \code{"cluster-median"} estimates the between-cluster Spearman rank correlation using the coefficients from the cumulative probability models of \code{x} and \code{y} on cluster index \code{cluster}. The estimation method \code{"approx"} estimates the between-cluster Spearman rank correlation using the approximated linear relationship between the total, between-, and within-cluster Spearman rank correlations.
#' @return a list with following components.
#' \tabular{ll}{
#'   \code{'Total'} \tab the total Spearman rank correlation, including the estimate (\code{Estimate}), the standard error (\code{SE}), the lower and upper bounds of the confidence interval (\code{Lower, Upper}).\cr
#'   \tab \cr
#'   \code{'Within'} \tab the within-cluster Spearman rank correlation, including the estimate (\code{Estimate}), the standard error (\code{SE}), the lower and upper bounds of the confidence interval (\code{Lower, Upper}).\cr
#'   \tab \cr
#'   \code{'Between'} \tab the between-cluster Spearman rank correlation estimated, including the estimation method name, the estimate (\code{Estimate}), the standard error (\code{SE}), the lower and upper bounds of the confidence interval (\code{Lower, Upper}).\cr
#'   \tab \cr
#'   \code{'Rank ICC'} \tab the rank intraclass correlation coefficients of \code{x} and \code{y}. It would be presented in the output if \code{'approx'} is used. \cr
#' }
#' @references
#' \tabular{ll}{
#' Tu, S., Li, C., Zeng, D., and Shepherd, B. E. (2023). Rank intraclass correlation for clustered data. Statistics in Medicine 42, 4333-4348. \cr
#' Shih, J. H. and Fay, M. P. (2017). Pearson's chi-square test and rank correlation inferences for clustered data. Biometrics 73, 822-834. \cr
#' Tu, S., Li, C., and Shepherd, B. E. (2024). Between- and within-cluster Spearman rank correlations. Statistics in Medicine, 44(3-4), e10326. \cr
#' }
#'
#' @examples
#' library(mvtnorm)
#' k <- 50; m <- 5
#' sigma.u <- matrix(c(1, 0.6, 0.6, 4), ncol=2); sigma.e <- matrix(c(1, 0.6, 0.6, 1), ncol=2)
#' u <- rmvnorm(k, c(1, -1), sigma.u)
#' x1 <- matrix(NA, k, m)
#' y1 <- matrix(NA, k, m)
#' for (i in 1:k){
#' r <- rmvnorm(m, c(0, 0), sigma.e)
#' x1[i,] <- u[i, 1] + r[, 1]
#' y1[i,] <- u[i, 2] + r[, 2]
#' }
#' x <- as.vector(t(x1))
#' y <- as.vector(t(y1))
#' cluster <- rep(1:k, each=m)
#' rankCorrCluster(x, y, cluster, link.x = "probit", link.y = "probit",
#' methods_between_corr = "approx")
#' idx <- sample(1:250, 200, replace = TRUE)
#' rankCorrCluster(x[idx], y[idx], cluster[idx], link.x = "probit", link.y = "probit",
#' weights = "clusters")
#' @export
#' @importFrom stats complete.cases qnorm sd pnorm dnorm predict
#' @importFrom rankICC rankICC
#' @importFrom rms orm

rankCorrCluster <- function(x, y, cluster,
                            link.x = c("probit", "logistic", "cauchit", "loglog", "cloglog"),
                            link.y = c("probit", "logistic", "cauchit", "loglog", "cloglog"),
                            weights = c("obs", "clusters"),
                            methods_between_corr = c("cluster-median", "approx", "both"),
                            conf.int = 0.95, fisher = FALSE,
                            na.rm = FALSE){
  if((!is.numeric(x) & !is.factor(x)) | (!is.numeric(y) & !is.factor(y))) stop("x and y must be a numeric or factor vector!")
  else if((length(cluster) != length(x)) | length(cluster) != length(y)) stop("lengths of x, y and cluster must be the same!")
  if(!methods_between_corr[1] %in% c("cluster-median", "approx", "both")) stop(stop("a wrong estimation method name for the between correlation entered!"))
  idx <- seq_along(x)
  if(na.rm | (sum(is.na(x)) | sum(is.na(y)) | sum(is.na(cluster)))){
    idx <- complete.cases(x, y, cluster)
    x <- x[idx]
    y <- y[idx]
    cluster <- cluster[idx]
    if(!na.rm) warning("missing values were removed")
  }
  cluster <- as.character(cluster)
  x <- as.numeric(factor(x))
  y <- as.numeric(factor(y))
  cluster <- factor(cluster, levels=unique(cluster))
  x <- x[order(cluster)]
  y <- y[order(cluster)]
  cluster <- sort(cluster)
  score.y <- scores_presid(y = y, X = cluster, link.y[1])
  score.x <- scores_presid(y = x, X = cluster, link.x[1])
  ##########within-cluster correlation
  ki <- tabulate(cluster)
  n.cluster <- length(unique(cluster))
  n.obs <- length(x)
  if(sum(ki == 1)){
    warning("clusters with only one observation were not used for estimating the within-cluster correlation")
    kij <- rep(ki, ki)
    idx.new <- kij > 1
    idx.new.cls <- ki > 1
    cluster.new <- cluster[idx.new]
    cluster.new  <- factor(cluster.new, levels = levels(cluster)[idx.new.cls])
    ki.new <- tabulate(cluster.new)
    n.cluster.new <- n.cluster - sum(ki==1)
    n.obs.new <- n.obs - sum(kij==1)
    if(weights[1] == "obs"){
      wij <- 1 / n.obs.new
      wi <- table(cluster.new) / n.obs.new
    }
    else{
      wij <- rep(1 / n.cluster.new / ki.new, ki.new)
      wi <- 1 / n.cluster.new
    }
    rw <- cor_rw(score.x$presid[idx.new], score.y$presid[idx.new],
                 score.x$psi[idx.new.cls,], score.y$psi[idx.new.cls,],
                 score.x$dpsi.dtheta, score.y$dpsi.dtheta,
                 score.x$dpresid.dtheta[idx.new.cls], score.y$dpresid.dtheta[idx.new.cls],
                 cluster.new, wi, wij, conf.int, fisher)
  }
  else{
    if(weights[1] == "obs"){
      wij <- 1 / n.obs
      wi <- ki / n.obs
    }
    else{
      wij <- rep(1 / n.cluster / ki, ki)
      wi <- 1 / n.cluster
    }
    rw <- cor_rw(score.x$presid, score.y$presid,
                 score.x$psi, score.y$psi,
                 score.x$dpsi.dtheta, score.y$dpsi.dtheta,
                 score.x$dpresid.dtheta, score.y$dpresid.dtheta,
                 cluster, wi, wij, conf.int, fisher)
  }

  #########Between-cluster correlation
  if(weights[1] == "obs"){
    wij <- 1 / n.obs
    wi <- ki / n.obs
  }
  else{
    wij <- rep(1 / n.cluster / ki, ki)
    wi <- 1 / n.cluster
  }
  rb <- cor_rb(score.x$beta, score.y$beta, score.x$psi, score.y$psi,
               score.x$dpsi.dtheta, score.y$dpsi.dtheta, wi, conf.int, fisher)

  ########Total correlation
  rt <- cor_rt(x, y, cluster, wij, conf.int, fisher)

  ans <- list("Total" = rt, 'Within' = rw)

  ########Approximation-based between-cluster correlation
  if(methods_between_corr[1] != "cluster-median"){
    if(sum(ki == 1)){
      rb.approx <- cor_rb_approx(x[idx.new], y[idx.new], cluster.new, rw['Estimate'], rt['Estimate'],
                                 weights, conf.int, fisher, rb)
    }
    else rb.approx <- cor_rb_approx(x, y, cluster, rw['Estimate'], rt['Estimate'],
                                    weights, conf.int, fisher, rb)
    ans[['Between']][['approx']] <- rb.approx$rb.approx.est
    ans[['Rank ICC']] <- c(rb.approx$rankicc)
  }
  if(methods_between_corr[1] != 'approx') ans[['Between']][['cluster-median']] <- rb

  return(ans)
}
