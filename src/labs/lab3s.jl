# # SciML SANUM2024
# # Lab 3: Reverse-mode automatic differentiation and Zygote.jl

# When the number of unknowns becomes large forward-mode automatic differentiation as
# implemented in ForwardDiff.jl becomes prohibitively expensive for computing gradients and instead we need to
# use reverse-mode automatic differentiation: this is best thought of as implementing the chain-rule
# in an automatic fashion, with a specific choice of multiplying the underlying Jacobians.

# Computing gradients is important for solving optimisation problems, which is what ultimately what training a neural network
# is. Therefore we also look at solving some
# simple optimissation problems, using Optimsation.jl


# **Learning Outcomes**
#
# 1. Basics of reverse-mode automatic differentiation and pullbacks.
# 2. Implementation via Zygote.jl
# 3. Adding custom pullbacks.
# 4. Using automatic differentiation for implementing gradient descent.
# 5. Solving optimisation with gradient descent and via Optimsation.jl

# ## 3.1 Using Zygote.jl for differentiation

# We begin with a simple demonstration of Zygote.jl, which can be thought of as a replacement for ForwardDiff.jl that
# uses reverse-mode differentiation under the hood. We can differentiate scalar functions, but unlike ForwardDiff.jl it
# overloads the `'` syntax to mean differentiation:


using Zygote, Test

## DEMO
@test cos'(0.1) ≈ -sin(0.1) # Differentiates cos using reverse-mode autodiff
## END

# The real power of Zygote.jl is computing gradients, or more generally, Jacobians
# of $f : ℝ^m → ℝ^n$ where $n << m$. We can compute a gradient of the function we considered before as follows:

f = function(x)
    ret = zero(eltype(x))
    for k = 1:length(x)-1
        ret += x[k]*x[k+1]
    end
    ret
end

## DEMO
x = randn(5)
Zygote.gradient(f,x)
## END

# Unlike ForwardDiff.jl, the gradient returns a tuple since multiple arguments are supported in addition
# to vector inputs, eg:

## DEMO
x,y = 0.1, 0.2
@test all(Zygote.gradient((x,y) -> cos(x*exp(y)), x, y) .≈ [-sin(x*exp(y))*exp(y), -sin(x*exp(y))*x*exp(y)])
## END

# Now differentiating this function is not particularly faster than ForwardDiff.jl:

## DEMO
x = randn(1000)
@time Zygote.gradient(f, x);
x = randn(10_000)
@time Zygote.gradient(f, x); # roughly 200x slower
## END

# This is because not all operations are ameniable to reverse-mode differentiation as implemented in Zygote.jl.
# However, if we restrict to vectorised operations we see a dramatic improvement:

f_vec = x -> sum(x[1:end-1] .* x[2:end]) # a vectorised version of the previus function
Zygote.gradient(f_vec, x) # compile
@time Zygote.gradient(f_vec, x); #  1500x faster 🤩

# Another catch is Zygote.jl doesn't support functions that mutate arrays. Here's an example:

f! = function(x)
    n = length(x)
    ret = zeros(eltype(x), n)
    for k = 1:n-1
        ret[k] = x[k]*x[k+1] # modifies the vector ret
    end
    sum(ret)
end


x = randn(5)
Zygote.gradient(f!,x) # errors out

# This is unlike `ForwardDiff.gradient` which works fine for differentiating `f!`.

# **Conclusion**: Zygote.jl is much more brittle, sometimes fails outright, requires
# writing functions in a specific way, but when it works
# well it is _extremely_ fast. Thus when we get to neural networks it is paramount that
# we design our representation of the neural network in a way that is ameniable to reverse-mode
# automatic differentiation, as implemented in Zygote.jl.

# ------



# ## 3.2 Pullbacks and back-propagation for scalar functions

