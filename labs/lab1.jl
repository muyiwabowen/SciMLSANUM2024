# # SciML SANUM2024
# # Lab 1: Introduction to Julia

# This first lab introduces the basics of Julia and some of its unique features in terms of creating custom types.
# This will become valuable in implementing automatic-differentiation for generic code, a feature that
# is particularly useful for SciML as it allows combining neural networks with general time-steppers.

# **Learning Outcomes**
#
# 1. Creating functions, both named and anonymous.
# 2. The notion of a type and how to make your own type.
# 3. Defining functions whose arguments are restricted to specific types.
# 4. Overloading functions like `+`, `*`, and `exp` for a custom type.
# 5. Construction of a dense `Vector` or `Matrix` either directly or via comprehensions or broadcasting.

# ## 1.1 Functions in Julia

# Functions are created in a number of ways.
# The most standard way is using the keyword `function`, 
# followed by a name for the function, 
# and in parentheses a list of arguments.  
# Let's make a function that takes in a 
# single number $x$ and returns $x^2$.  


function sq(x)
   x^2 
end
sq(2), sq(3)

# There is also a convenient syntax for defining functions on
# one line, e.g., we can also write

sq(x) = x^2

# Julia is a compiled language: the first time we run a command on a specific type it compiles for that type.
# The second time it is called on a type it reuses the precompiled function:

@time sq(5) # Already compiled for Int so very fast
@time sq(1.3) # Needs to recompile for Float64 (the typeof of `1.3`) so takes extra time to compile
@time sq(5.6) # It reuses the compiled code from the previous call


# Multiple arguments to the function can be included with `,`.  
# Here's a function that takes in 3 arguments and returns the average.  
# (We write it on 3 lines only to show that functions can take multiple lines.)

function av(x, y, z)
    ret = x + y
    ret = ret + z
    ret/3
end
av(1, 2, 3)

# Variables live in different scopes.  In the previous example, `x`, `y`, `z` and `ret` are _local variables_: 
# they only exist inside of `av`.  
# So this means `x` and `z` are _not_ the same as our complex number `x` and `z` defined above.

# **Warning**: if you reference variables not defined inside the function, they will use the outer scope definition.  
# The following example shows that if we mistype the first argument as `xx`, 
# then it takes on the outer scope definition `x`, which is a complex number:


function av2(xx, y, z)
    (x + y + z)/3
end

# You should almost never use this feature!!  
# We should ideally be able to predict the output of a function from knowing just the inputs.

# **Example**
# Let's create a function that calculates the average of the entries of a vector.  

function vecaverage(v)
    ret = 0
    for k = 1:length(v)
        ret = ret + v[k]
    end
    ret/length(v)
end
vecaverage([1,5,2,3,8,2])

# Julia has an inbuilt `sum` command that we can use to check our code:

sum([1,5,2,3,8,2])/6

# ### Anonymous (lambda) functions

# Just like Python it is possible to make anonymous functions,
# with two variants on syntax:

f = x -> x^2
g = function(x)
    x^2
end

# There is not much difference between named and anonymous functions,
# both are compiled in the same manner. The only difference is
# named functions are in a sense "permanent". One can essentially think of
# named functions as "global constant anonymous functions".


# ## 1.2 Types in Julia


# Before we can use a concept like dual numbers we have to understand the notion of a "type".
# In compiled languages like Julia everything has a "type". The function `typeof` can be used to determine the type of,
# for example, a number.
# By default when we write an integer (e.g. `-123`) it is of type `Int`:

typeof(5)

# On a 64-bit machine this will print `Int64`, where the `64` indicates it is using precisely 64 bits
# to represent the number (a topic we will come back to in Part II). If we write something with
# a decimal point it represents a "real" number, whose storage is of type `Float64`:

typeof(5.3)

# This is called a "floating point" number, and again the `64` indicates it is using precisely
# 64 bits to represent this number. (We will see this is why computations like divided differences
# have large errors: because we are limiting the number of "digits" to represent numbers we need to
# round our computations.) Note that some operations involving `Int`s return `Float64`s:

1/5 # 1 and 5 are Int but output is a Float64

