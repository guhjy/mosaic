utils::globalVariables(c('.latticeEnv'))

#' Create function from data
#'
#' These functions create mathematical functions from data, by smoothing, splining, or linear
#' combination (fitting).  Each of them takes a formula and a data frame as an argument
#' @rdname FunctionsFromData
#' @name FunctionsFromData
#' @aliases smoother linearModel spliner connector
#'
#' @param formula a formula.  Only one quantity is allowed on the left-hand side, the
#' output quantity
#' @param data a data frame
#' @param method a method for splining.  See [spline()].
#' @param monotonic a `TRUE/FALSE` flag specifying whether the spline should
#' respect monotonicity in the data
#' @param span parameter to smoother.  How smooth it should be.
#' @param degree parameter to smoother. 1 is locally linear, 2 is locally quadratic.
#'
#' @details
#' These functions use data to create a mathematical, single-valued function of the inputs.
#' All return a function whose arguments are the variables used on the right-hand side of the formula.
#' If the formula involves a transformation, e.g. `sqrt(age)` or `log(income)`,
#' only the variable itself, e.g. `age` or `income`, is an argument to the function.
#' 
#' `linearModel` takes a linear combination of the vectors specified on the right-hand side.
#' It differs from `project` in that `linearModel` returns a function
#' whereas `project` returns the coefficients.  NOTE: An intercept term is not included
#' unless that is explicitly part of the formula with `+1`.  This conflicts with the
#' standard usage of formulas as found in `lm`.  Another option for creating
#' such functions is to combine [lm()] and [makeFun()].
#' 
#' `spliner` and `connector` currently work for only one input variable.
#' 
#' 
#'
#' @seealso [project()] method for formulas
#'
#' @examples
#' if (require(mosaicData)) {
#' data(CPS85)
#' f <- smoother(wage ~ age, span=.9, data=CPS85)
#' f(40)
#' g <- linearModel(log(wage) ~ age + educ + 1, data=CPS85)
#' g(age=40, educ=12)
#' # an alternative way to define g (Note: + 1 is the default for lm().)
#' g2 <- makeFun(lm(log(wage) ~ age + educ, data=CPS85))
#' g2(age=40, educ=12)
#' x<-1:5; y=c(1, 2, 4, 8, 8.2)
#' f1 <- spliner(y ~ x)
#' f1(x=8:10)
#' f2 <- connector(x~y)
#' }
#' @export

spliner <- function(formula, data=NULL, method="fmm", monotonic=FALSE) {
  .interpolatingFunction(formula, data, method=method, monotonic=monotonic)
}

#' @rdname FunctionsFromData
#' @export

connector <- function(formula, data=NULL, method="linear") {
  .interpolatingFunction(formula, data, connect=TRUE)
}
#' @rdname FunctionsFromData
#' @param \dots additional arguments to [stats::loess()] or [stats::lm()]
#' @export

smoother <- function(formula, data, span=0.5, degree=2, ... ) {
  input.names <- all.vars(formula)[-1]
  L <- loess(formula, data, span=span, degree=degree, ..., control=loess.control(surface="direct"))
  makeDF <- paste( "data.frame( ", paste(input.names, collapse=",", sep=""), ")")
  F <- function() {
    D <- eval(parse(text=makeDF))
    predict(L, newdata=D)
  }
  tmp <- paste("alist( ", paste(input.names, "=", collapse = ",", sep = ""), ")")
  tmp <- eval(parse(text = tmp))
  formals(F) <- tmp
  return(F)
}

#' @rdname FunctionsFromData
#' @export

linearModel <- function(formula, data, ...) {
  input.names <- all.vars(formula)[-1]
  L <- lm(update(formula, ~-1+.), data, ...)
  makeDF <- paste( "data.frame( ", paste(input.names, collapse=",", sep=""), ")")
  F <- function(showcoefs) {
    if( showcoefs ) coef(L)
    else { # evaluate the function 
      D <- eval(parse(text=makeDF))
      predict(L, newdata=D)
    }
  }
  tmp <- paste("alist( ", paste(input.names, "=", collapse = ",", sep = ""), ", showcoefs=FALSE)")
  tmp <- eval(parse(text = tmp))
  formals(F) <- tmp
  attr(F, "mosaicType") <- "Fitted Linear Model"
  return(F)
}

.interpolatingFunction <- function(formula, data, method="fmm", monotonic=FALSE, connect=FALSE) {
  fnames <- all.vars(formula)
  if( length(fnames) > 2 )
    stop("Sorry: Doesn't yet handle multiple input variables.")
  
  values <- model.frame(formula, data=data )
  y <- model.response(values)
  x <- mat(formula, data=data)
  if( connect ) SF <- approxfun(x, y, rule=2)
  else {
    if( ! monotonic )  SF <- splinefun(x, y, method=method)
    else SF <- splinefun(x, y, method="monoH.FC")
  }
  F <- function(foobar, deriv=0 ){
    x <- get(fnames[2])
    if(connect) SF(x)
    else SF(x, deriv=deriv)
  }
  if (connect) tmp <- paste("alist( ", fnames[2], "=)", sep="")
  else tmp <- paste("alist( ", fnames[2], "=, deriv=0)", sep="")
  formals(F) <- eval(parse(text=tmp))
  return(F)
}