# We now peek a little under-the-hood to get some intuition on how Zygote.jl is computing 
# derivatives, and to understand why its so much faster than ForwardDiff.jl. Underlying automatic 
# differentiation in Zygote.jl are so-called "pullback"s. In the scalar
# case these are very close to the notion of a derivative. However, rather than
# the derivative being a single constant, it's a linear map representing the derivative:
# eg, if the derivative of $f(x)$ is denoted $f'(x)$ then the pullback is a linear map
# $$
# t ↦ f'(x)t.
# $$
# We can compute pullbacks using the `pullback` routine:

## DEMO
import Zygote: pullback

s, sin_J = pullback(sin, 0.1)
## END

# `sin_J` contains the map $t ↦ \cos(0.1) t$. Since pullbacks support multiple arguments
# it actually returns a tuple with a single entry:

sin_J(1)

# Thus to get out the value we use the following:

@test sin_J(1)[1] == cos(0.1)
@test sin_J(2)[1] == 2cos(0.1)

# The reason its a map instead of just a scalar becomes important for the vector-valued case
# where Jacobians can often be applied to vectors much faster than constructing the Jacobian matrix and
# performing a matrix-vector multiplication.


# Pullbacks can be used for determining more complicated derivatives. Consider a composition of three functions
# $h ∘ g ∘ f$ where from the Chain Rule we know:
# $$
# {{\rm d} \over {\rm d} x}[f(g(h(x))] = f'(g(h(x)) g'(h(x)) h'(x)
# $$
# Essentially we have three pullbacks: the first is the pullback of $f$ evaluated
# at $x$, the second corresponding to $g$ evaluated at $f(x)$, and the third 
# corresponding to $h$ evaluated at $g(f(x))$, that is:
# $$
# \begin{align*}
#  p_1(t) &= f'(x) t  \\
#  p_2(t) &= g'(f(x)) t  \\
#  p_3(t) &= h'(g(f(x))t
# \end{align*}
# $$
# Thus the derivative is given by either the _forward_ or _reverse_ composition of these functions:
# $$
#  p_3(p_2(p_1(1))) = p_1(p_2(p_3(1))) = h'(g(f(x))g'(f(x))f'(x).
# $$
# The first version is called _forward-propagation_ and the second called _back-propagation_.
# Forward-propagation is a version of forward-mode automatic differentiation and is essentially equivalent to using dual numbers.
# We will see later in the vector case that forward- and back-propagation are not the same,
# and that back-propagation is much more efficient provided the output is scalar (or small dimensional).

# Let's see pullbacks in action for computing the derivative of $\cos\sqrt{{\rm e}^x}$:

## DEMO
x = 0.1 # point we want to differentiate
y,p₁ = pullback(exp, x) 
z,p₂ = pullback(sqrt, y) # y is exp(x)
w,p₃ = pullback(cos, z) # z is sqrt(exp(x))

@test w == cos(sqrt(exp(x)))

@test p₁(p₂(p₃(1)...)...)[1] ≈ p₃(p₂(p₁(1)...)...)[1] ≈ -sin(sqrt(exp(x)))*exp(x)/(2sqrt(exp(x)))
## END

# We can see how this can lead to an approach for automatic differentiation.
# For example, consider the following function composing `sin` over and over:

function manysin(n, x)
    r = x
    for k = 1:n
        r = sin(r)
    end
    r
end

# Now, we would need `n` pullbacks as each time `sin` is called at a different value.
# But the number of such pullbacks grows only linearly so this is acceptable. So thus
# at a high-level we can think of Zygote as running through and computing all the pullbacks:

## DEMO
n = 5
x = 0.1 # input

pullbacks = Any[] # a vector where we store the pull backs
r = x
for k = 1:n
    r,pₖ = pullback(sin, r) # new pullback
    push!(pullbacks, pₖ)
end
r # value
## END

# To deduce the derivative we need can either do forward- or back-propogation by looping through our pullbacks
# either in forward- or in reverse-order. Here we implement back-propagation:

## DEMO
reverse_der = 1 # we always initialise with the trivial scaling
for k = n:-1:1
    reverse_der = pullbacks[k](reverse_der)[1]
end
@test reverse_der ≈ ForwardDiff.derivative(x -> manysin(n, x), x)
## END