# It is possible to have functions behave differently depending on the input type.
# To do so we can add a restriction denoted `::Int` or `::Float64` to the function "signature".
# Here we create a function `foo` that is equal to `1` if the input is an `Int`, `0` if the input is
# a `Float64`, and `-1` otherwise:

foo(x::Int) = 1 # The ::Int means this version is called when the input is an Int
foo(x::Float64) = 0
foo(x) = -1 # This is equivalent to f(x::Any) = -1
            # Anything that is not an Int or Float64 will call this

foo(3), foo(2.5), foo("hi"), foo(3.0)


# The last line returns a list of `Int`s, which has the type `Tuple`.
# Note that there is a difference between an "integer" and the type `Int`: whilst 3.0 is an integer
# its type is `Float64` so `foo(3.0) == 0`.

# **Remark** Every type has a "supertype", which is an "abstract type": something you can't make an instance of it.
# For example, in the same way that "integers"
# are subsets of the "reals" we have that `Int` and `Float64` are subtypes of
# `Real`. Which is a subtype of `Number`. Which, as is everything, a subtype of `Any`.

# Types allow for combining multiple numbers (or instances of other types) to represent a more complicated
# object. A simple example of this is a complex number,
# which stores two real numbers $x$ and $y$ (either `Int` or `Float64` or indeed other real number types not yet discussed)
# to represent the complex number $x + {\rm i} y$. In Julia ${\rm i} = \sqrt{-1}$ is denoted `im` and
# hence we can create a complex number like $1+2{\rm i}$ as follows:

z = 1 + 2im

# This complex number has two "fields": the real and imaginary part. Accessing the fields is done
# using a `.`, here we display the real and imaginary parts as a `Tuple`:

z.re, z.im

# When we ask  its type we see it is a `Complex{Int}`:

typeof(z)

# The `{Int}` indicates that each of the fields is an `Int`.
# Note we can add, subtract, multiply, or apply functions like `exp` to complex numbers:

exp(2z^2 + 3im)

# -----
# **Problem 1(a)** Use `typeof` to determine the type of `1.2 + 2.3im`.

## TODO: What is the type of `1.2 + 2.3im`?



# **Problem 1(b)** Add another implementation of `foo` that returns `im` if the input
# is a `ComplexF64`.

## TODO: Overload foo for when the input is a ComplexF64 and return im


@test foo(1.1 + 2im) == im

# ------

# **Problem 2(a)** Consider the Taylor series approximation to the exponential:
# $$
# \exp z ≈ ∑_{k=0}^n {z^k \over k!}
# $$
# Complete the function `exp_t(z, n)` that computes this and returns a
# `Complex{Float64}` if the input is complex and a `Float64` if the input is real.
# Do not use the inbuilt `factorial` function.
# Hint: It might help to think inductively: for $s_k = z^k/k!$ we have
# $$
#   s_{k+1}  = {z \over k+1} s_k.
# $$

function exp_t(z, n)
    ## TODO: Compute the first (n+1)-terms of the Taylor series of exp
    ## evaluated at z
    
end

@test exp_t(1.0, 10) isa Float64 # isa is used to test the type of a result
@test exp_t(im, 10) isa ComplexF64 # isa is used to test the type of a result

@test exp_t(1.0, 100) ≈ exp(1)


# ### Making our own Types


# One of the powerful parts of Julia is that it's very easy to make our own types. Lets begin with a simple
# implementation of a rational function $p/q$ where $p$ and $q$ are `Int`s.  Thus we want to create a new
# type called `Rat` with two fields `p` and `q` to represent the numerator and denominator, respectively.
# (For simplicity  we won't worry about restricting $p$ and $q$ to be `Int`.)
# We can construct such a type using the `struct` keyword:

struct Rat
    p
    q
end

# A new instance of `Rat` is created via e.g. `Rat(1, 2)` represents 1/2
# where the first argument specifies `p` and the second argument `q`.
# The fields are accessed by `.`:

x = Rat(1, 2) # Rat(1, 2) creates an instance with fields equal to the input
@test x.p == 1
@test x.q == 2

# Unfortunately we can't actually do anything with this type, yet:

x + x

# The error is telling us to overload the `+` function when the inputs are both `Rat`.
# To do this we need to "import" the `+` function and then we can overload it like any
# other function:

import Base: + # allows us to overload +

