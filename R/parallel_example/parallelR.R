
# This code is part of the ParallelR blog ExplicitParallel example.
# Adapted to work in Triton by Simo Tuomisto, 2017
# See the blog post in http://www.parallelr.com/r-with-parallel-computing/
# Blog's examples are available in GitHub: https://github.com/patriczhao/ParallelR

# Original author docstring:
# Examples for the R and Parallel Computing blog in COS website （cos.name)
# Author: Peng Zhao, 8/30/2016

# Get the number of cores to use from command line or from SLURM_CPUS_PER_TASK
library("optparse")

option_list = list(
  make_option(c("-c", "--cores"), type="integer", default=NULL, 
                help="Number of cpus to use", metavar="integer")); 

opt_parser = OptionParser(option_list=option_list);
opt = parse_args(opt_parser);

if (is.null(opt$cores)) {
  cores <- as.integer(Sys.getenv("SLURM_CPUS_PER_TASK"))
  if (is.na(cores)) {
    cores <- 1
  }
} else {
    cores <- opt$cores
}
message("Number of cores used: ",cores)


# Generate data    
message("Generating data")
len <- 1e6
a <- runif(len, -10, 10)
a[sample(len, 100,replace=TRUE)] <- 0

b <- runif(len, -10, 10)
c <- runif(len, -10, 10)

# Not vectorized function
solve.quad.eq <- function(a, b, c) 
{
  # Not validate eqution: a and b are almost ZERO
  if(abs(a) < 1e-8 && abs(b) < 1e-8) return(c(NA, NA) )
  
  # Not quad equation
  if(abs(a) < 1e-8 && abs(b) > 1e-8) return(c(-c/b, NA))
  
  # No Solution
  if(b*b - 4*a*c < 0) return(c(NA,NA))
  
  # Return solutions
  x.delta <- sqrt(b*b - 4*a*c)
  x1 <- (-b + x.delta)/(2*a)
  x2 <- (-b - x.delta)/(2*a)
  
  return(c(x1, x2))
}

#############################################################################################
# *apple style
##############################################################################################
# serial code
message("Running lapply")
system.time(
    res1.s <- lapply(1:len, FUN = function(x) { solve.quad.eq(a[x], b[x], c[x])})
)

# parallel
message("Running mcapply with parallel-package")
library(parallel)
# multicores on Linux
system.time(
  res1.p <- mclapply(1:len, FUN = function(x) { solve.quad.eq(a[x], b[x], c[x])}, mc.cores = cores)
)


# cluster
message("Running Cluster parLapply with parallel-package")
cl <- makeCluster(cores)
clusterExport(cl, c('solve.quad.eq', 'a', 'b', 'c'))
system.time(
   res1.p <- parLapply(cl, 1:len, function(x) { solve.quad.eq(a[x], b[x], c[x]) })
)
stopCluster(cl)


##########################################################################################
# For style
###########################################################################################
# serial code
message("Running serial for-loop")
res2.s <- matrix(0, nrow=len, ncol = 2)
system.time(
    for(i in 1:len) {
        res2.s[i,] <- solve.quad.eq(a[i], b[i], c[i])
    }
)

# foreach
library(foreach)
library(doParallel)

# Real physical cores in my computer
cl <- makeCluster(cores)
registerDoParallel(cl, cores=cores)

# clusterSplit are very convience to split data but it takes lots of extra memory
# chunks <- clusterSplit(cl, 1:len)

# split data by ourselves
chunk.size <- len/cores

message("Running parallel for loop with foreach- and doParallel-packages")
system.time(
  res2.p <- foreach(i=1:cores, .combine='rbind') %dopar%
  {  # local data for results
     res <- matrix(0, nrow=chunk.size, ncol=2)
     for(x in ((i-1)*chunk.size+1):(i*chunk.size)) {
        res[x - (i-1)*chunk.size,] <- solve.quad.eq(a[x], b[x], c[x])
     }
     # return local results
     res
  }
)

stopImplicitCluster()
stopCluster(cl)