# Zygote constructs code that is equivalent to this loop automatically, and without the need for creating a "tape".
# That is, it doesn't actually create a vector `pullbacks` to record the operations at run-time, rather,
# it constructs a high-performance version of this back-propogation loop at compile time using something called source-to-source
# differentiation.

# ------

# **Problem 1** Compute the derivative of `manysin` using forward-propagation, by looping through the pull-backs
# in the forward direction.

## TODO: loop through pullbacks in order to compute the derivative.
## SOLUTION
forward_der = 1 # we always initialise with the trivial scaling
for k = 1:n
    forward_der = pullbacks[k](forward_der)[1]
end

@test reverse_der ≈ ForwardDiff.derivative(x -> manysin(n, x), x)

## END


# ## 3.3 Pullbacks with multiple arguments

# Things become more complicated when we have a function with multiple arguments, even in the
# scalar case. Consider now the function $f(g(x), h(x))$. The chain rule tells us that
# $$
# {{\rm d} \over {\rm d} x}[f(g(x), h(x))] = f_x(g(x), h(x)) g'(x) + f_y(g(x), h(x)) h'(x)
# $$
# Now we have three pullbacks:
# $$
# \begin{align*}
# p_1(t) &= g'(x) t\\
# p_2(t) &= h'(x) t\\
# p_3(t) &= [f_x(g(x), h(x))t, f_y(g(x), h(x))t]
# \end{align*}
# $$
# In this case the derivative can be recovered via back-propagation via:
# $$
# p_1(p_3(1)[1]) + p_2(p_3(1)[2]).
# $$
# Here we see a simple example:

f = (x,y) -> cos(x*exp(y))
g = sqrt
h = sin
F = x -> f(g(x), h(x))

x = 0.1
gx, p₁ = pullback(g, x)
hx, p₂ = pullback(h, x)
z, p₃ = pullback(f, gx, hx)

@test p₁(p₃(1)[1])[1] + p₂(p₃(1)[2])[1] ≈ F'(0.1)





# ------

# ## 3.4 Gradients and pullbacks
#
# Now we consider computing gradients, which is
# essential in ML.   Again we denote the Jacobian as
# $$
#  J_f = \begin{bmatrix} {∂ f_1 \over ∂x_1} & ⋯ & {∂ f_1 \over ∂x_ℓ} \\
#       ⋮ & ⋱ & ⋮ \\
#       {∂ f_m \over ∂x_1} & ⋯ & {∂ f_m \over ∂x_ℓ} 
# \end{bmatrix}
# $$
# Note that gradients are the transpose of Jacobians: $∇h = J_h^⊤$. 
# For a scalar-valued function $f : ℝ^n → ℝ$ the pullback represents the linear map $ℝ → ℝ^n$
# corresponding to the gradient:
# $$
# 𝐭 ↦ J_f(𝐱)^⊤𝐭 = ∇f(𝐱) 𝐭
# $$
# Here we see an example:


f = (𝐱) -> ((x,y) = 𝐱;  exp(x*cos(y)))
x,y = (0.1,0.2)
f_v, f_pb = Zygote.pullback(f, [x,y])
@test f_pb(1)[1] ≈ [exp(x*cos(y))*cos(y), -exp(x*cos(y))*x*sin(y)]

# For a function $f : ℝ^n → ℝ^m$ the the pullback represents the map $ℝ^m → ℝ^n$ given by
# $$
# 𝐭 ↦ J_f(𝐱)^⊤𝐭
# $$
# Here is an example:

f = function(𝐱)
    x,y,z = 𝐱
    [exp(x*y*z),cos(x*y+z)]
end
     

𝐱 = [0.1,0.2,0.3]
f_v, f_pb =  pullback(f, 𝐱)

J_f = function(𝐱)
    x,y,z = 𝐱
    [y*z*exp(x*y*z) x*z*exp(x*y*z) x*y*exp(x*y*z);
     -y*sin(x*y+z) -x*sin(x*y+z) -sin(x*y+z)]
end