## Here putting ::Rat after both x and y means this version of +
## is only called if both arguments are Rat
function +(x::Rat, y::Rat)
    p,q = x.p,x.q # x represents p/q
    r,s = y.p,y.q # y represents r/s
    Rat(p * s + r * q, q * s)
end

Rat(1,2) + Rat(3,4) # 1/2 + 3/4 == 10/8 (== 5/4) which is represented
                    ## as Rat(10, 8)

# We can support mixing `Rat` and `Int` by adding additional functionality:

Rat(p::Int) = Rat(p,1) # an Int is converted to p/1
+(x::Rat, y::Int) = x + Rat(y) # To add a Rat to an Int we convert the Int into a Rat and use the previously defined +

Rat(1,2) + 1  # 1 + 1/2 == 3/2

# -----

# **Problem 3** Support `*`, `-`, `/`, and `==` for `Rat` and `Int`.

## We import `+`, `-`, `*`, `/` so we can "overload" these operations
## specifically for `Rat`.
import Base: +, -, *, /, ==

## The ::Rat means the following version of `==` is only called if both
## arguments are Rat.
function ==(x::Rat, y::Rat)
    ## TODO: implement equality, making sure to check the case where
    ## the numerator/denominator are possibly reducible
    ## Hint: gcd and div may be useful. Use ? to find out what they do

    
end

## We can also support equality when `x isa Rat` and `y isa Int`
function ==(x::Rat, y::Int)
    ## TODO: implement
    
end

## TODO: implement ==(x::Int, y::Rat)


@test Rat(1, 2) == Rat(2, 4)
@test Rat(1, 2) ≠ Rat(1, 3)
@test Rat(2,2) == 1
@test 1 == Rat(2,2)

## TODO: implement +, -, *, and /,


@test Rat(1, 2) + Rat(1, 3) == Rat(5, 6)
@test Rat(1, 3) - Rat(1, 2) == Rat(-1, 6)
@test Rat(2, 3) * Rat(3, 4) == Rat(1, 2)
@test Rat(2, 3) / Rat(3, 4) == Rat(8, 9)


# ## 1.3 Arrays


# One can create arrays in multiple ways. For example, the function `zeros(Int, 10)` creates
# a 10-element `Vector` whose entries are all `zero(Int) == 0`. Or `fill(x, 10)` creates a
# 10-element `Vector` whose entries are all equal to `x`. Or you can use a comprehension:
# for example `[k^2 for k = 1:10]` creates a vector whose entries are `[1^2, 2^2, …, 10^2]`.
# This also works for matrices: `zeros(Int, 10, 5)` creates a 10 × 5 matrix of all zeros,
# and `[k^2 + j for k=1:3, j=1:4]` creates the following:

[k^2 + j for k=1:3, j=1:4] # k is the row, j is the column

# Note sometimes it is best to create a vector/matrix and populate it. For example, the
# previous matrix could also been constructed as follows:

A = zeros(Int, 3, 4) # create a 3 × 4 matrix whose entries are 0 (as Ints)
for k = 1:3, j = 1:4
    A[k,j] = k^2 + j # set the entries of A
end
A

# **Remark** Julia uses 1-based indexing where the first index of a vector/matrix
# is 1. This is standard in all mathematical programming languages (Fortran, Maple, Matlab, Mathematica)
# whereas those designed for computer science use 0-based indexing (C, Python, Rust).



# Be careful: a `Matrix` or `Vector` can only ever contain entries of the right
# type. It will attempt to convert an assignment to the right type but will throw
# an error if not successful:

A[2,3] = 2.0 # works because 2.0 is a Float64 that is exactly equal to an Int
A[1,2] = 2.3 # fails since 2.3 is a Float64 that cannot be converted to an Int


# ------
# **Problem 1(a)** Create a 5×6 matrix whose entries are `Int` which is
# one in all entries. Hint: use a for-loop, `ones`, `fill`, or a comprehension.
## TODO: Create a matrix of ones, 4 different ways


# **Problem 1(b)** Create a 1 × 5 `Matrix{Int}` with entries `A[k,j] = j`. Hint: use a for-loop or a comprehension.

## TODO: Create a 1 × 5  matrix whose entries equal the column, 2 different ways


# -------
# ### Transposes and adjoints

# We can also transpose a matrix `A` via `transpose(A)`
# or compute the adjoint (conjugate-transpose) via `A'` (which is
# equivalent to a transpose when the entries are real).
# This is done _lazily_: they return custom types `Transpose` or
# `Adjoint` that just wrap the input array and reinterpret the entries.
# This is equivalent to
# _row-major_ format, where the next address in memory of `transpose(A)` corresponds to
# moving along the row.
# Here is a simple example:

A = [1+im  2  3;
     4     5  6;
     6     8  9]

A' # adjoint (conjugate-transpose). If entries are real it is equivalent to transpose(A)

# If we change entries of `A'` it actually changes entries of `A` too since
# they are pointing to the same locations in memory, just interpreting the data differently:

A'[1,2] = 2+im
A # A[2,1] is now 2-im

# Note vector adjoints/transposes behave differently than 1 × n matrices: they are
# more like row-vectors. For example the following computes the dot product of two vectors:

x = [1,2,3]
y = [4,5,6]
x'y # equivalent to dot(x,y), i.e. the standard dot product.

# ### Broadcasting

# _Broadcasting_ is a powerful and convenient way to create matrices or vectors,
# where a function is applied to every entry of a vector or matrix.
# By adding `.` to the end of a function we "broadcast" the function over
# a vector:

x = [1,2,3]
cos.(x) # equivalent to [cos(1), cos(2), cos(3)], or can be written broadcast(cos, x)

# Broadcasting has some interesting behaviour for matrices.
# If one dimension of a matrix (or vector) is `1`, it automatically
# repeats the matrix (or vector) to match the size of another example.
# In the following we use broadcasting to pointwise-multiply a column and row
# vector to make a matrix:

a = [1,2,3]
b = [4,5]

a .* b'

# Since `size([1,2,3],2) == 1` it repeats the same vector to match the size
# `size([4,5]',2) == 2`. Similarly, `[4,5]'` is repeated 3 times. So the
# above is equivalent to:

A = [1 1;
     2 2;
     3 3] # same as [a a], i.e. repeat the vector a in each column
B = [4 5;
     4 5;
     4 5] # same as [b'; b' b'], i.e. repeat the row vector b' in each row

A .* B # equals the above a .* b'

# Note we can also use matrix broadcasting with our own functions:

f = (x,y) -> cos(x + 2y)
f.(a, b') # makes a matrix with entries [f(1,4) f(1,5); f(2,4) f(2,5); f(3,4) f(3.5)]


# ### Ranges

# _Ranges_ are another useful example of vectors, but where the entries are defined "lazily" instead of
# actually created in memory.
# We have already seen that we can represent a range of integers via `a:b`. Note we can
# convert it to a `Vector` as follows:

Vector(2:6)

# We can also specify a step:

Vector(2:2:6), Vector(6:-1:2)

# Finally, the `range` function gives more functionality, for example, we can create 4 evenly
# spaced points between `-1` and `1`:

Vector(range(-1, 1; length=4))

# Note that `Vector` is mutable but a range is not:

r = 2:6
r[2] = 3   # Not allowed

# Both ranges `Vector` are subtypes of `AbstractVector`, whilst `Matrix` is a subtype of `AbstractMatrix`.


# -----

# **Problem 1(c)** Create a vector of length 5 whose entries are `Float64`
# approximations of `exp(-k)`. Hint: use a for-loop, broadcasting `f.(x)` notation, or a comprehension.
## TODO: Create a vector whose entries are exp(-k), 3 different ways


# ### Linear algebra

# A `Vector` stores its entries consecutively in memory.
# To be perhaps overly technical: a `Vector` contains a "pointer" (an integer)
# to the first memory address and a length. A `Matrix` is also stored consecutively in memory
#  going down column-by-
# column (_column-major_). That is,

A = [1 2;
     3 4;
     5 6]

# Is actually stored equivalently to a length `6` vector `[A[1,1],A[2,1],A[3,1],A[1,2],A[2,2],A[3,2]]`:

vec(A)

# which in this case would be stored using `8 * 6 = 48` consecutive bytes.
# Behind the scenes, a matrix is also "pointer" to the location of the first entry alongside two integers
# dictating the row and column sizes.


# Matrix-vector multiplication works as expected because `*` is overloaded:

x = [7, 8]
A * x