𝐲 = [1,2]
@test J_f(𝐱)'*𝐲 ≈ f_pb(𝐲)[1]


# Consider a composition $f : ℝ^n → ℝ^m$, $g : ℝ^m → ℝ^ℓ$ and $h : ℝ^ℓ → ℝ$, that is, 
# we want to compute the gradient of $h ∘ g ∘ f : ℝ^n → ℝ$. The Chain rule tells us that
# $$
#  J_{h ∘ g ∘ f}(𝐱) = J_h(g(f(𝐱)) J_g(f(𝐱)) J_f(𝐱)
# $$
# Put another way, the gradiant of $h ∘ g ∘ f$
# is given by the transposes of Jacobians:
# $$
#    ∇[{h ∘ g ∘ f}](𝐱) = J_f(𝐱)^⊤ J_g(f(𝐱))^⊤  ∇h(g(f(𝐱))
# $$
# Thus we have three pullbacks $p_1 : ℝ^m → ℝ^n$, $p_2 : ℝ^ℓ → ℝ^m$ and $p_3 : ℝ → ℝ^ℓ$ given by
# \begin{align*}
#  p_1(𝐭) &= J_f(𝐱)^⊤ 𝐭  \\
#  p_2(𝐭) &= J_g(f(x))^⊤ 𝐭  \\
#  p_3(𝐭) &= ∇h(g(f(𝐱)) 𝐭
# \end{align*}
# The gradient is given by _back-propagation_:
# $$
#  p_1(p_2(p_3(1))) = J_f(𝐱)^⊤ J_g(f(𝐱))^⊤  ∇h(g(f(𝐱)).
# $$
# Here the "right" order to do the multiplications is clear: matrix-matrix multiplications are expensive
# so its best to do it reverse order so that we only ever have matrix-vector multiplications.
# Also, the pullback doesn't give us enough information to implement forward-propagation.
# (This can be done using `Zygote.pushforward` which implements the transpose map $𝐭 ↦ J_f(𝐱) 𝐭$.)

# Here we consider iterating a simple map like:
# 𝐟(x,y,z) = [cos(x*y)+z, z*y-exp(x), x + y + z]

𝐟 = function(𝐱)
    (x,y,z) = 𝐱
    [cos(x*y)+z, z*y-sin(x), x + y + z]
end

function iteratef(𝐱, 𝐟, n)
    for k = 1:n
        𝐱 = 𝐟(𝐱)
    end
    sum(𝐱)
end

iteratef([0.1,0.2,0.3], 𝐟, 5)

# As before we accumulate the pullbacks

pullbacks = Any[] # a vector where we store the pull backs
r = [0.1,0.2, 0.3]
n = 5
for k = 1:n
    r,pₖ = pullback(𝐟, r) # new pullback
    push!(pullbacks, pₖ)
end

ret,sumpullback = pullback(sum, r)
ret # value

# We can recover the gradient by back-propogation:

reverse_grad = 1
reverse_grad = sumpullback(reverse_grad)[1] # now a 3-vector
for k = n:-1:1
    reverse_grad = pullbacks[k](reverse_grad)[1]
end
reverse_grad


# Indeed we match the gradient as computed with Zygote.jl:

@test reverse_grad ≈ gradient(𝐱 -> iteratef(𝐱, 𝐟, n), [0.1,0.2,0.3])[1]





# **Problem 2** Consider the simple function `exp_t` from Lab 1 for computing the Taylor series of exponential
# below. Write a function that implements back-propogation for this simple function by creating a vector of pullbacks.
# Treat each basic operation (`*`, `/`, etc.) as a separate function.
# Hint: `s/k` is independent of `z` so no pullback is needed. 
# To compute the pullback of `a*z` we can call `pullback(*, a, z)` which when evaluated gives a tuple for both perturbing
# `a` and `z`. So we need to ignore the former. A similar argument works with `a + z` and `pullback(+, a, z)`.


function exp_t(z, n)
    ret = 1.0
    s = 1.0
    𝐳 = [z,s,ret]
    for k = 1:n
        𝐳 = [

        s = s/k * z
        ret = ret + s
    end
    ret
end


function exp_t_pullback(z, n)
    pullbacks_div = Any[]
    pullbacks_mul = Any[]
    pullbacks_ret = Any[]
    ret = 1.0
    s = 1.0
    ## TODO: Populate the vector pullbacks corresponding to the algorithm above
    ## SOLUTION
    for k = 1:n
        s,pₖ = pullback(/, s, k)
        push!(pullbacks_div, pₖ)
        s,pₖ = pullback(*, s, z)
        push!(pullbacks_mul, pₖ)
        ret,pₖ = pullback(+, ret, s)
        push!(pullbacks_ret, pₖ)
    end
    ## END
    pullbacks_div, pullbacks_mul, pullbacks_ret
end

function exp_t_backprop(pullbacks_mul, pullbacks_ret)
    s_der = 0.0
    z_der = 0.0
    ret_der = 1.0
    ## TODO: loop through pullbacks to compute the derivative. Be careful about the return value being a tuple.
    ## SOLUTION
    ## Its easiest to think of this as a sequence of Jacobians. We have the maps
    ## [z,s,ret] ↦ [z, s/k * z, ret + s/k * z]
    ## Hence the Jacobian is [1 0 0; s/k z/k 0; s/k z/k 1]
    ## and its transpose is [1 s/k s/k; 0 z/k z/k; 0 0 1] == [1 s/k s/k; 0 z/k z/k; 0 0 1]
    ## The last map is then [z,s,ret] ↦ ret
    ## which has the Jacobian [0 0 1]
    ## These maps are hidden in the pullbacks. In particular we have
    ## 

    n = length(pullbacks_mul)
    for k = n:-1:1
        ret_der,s_der = pullbacks_ret[k](ret_der)
        s_der,z_der = pullbacks_mul[k](s_der)
        s_der = pullbacks_div[k](s_der)[1]
    end
    reverse_der
    ## END
end

pullbacks_div, pullbacks_mul, pullbacks_ret = exp_t_pullback(1.0, 1)

k = 1
ret_der,s_der = pullbacks_ret[k](ret_der)
s_der,z_der = pullbacks_mul[k](s_der)
s_der = pullbacks_div[k](s_der)[1]

mul_der = 0.0
ret_der = 0.0
z_der = 1.0

p

Zygote.gradient(z -> exp_t(z,2), 1.0)

pullbacks_ret[end](1)
pullbacks_ret[end](1)

exp_t_backprop(exp_t_pullback(1.0, 20)...)


# ## 3.5 Optimisation

# A key place where reverse-mode automatic differentiation is essential is large scale optimisation.
# As an extremely simple example we will look at the classic optimisation problem
# solving $A 𝐱 = 𝐛$ where $A$ is symmetric positive definite: find $𝐱$ that minimises
# $$
# f_{A,𝐛}(𝐱) = 𝐱^⊤ A 𝐱 - 2𝐱^⊤ 𝐛.
# $$.
# Of course we can use tried-and-true techniques implemented in `\` but here we want
# to emphasise we can also solve this with simple optimsation algorithms like gradient desecent
# which do not know the structure of the problem. We consider a matrix where we know gradient descent
# will converge fast:
# $$
# A = \begin{bmatrix} 1 & 1/4 \\ 1/4 & 1 & ⋱ \\ &  ⋱ & ⋱ & 1/n^2 \\ && 1/n^2 & 1 \end{bmatrix}
# $$
# In other words we want to minimise the functional (or the _loss function_)
# $$
# f_{A,𝐛}(𝐱) = ∑_{k=1}^n x_k^2 - ∑_{k=2}^n x_{k-1} x_k/k^2 - ∑_{k=1}^n x_k b_k.
# $$
# For simplicity we will take $𝐛$ to be the vector with all ones.

# Owing to the constraints of Zygote.jl, we need to write this in a vectorised way to ensure Zygote is sufficiently fast. 
# Here we see that when we do this we can efficiently
# compute gradients even
# with a million degrees of freedom, way beyond what could ever be done with forward-mode automatic differentiation:

## DEMO
n = 1_000_000
f = x -> (x'x + 2x[1:end-1]'*(x[2:end] ./ (2:n).^2)) - 2sum(x)

x = randn(n) # initial guess
Zygote.gradient(f, x) # compile
@time Zygote.gradient(f, x)
## END

# For concreteness we first implement our own version of a quick-and-dirty gradient descent:
# $$
# x_{k+1} = x_k - γ_k ∇f(x_k)
# $$
# where $γ_k$ is the learning rate. To choose $γ_k$ we just halve
# the learning rate until we see decrease in the loss function.


for k = 1:100
    γ = 1
    y = x - γ*Zygote.gradient(f, x)[1]
    while f(x) < f(y)
        γ /= 2 # half the learning rate
        y = x - γ*Zygote.gradient(f, x)[1]
    end
    x = y
    @show γ,f(x)
end


# We can compare this with the "true" solution:

A = SymTridiagonal(ones(n), (2:n) .^ (-2))
@test x ≈ A\ones(n)

# In practice its better to use inbuilt optimsation routines and packages. Here we see how we can solve the same problem with
# the Optimization.jl package. Here we need to rewrite our function to take in parameters:
n = 10_000
f = (x,n) -> (x'x + 2x[1:end-1]'*(x[2:end] ./ (2:n).^2)) - 2sum(x)

using Optimization, OptimizationOptimJL


x = randn(n) # initial guess
prob = OptimizationProblem(OptimizationFunction(f, Optimization.AutoZygote()), x, n)
@time y = solve(prob, GradientDescent(), maxiters=100);





# We will do an example that will connect to neural networks.


n = 100
x = range(-1, 1; length = n)
y = exp.(x)

function summation_model(x, (𝐚, 𝐛))
    Y = relu.(𝐚*x' .+ 𝐛)
    vec(sum(Y; dims=1)) # sums over the columns
end

convex_regression_loss((𝐚, 𝐛), (x,y)) = norm(summation_model(x, (𝐚, 𝐛)) - y)

𝐚,𝐛 = randn(n),randn(n)
plot(x, summation_model(x, (𝐚, 𝐛)))

# We can efficiently compute the gradient with respect to the parameters:

@time Zygote.gradient(convex_regression_loss, (𝐚, 𝐛), (x,y))[1]




loss = convex_regression_loss((𝐚,𝐛), (x,y))
for k = 1:100
    γ = 0.01
    (a_n, b_n) = (𝐚, 𝐛) .- γ.*Zygote.gradient(convex_regression_loss, (𝐚, 𝐛), (x,y))[1]
    while loss < convex_regression_loss((a_n, b_n), (x,y))
        γ /= 2 # half the learning rate
        (a_n, b_n) = (𝐚, 𝐛) .- γ.*Zygote.gradient(convex_regression_loss, (𝐚, 𝐛), (x,y))[1]
    end
    (𝐚, 𝐛) = (a_n, b_n)
    global loss = convex_regression_loss((𝐚,𝐛), (x,y))
    @show γ,loss
end

plot(x, y)
plot!(x, summation_model(x, (𝐚, 𝐛)))


# prob = OptimizationProblem(OptimizationFunction(convex_regression_loss, Optimization.AutoZygote()), y0, (1,1,1/n))



# **Problem 2** 

## SOLUTION
n = 100; h = 1/n;

y = ones(n)
f = y -> sum(y[1:end-1] .* sqrt.(1 .+ ((y[2:end] - y[1:end-1])/h) .^2))/n

@time Zygote.gradient(f, y)

for k = 1:1_000
    γ = 1
    z = y - γ*Zygote.gradient(f, y)[1]
    z[1] = z[end] = 1
    while f(y) < f(z)
        γ /= 2 # half the learning rate
        z = y - γ*Zygote.gradient(f, y)[1]
        z[1] = z[end] = 1
    end
    y = z
    @show γ,f(y)
end

plot(y)
## END