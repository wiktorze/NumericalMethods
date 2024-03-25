### A Pluto.jl notebook ###
# v0.19.37

using Markdown
using InteractiveUtils

# ╔═╡ 313a1e80-7b42-11eb-2b4c-cd7fe27b5483
# load some packages
begin
	using NLopt
	using DataFrames
	using Ipopt
	using JuMP
	using LinearAlgebra
	using Statistics
	using Plots
end

# ╔═╡ c69606ac-7b41-11eb-075f-27802f4d671e
md"
# A Portfolio Choice Problem

We want to solve the portfolio allocation problem of an investor. You can think that they want to keep some part of their endowment for consumption $c$, and invest the remainder into one of $n$ financial assets. You can think about this as an intertemporal choices (consumption _today_ vs consumption _tomorrow_), but it is not necessary. 

* Assume we have $n$ assets, and asset number 1 is the safe asset. It will pay 1 in any state.
* Assets $i=2,\dots,n$ are risky and pay out $z_i^s$ in state $s=1,\dots,S$
* State $s$ occurs with probability $\pi^s$
* The investor is characterized by
    * an initial endowment of each asset: $(e_1,e_2,\dots,e_n)$
    * a utility function $u(c) = -\exp(-ac)$
* The problem of the investor is to choose consumption $c$ and how much of each asset to hold. $\omega_i$ represents the number of units of asset $i$ the investor wants to hold. Notice that there is no constraint on $\omega_i$, so could be negative or positive.
$$\begin{align}
    \max_{c,\omega_1,\dots,\omega_n} u(c) + \sum_{s=1}^S \pi^s u \left( \sum_{i=1}^n \omega_i z_i^s \right) \quad (1)\\
    \text{subject to   } c + \sum_{i=1}^n p_i \omega_i = \sum_{i=1}^n p_i e_i  \quad (2)\\
c \geq 0,\quad w_i \in \mathbb{R}
\end{align}$$

## Setup

* Assume $n=3,p=(1,1,1),e=(2,0,0)$ and suppose that $z_2 = (0.72,0.92,1.12,1.32),z_3=(0.86,0.96,1.06,1.16)$. Each of these realizations is equally likely to occur, and all assets are independent. This means we have a total of $4\times4=16$ random states.

"

# ╔═╡ 4d3447d2-7b42-11eb-1ce3-095b89785f6c
md"
# Question 1: Data Creator

* write a function that creates the data used in this exercise.
* function `data(a = 0.5)` should return a `Dict` with keys `:a,:na,:nc,:ns,:nss,:e,:p,:zp,:z,:π`, where `:nc` is number of choice variables, `:ns` is number of states for each asset and `nss` is number of total states of the world, `:zp` is a matrix of payoffs for each asset (`4 x 3`).
* I suggest to create a `z` matrix which has one column for each asset, and one row for each state of the world. Notice that *independence* of assets implies that it's equally likely to have $(z_2^1, z_3^1)$ (both risky assets in same state of world $s=1$, as it is to have $(z_2^3, z_3^2)$. The first column of `z` is all ones (the safe asset pays 1 in each state of the world). There should be 16 rows."



# ╔═╡ 06219b52-7b43-11eb-3ca9-c334f6d53908
function data(a=0.5)
	na = 3
	nc = na + 1
	ns = 4
	nss = ns^2
	e = [2, 0, 0]
	p = ones(3)
	z1 = ones(4)
	z2 = [0.72, 0.92, 1.12, 1.32]
	z3 = [0.86, 0.96, 1.06, 1.16]
	zp = hcat(z1,z2,z3)
	
	z = zeros(16, 3)
	
	for i in 1:4
	    for j in 1:4
	        index = (i - 1) * 4 + j
	        z[index, 1] = z1[1]
	        z[index, 2] = z2[i]
	        z[index, 3] = z3[j]
	    end
	end
	π = ones(nss) / nss
	
	return Dict(:a => a, :na => na, :nc => nc, :ns => ns, :nss => nss, :e => e, :p => p, :z => z, :zp => zp, :π => π)
end

# ╔═╡ f07efffc-7cd9-11eb-15aa-338b74552e6a
md"
## Question 1.2

👉 What is the expected payoff of each asset if the portfolio is $(\omega_1,\omega_2,\omega_3) = (1,1,1)$? Write a function `mean_payoff(d)` that returns a `Array` (1, 3),  computing the average payoff across all 4 states of the world for each asset, i.e. columns $i$ is

$$\sum_{s=1}^S \pi^s \omega_i z_i^s$$"

# ╔═╡ 03302a44-7cdb-11eb-0e34-73d2add94f8e
mean_payoff(d) =  mean(d[:zp],dims=1)

# ╔═╡ d44226c2-7cda-11eb-1e95-d5c362a2a27c
md"
## Question 1.3

👉 What is the variance of each asset's payoff if the portfolio is $(\omega_1,\omega_2,\omega_3) = (1,1,1)$? Write a function `var_payoff(d)` that returns a `Array` (1, 3),  computing the variance of payoff across all 4 states of the world for each asset.


"

# ╔═╡ 12a088f2-7cdb-11eb-01a6-21baf4b9ba02
var_payoff(d) = var(d[:zp],dims=1)

# ╔═╡ 632f1fea-7ce5-11eb-17ab-b5d2e8fa6995
md"* How do you compare the assets, now that you know their average payoff and variance? Which ones would you choose to invest in, if any?
* How could we represent the way you think about this tradeoff?"

# ╔═╡ 39f70dac-7b45-11eb-16d7-316a34077ace
md"

## Question 2.1

> How could we represent the way you think about this tradeoff?

_Well, with a uility function of course!_

* Write down the given utility function `u` and it's first derivative `up`!
* Both take 2 arguments and return a number.
"

# ╔═╡ 5124ed8a-7b45-11eb-0984-a944bd9302e0
u(a,c) = -exp(-a*c)

# ╔═╡ 587f244c-7b45-11eb-0238-070d76122af1
up(a,c) = a*(exp(-a*c))

# ╔═╡ a6f5e970-7ce5-11eb-179c-39d4f242c202
md"
## Question 2.2

Let's generate some intuition before we attempt to solve this numerically. To do so, let's simplify the problem. So, suppose there is only one asset, endowment is given by the positive number $y$, and consumer cares about consumption today $c_1$ and tomorrow $c_2$, no discounting, no interest on savings. In short, the problem is

$$\begin{array}{c}
    \max_{c_1, c_2} u(c_1) + u(c_2) \\
    \text{subject to   } c_2 = y - c_1\\
c_i \geq 0
\end{array}$$

👉 Given the above utility function, what is the optimal level of consumption in each period?  

👉 Do you think this result will survive if we introduce uncertainty and asset choices?

**Don't look at the hint! It shows you the solution. First think about it a little while!** it is easy. 😉
"

# ╔═╡ c78a0e3d-fe92-4fe9-8c2b-da51c9651648
md"""
The optimal level of consumption is $c_1 = c_2 = \frac{y}{2}$. If $u$ were linear, the solution will stay the same.
Let's take $u(c) = \frac{c}{4}$.
Then $\frac{c}{4} = y - \frac{c}{4}$
$c = \frac{y}{2}$.
The solution stays the same
"""

# ╔═╡ d5555454-7da6-11eb-052e-7313220e3edb
md"

## Question 2.3

Let's look at the utility function!

👉 make a plot that shows $u(c,a)$ for different values of $a$!
"

# ╔═╡ f22090dc-7da6-11eb-29dc-51aac7458cb2
let
	c_values = 0:0.1:5
	a_values = [0.2,0.4,0.6,0.8,1.0]
	
	plot()
	for a in a_values
		u_values=u.(c_values,a)
		plot!(c_values,u_values,label="a=$a")
	end
	xlabel!("c")
	ylabel!("u(c, a)")
	title!("Utility Function for Different Values of a")
end

# ╔═╡ 1910d264-7da8-11eb-1434-fb54dbeda64c
md"

### Question 2.4


* What is this expression called in economics, and what is it equal to here?

$$\frac{-u''(c)}{u'(c)}$$

* What's your interpretation of the number $a$ in this context? How do you expect our investor to behave as $a$ increases?

"

# ╔═╡ fca315d4-d092-4eed-9d5b-62ad815cfdee
md"""
This is the formula for constant relative risk aversion. As a increases, the utility function is steeper.
In this context, a can be interpreted as the constant level of risk aversion for a given wealth. As a increases, we expect a higher level of relative risk aversion for all levels of wealth.
"""

# ╔═╡ 13b50308-7b46-11eb-034c-c3e2b017e5e9
md"

# 3. Numerical Solution to the problem

Here is the correct solution to the problem for three different values of `a`. We will compare your solution against this dataframe. Please compute a solution for $a\in\{0.5,1,1.5\}$.
"

# ╔═╡ c1a8d1ec-7b99-11eb-02bb-6917b65f33a7
solution = DataFrame(a=[0.5;1.0;5.0],c = [1.008;1.004;1.0008],omega1=[-1.41237;-0.20618;0.758763],omega2=[0.801455;0.400728;0.0801455],omega3=[1.60291;0.801455;0.160291],fval=[-1.20821;-0.732819;-0.013422])

# ╔═╡ b1e51722-7b99-11eb-33ec-9dc089e8b7fe
md"

## 3.1. Solve this problem using `NLopt`


* Define 2 functions `obj(x::Vector,grad::Vector,data::Dict)` and `constr(x::Vector,grad::Vector,data::Dict)`, similar to the way we set this up in class.
* In particular, remember that both need to modify their gradient `in-place`. 

👉 `obj` returns the value of equation (1) and its gradient wrt all choice variables in `grad`

👉 `constr` returns the value of equation (2) and its gradient wrt all choice variables in `grad`

"

# ╔═╡ 32f9d464-7b46-11eb-274c-0713593fe800
function obj(x::Vector, grad::Vector, data::Dict)
    a = data[:a]
    zp = data[:zp]
    π = data[:π]
    # Extract relevant data
    na = data[:na]
    nc = data[:nc]
    ns = data[:ns]
    nss = data[:nss]
    e = data[:e]
	z = data[:z]
    # Extract choice variables
    c = x[1]
    ω = x[2:end]
   	f = u(a,c) + u.(a, z*ω)'*π
	grad[1] = up(a, c)
	for i in 1:na
		grad[i+1] = sum([up.(a, z*ω)[s]*π[s]*z[s,i] for s in 1:nss])
	end
    return f
end

# ╔═╡ 3af65458-7b46-11eb-2d0c-e5a480ffe003
function constr(x::Vector, grad::Vector, data::Dict)
    # Extract relevant data
    p = data[:p]
    e = data[:e]
    # Extract choice variables
    c = x[1]
    ω = x[2:end]
    # Compute constraint value and gradient
    g = c + sum(p .* ω) - sum(p .* e)
	if length(grad) >0 
	    grad[1] = 1.0
	    grad[2:end] = p
	end
    return g
end

# ╔═╡ 389f51a0-7cea-11eb-19a3-438cb29fc2e0
md"

## 3.2 Numerically Solve!

now call the NLopt solver to get the solution.

👉 write a function `max_NLopt(a=0.5)` which 
1. creates a data set with `data(a)`
2. sets up an `Opt` instance using the `:LD_SLSQP` algorithm for equality constraints.
3. sets objective, equality constraint, and bounds
4. returns a tuple `(optf,optx,ret)` with `(optimal f value, optimal choice, return code)`
5. choose as starting value $0.2$ for all choice variables.
"
	

# ╔═╡ 742bf3ec-a9bb-44ac-a3be-6e5c624222c4
function max_NLopt(a = 0.5)
	
	d = data(a)

	num_variables = d[:na] + 1

    opt = Opt(:LD_SLSQP, num_variables)
	opt.lower_bounds = [0.0; fill(-Inf, num_variables -1)]
	opt.xtol_rel = 1e-4

	function objective_wrapper(x::Vector, grad::Vector)
        return obj(x, grad, d)
    end
	
    opt.max_objective = objective_wrapper
	
	equality_constraint!(opt, (x, g) -> constr(x, g, d), 1e-8)

	x_init = fill(0.2, num_variables)

    (optf, optx, ret) = optimize(opt, x_init)

    return (optf, optx, ret)


end

# ╔═╡ 74ada204-7ceb-11eb-0f48-ddc9c1a5fec8
md"Here is your answer: check the return code! somthing like `:FTOL_REACHED` would be good!"

# ╔═╡ 504b0b2d-f7ce-4a80-b148-ad4c438f8139
nlopt_res = max_NLopt()

# ╔═╡ e5233fa0-7b9a-11eb-39cc-c70c0addca97
md"check that the budget constraint is satisfied at this solution"

# ╔═╡ ef08e970-7b9a-11eb-203d-41095002a3b7
constr(nlopt_res[2],zeros(4),data()) == 0.0

# ╔═╡ aa8e4912-7ceb-11eb-0705-2bf588d303fe
md"

### 3.3 checking

What is the expected utility of the optimal investment portfolio, i.e.  what is this number?

$$\sum_{s=1}^S \pi^s u \left( \sum_{i=1}^n \omega_i^* z_i^s \right)$$

👉 write a function `exp_u(a=0.5)` which 
1. creates a data set with `data(a)`
2. gets your solution with `max_NLopt(a)`
3. Returns the above expression
"

# ╔═╡ 2de86fba-7b9b-11eb-379d-0b0f85d9c9a3
function exp_u(a=0.5)
	d = data(a)
	nlopt_res = max_NLopt(d[:a])
    ω = nlopt_res[2][2:end]
	return u.(d[:a], d[:z]*ω)'*d[:π]
end

# ╔═╡ f910cfce-7b9b-11eb-3162-9be77eb705ee
md" 

### 3.4 Checking $u$

And finally: what is $u(c^*)$?

👉 write a function `opt_c(a=0.5)` which 
1. gets your solution with `max_NLopt(a)`
2. Returns $u(c^*)$


I'll then check whether `opt_c(a) ≈ exp_u(a)`!
"

# ╔═╡ 8913fa58-7cec-11eb-1bfa-cf84ef627bd2
function opt_c(a=0.5)
	nlopt_res = max_NLopt(a)
	u(a,nlopt_res[2][1])
end

# ╔═╡ 84b43576-7ced-11eb-37c3-5f6b595f0730
md"
### 3.5 Checking all your results

* In the next cell I run your model for all $a$ values!
"

# ╔═╡ f078be5a-7b4c-11eb-3f03-138505242d43
md"

# 4. Now solve with `JuMP`!

* Let's solve the identical problem with JuMP.jl now.
* write a function `max_JuMP(a)` that defines the constrained optimization problem
* it should return a dict with optimal values `:obj`, `:c` and `:omega`.
"

# ╔═╡ e7b74f8e-ffcc-4c8d-8d67-62d4fa05be79
function max_JuMP(a=0.5)
	m = Model(Ipopt.Optimizer)
	d = data(a)
	π = d[:π]
	p = d[:p]
	e = d[:e]
	z = d[:z]
	na = d[:na]

	@variable(m, c)
	@variable(m, ω[1:na])

	@NLexpression(m, z_dot_ω[i = 1:size(z, 1)], sum(z[i, j] * ω[j] for j in 1:length(ω)))

	@NLobjective(m, Max, u(a,c) + sum(u(a, z_dot_ω[i]) * π[i] for i in 1:size(z, 1)))
	@constraint(m, c + dot(ω,p) - dot(e,p) <= 0)

	JuMP.optimize!(m)
	s = Dict()
	s["obj"] = objective_value(m)
	s["c"] = value(c)
	s["omegas"] = value.(ω)
	return s
end


# ╔═╡ 0e41d664-7da6-11eb-3598-bd1ce2944ebd
md"
### 4.2 Checking all your results

* In the next cell I run your model for all $a$ values!
"

# ╔═╡ 7cc76266-7da6-11eb-3c61-6d4b7206c46c
md"

# 5. Going Further

Here are couple of fun things to try, often with minimal effort:

1. how does the solution change if $\omega_i \geq 0,\forall i$?
2. How does the solution change with a different utility function? In the Jump part, just use a different u!


"

# ╔═╡ 6bd9598d-817f-45eb-b2b7-d8629e78b178
function max_JuMP_nosell(a=0.5)
	m = Model(Ipopt.Optimizer)
	d = data(a)
	π = d[:π]
	p = d[:p]
	e = d[:e]
	z = d[:z]
	na = d[:na]

	@variable(m, c>=0)
	@variable(m, ω[1:na]>=0)

	@NLexpression(m, z_dot_ω[i = 1:size(z, 1)], sum(z[i, j] * ω[j] for j in 1:length(ω)))

	@NLobjective(m, Max, u(a,c) + sum(u(a, z_dot_ω[i]) * π[i] for i in 1:size(z, 1)))
	@constraint(m, c + dot(ω,p) - dot(e,p) <= 0)

	JuMP.optimize!(m)
	s = Dict()
	s["obj"] = objective_value(m)
	s["c"] = value(c)
	s["omegas"] = value.(ω)
	return s
end

# ╔═╡ 83812582-d6a1-448f-9630-8560c6833843
max_JuMP_nosell()

# ╔═╡ ecf9521c-97f7-4645-a111-da5a00dc4586
u2(a,c) = -a*c^2

# ╔═╡ 3f374470-d174-4bd1-84e5-aa4608fd91c0
function max_JuMP_u(a=0.5)
	m = Model(Ipopt.Optimizer)
	d = data(a)
	π = d[:π]
	p = d[:p]
	e = d[:e]
	z = d[:z]
	na = d[:na]

	@variable(m, c)
	@variable(m, ω[1:na])

	@NLexpression(m, z_dot_ω[i = 1:size(z, 1)], sum(z[i, j] * ω[j] for j in 1:length(ω)))

	@NLobjective(m, Max, u(a,c) + sum(u2(a, z_dot_ω[i]) * π[i] for i in 1:size(z, 1)))
	@constraint(m, c + dot(ω,p) - dot(e,p) <= 0)

	JuMP.optimize!(m)
	s = Dict()
	s["obj"] = objective_value(m)
	s["c"] = value(c)
	s["omegas"] = value.(ω)
	return s
end


# ╔═╡ 9b9ec0d6-e54f-4838-89c6-a1807ba59349
max_JuMP_u()

# ╔═╡ a1e0ec36-7cee-11eb-3e4c-69ad1c5d018f
md"Function Library"

# ╔═╡ 061b765e-7b4c-11eb-337a-61f8783875bb
function table_NLopt()
	d = DataFrame(a=[0.5;1.0;5.0],c = zeros(3),omega1=zeros(3),omega2=zeros(3),omega3=zeros(3),fval=zeros(3))
	for i in 1:nrow(d)
		xx = max_NLopt(d[i,:a])
		for j in 2:ncol(d)-1
			d[i,j] = xx[2][j-1]
		end
		d[i,end] = xx[1]
	end
	return d
end

# ╔═╡ 13d41f9e-7cf0-11eb-1e01-f1ddcbe01b8a
function table_JuMP()
	d = DataFrame(a=[0.5;1.0;5.0],c = zeros(3),omega1=zeros(3),omega2=zeros(3),omega3=zeros(3),fval=zeros(3))
	for i in 1:nrow(d)
		xx = max_JuMP(d[i,:a])
		d[i,:c] = xx["c"]
		d[i,:omega1] = xx["omegas"][1]
		d[i,:omega2] = xx["omegas"][2]
		d[i,:omega3] = xx["omegas"][3]
		d[i,:fval] = xx["obj"]
	end
	return d
end

# ╔═╡ 88317198-7b42-11eb-1364-470e8ef725d9
hint(text) = Markdown.MD(Markdown.Admonition("hint", "Hint", [text]))

# ╔═╡ f149f7b0-7ce6-11eb-207b-d3830fbf83ef
hint(md"""
$$\begin{array}{c}
    u(c_1) + u(c_2) \\
    \text{subject to   } c_2 = y - c_1\\
	\Rightarrow \\
	u(c_1) + u(y - c_1) \\
	u(c_1)' = u'(y - c_1) \\
	a \exp(-a c_1) = a \exp(-a (y - c_1)) \\
	 -a c_1 =  -a (y - c_1) \\	
 	2 c_1 =  y \\
	c_1^* = \frac{y}{2} = c_2^* 
\end{array}$$
	
So, consumption is *constant*. What's the solution to this question if $u$ were linear?
""")

# ╔═╡ babf2e98-7b42-11eb-09ef-1bfcc53d3d16
almost(text) = Markdown.MD(Markdown.Admonition("warning", "Almost there!", [text]))

# ╔═╡ bf3b2792-7b42-11eb-0e28-295cbed65a13
still_missing(text=md"Replace `missing` with your answer.") = Markdown.MD(Markdown.Admonition("warning", "Here we go!", [text]))

# ╔═╡ c47c5640-7b42-11eb-3b72-25362925c2d1
keep_working(text=md"The answer is not quite right.") = Markdown.MD(Markdown.Admonition("danger", "Keep working on it!", [text]))

# ╔═╡ c961ea44-7b42-11eb-3a35-bfd505fb99fb
yays = [md"Fantastic!", md"Splendid!", md"Great!", md"Yay ❤", md"Great! 🎉", md"Well done!", md"Keep it up!", md"Good job!", md"Awesome!", md"You got the right answer!", md"Let's move on to the next section."]

# ╔═╡ cd08f232-7b42-11eb-3b5b-55079d868638
correct(text=rand(yays)) = Markdown.MD(Markdown.Admonition("correct", "Got it!", [text]))

# ╔═╡ 0a5c81f2-7b4c-11eb-2a96-7163671eed67
let
	r = maximum(abs.(Array(solution .- table_NLopt())))
	if r > 1e-4
		keep_working(md"Your results are not close enough to the correct ones (above in `solution`!)")
	else
		correct()
	end
end

# ╔═╡ 19d9f3f8-7da6-11eb-169c-9765c55cfac6
let
	r = maximum(abs.(Array(solution .- table_JuMP())))
	if r > 1e-4
		keep_working(md"Your results are not close enough to the correct ones (above in `solution`!)")
	else
		correct()
	end
end

# ╔═╡ d0d5d506-7b42-11eb-0517-6318fd0ede8b
not_defined(variable_name) = Markdown.MD(Markdown.Admonition("danger", "Oopsie!", [md"Make sure that you define a variable called **$(Markdown.Code(string(variable_name)))**"]))

# ╔═╡ d4548c4a-7b42-11eb-294f-d1c27fe76543
not_definedf(variable_name) = Markdown.MD(Markdown.Admonition("danger", "Oopsie!", [md"Make sure that you define a function called **$(Markdown.Code(string(variable_name)))**"]))

# ╔═╡ 1532e6bc-7b43-11eb-3f27-59134ea6acc0
if !@isdefined(data)
	not_definedf(:data)
else
	let
		res = data()
		if res isa Missing
			still_missing()
		elseif !(res isa Dict)
			keep_working(md"Make sure you return a `Dict`")
		elseif !issetequal(collect(keys(res)),[:a,:na,:nc,:ns,:nss,:e,:p,:z,:zp,:π])
			keep_working(md"your Dict needs to have keys [:a,:na,:nc,:ns,:nss,:e,:p,:z,:π]")
		elseif res[:na] != 3
			keep_working(md"We need three assets!")
		elseif length(res[:e]) != 3
			keep_working(md"the :e vector needs to be 3 x 1!")
		elseif size(res[:z]) != (16,3)
			almost(md"your z matrix should be 16 x 3")
		elseif res[:e] != [2.0;0;0]
			almost(md"check your `:e` key! ")
		else
			correct()
		end
	end
end

# ╔═╡ 2757d17a-7cda-11eb-3694-65c409660196
if !@isdefined(mean_payoff)
	not_definedf(:mean_payoff)
else
	let
		d = data()
		res = mean_payoff(d)
		if res isa Missing
			still_missing()
		elseif !(res isa Array)
			keep_working(md"Make sure you return a 1 by 3 `Array`")
		elseif !(norm(res .- mean(d[:zp],dims=1)) < 1e-6)
			almost(md"your result is incorrect.")
		else
			correct()
		end
	end
end

# ╔═╡ 20316894-7cdb-11eb-2fec-f3f6876126ba
if !@isdefined(var_payoff)
	not_definedf(:var_payoff)
else
	let
		d = data()
		res = var_payoff(d)
		if res isa Missing
			still_missing()
		elseif !(res isa Array)
			keep_working(md"Make sure you return a 1 by 3 `Array`")
		elseif !(norm(res .- var(d[:zp],dims=1)) < 1e-6)
			almost(md"your result is incorrect.")
		else
			correct()
		end
	end
end

# ╔═╡ 6183c9a8-7b45-11eb-0bd5-1302c23d6570
if !@isdefined(u)
	not_definedf(:u)
else
	let
		a = 1.1
		c = 0.5
		res = u(a,c)
		if res isa Missing
			still_missing()
		elseif !(res == -exp(-a * c))
			keep_working(md"check your function definition! it's wrong.")
		else
			correct()
		end
	end
end

# ╔═╡ 5bef3e96-7b45-11eb-257a-09f7dbe66aaa
if !@isdefined(up)
	not_definedf(:up)
else
	let
		a = 1.1
		c = 0.5
		res = up(a,c)
		if res isa Missing
			still_missing()
		elseif !(res == a * exp(-a * c))
			keep_working(md"check your function definition! it's wrong.")
		else
			correct()
		end
	end
end

# ╔═╡ 241521be-7ceb-11eb-0553-2de70f4c57e9
if !@isdefined(max_NLopt)
	not_definedf(:max_NLopt)
else
	let
		res = max_NLopt()
		if res isa Missing
			still_missing()
		elseif !(res isa Tuple)
			keep_working(md"You should return a tuple")
		else
			correct()
		end
	end
end

# ╔═╡ 06aba85e-7cec-11eb-075f-23d500eda202
if !@isdefined(exp_u)
	not_definedf(:exp_u)
else
	let
		res = exp_u(0.5)
		if res isa Missing
			still_missing()
		elseif !(res isa Number)
			keep_working(md"You should return a number")
		else
			correct()
		end
	end
end

# ╔═╡ cac793ec-7cec-11eb-12a0-b7caf963d07f
if !@isdefined(opt_c)
	not_definedf(:opt_c)
else
	let
		a = 0.5
		res = opt_c(a)
		if res isa Missing
			still_missing()
		elseif !(res isa Number)
			keep_working(md"You should return a number")
		elseif abs(res - exp_u(a)) > 1e-4
			keep_working(md"your opt_c(0.5) and exp_u(a) should be approximately equal!")
		else
			correct()
		end
	end
end

# ╔═╡ 316f5b3e-7da6-11eb-1d30-5f7a350de422
if !@isdefined(max_JuMP)
	not_definedf(:max_JuMP)
else
	let
		res = max_JuMP()
		if res isa Missing
			still_missing()
		elseif !(res isa Dict)
			keep_working(md"You should return a Dict")
		elseif !issetequal(collect(keys(res)),["obj","c","omegas"])
			keep_working(md"""your Dict needs to have keys ["obj","c","omegas"]""")
		else
			correct()
		end
	end
end

# ╔═╡ d7915d7a-7b42-11eb-2ea7-4f0b7bd6a904


# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
Ipopt = "b6b21f68-93f8-5de0-b562-5493be1d77c9"
JuMP = "4076af6c-e467-56ae-b986-b466b2749572"
LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
NLopt = "76087f3c-5699-56af-9a33-bf431cd00edd"
Plots = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[compat]
DataFrames = "~1.2.2"
Ipopt = "~0.9.1"
JuMP = "~0.22.1"
NLopt = "~0.6.4"
Plots = "~1.24.3"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.10.2"
manifest_format = "2.0"
project_hash = "04bb2b471a3fcfbf8b7ab45bc4af95d47dc6e60a"

[[deps.ASL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "6252039f98492252f9e47c312c8ffda0e3b9e78d"
uuid = "ae81ac8f-d209-56e5-92de-9978fef736f9"
version = "0.1.3+0"

[[deps.Adapt]]
deps = ["LinearAlgebra", "Requires"]
git-tree-sha1 = "cc37d689f599e8df4f464b2fa3870ff7db7492ef"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "3.6.1"
weakdeps = ["StaticArrays"]

    [deps.Adapt.extensions]
    AdaptStaticArraysExt = "StaticArrays"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.1"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.BenchmarkTools]]
deps = ["JSON", "Logging", "Printf", "Profile", "Statistics", "UUIDs"]
git-tree-sha1 = "d9a9701b899b30332bbcb3e1679c41cce81fb0e8"
uuid = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
version = "1.3.2"

[[deps.BinaryProvider]]
deps = ["Libdl", "Logging", "SHA"]
git-tree-sha1 = "ecdec412a9abc8db54c0efc5548c64dfce072058"
uuid = "b99e7846-7c00-51b0-8f62-c81ae34c0232"
version = "0.5.10"

[[deps.Bzip2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "19a35467a82e236ff51bc17a3a44b69ef35185a2"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.8+0"

[[deps.Cairo_jll]]
deps = ["Artifacts", "Bzip2_jll", "CompilerSupportLibraries_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "JLLWrappers", "LZO_jll", "Libdl", "Pixman_jll", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "4b859a208b2397a7a623a03449e4636bdb17bcf2"
uuid = "83423d85-b0ee-5818-9007-b63ccbeb887a"
version = "1.16.1+1"

[[deps.Calculus]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "f641eb0a4f00c343bbc32346e1217b86f3ce9dad"
uuid = "49dc2e85-a5d0-5ad3-a950-438e2897f1b9"
version = "0.5.1"

[[deps.CodecBzip2]]
deps = ["Bzip2_jll", "Libdl", "TranscodingStreams"]
git-tree-sha1 = "2e62a725210ce3c3c2e1a3080190e7ca491f18d7"
uuid = "523fee87-0ab8-5b00-afb7-3ecf72e48cfd"
version = "0.7.2"

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "9c209fb7536406834aa938fb149964b985de6c83"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.1"

[[deps.ColorSchemes]]
deps = ["ColorTypes", "ColorVectorSpace", "Colors", "FixedPointNumbers", "Random", "SnoopPrecompile"]
git-tree-sha1 = "aa3edc8f8dea6cbfa176ee12f7c2fc82f0608ed3"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.20.0"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "eb7f0f8307f71fac7c606984ea5fb2817275d6e4"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.4"

[[deps.ColorVectorSpace]]
deps = ["ColorTypes", "FixedPointNumbers", "LinearAlgebra", "SpecialFunctions", "Statistics", "TensorCore"]
git-tree-sha1 = "600cc5508d66b78aae350f7accdb58763ac18589"
uuid = "c3611d14-8923-5661-9e6a-0046d554d3a4"
version = "0.9.10"

[[deps.Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "fc08e5930ee9a4e03f84bfb5211cb54e7769758a"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.12.10"

[[deps.CommonSubexpressions]]
deps = ["MacroTools", "Test"]
git-tree-sha1 = "7b8a93dba8af7e3b42fecabf646260105ac373f7"
uuid = "bbf7d656-a473-5ed7-a52c-81e309532950"
version = "0.3.0"

[[deps.Compat]]
deps = ["Base64", "Dates", "DelimitedFiles", "Distributed", "InteractiveUtils", "LibGit2", "Libdl", "LinearAlgebra", "Markdown", "Mmap", "Pkg", "Printf", "REPL", "Random", "SHA", "Serialization", "SharedArrays", "Sockets", "SparseArrays", "Statistics", "Test", "UUIDs", "Unicode"]
git-tree-sha1 = "6c0100a8cf4ed66f66e2039af7cde3357814bad2"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "3.46.2"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.1.0+0"

[[deps.Contour]]
deps = ["StaticArrays"]
git-tree-sha1 = "9f02045d934dc030edad45944ea80dbd1f0ebea7"
uuid = "d38c429a-6771-53c6-b99e-75d170b6e991"
version = "0.5.7"

[[deps.Crayons]]
git-tree-sha1 = "249fe38abf76d48563e2f4556bebd215aa317e15"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.1.1"

[[deps.DataAPI]]
git-tree-sha1 = "e8119c1a33d267e16108be441a287a6981ba1630"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.14.0"

[[deps.DataFrames]]
deps = ["Compat", "DataAPI", "Future", "InvertedIndices", "IteratorInterfaceExtensions", "LinearAlgebra", "Markdown", "Missings", "PooledArrays", "PrettyTables", "Printf", "REPL", "Reexport", "SortingAlgorithms", "Statistics", "TableTraits", "Tables", "Unicode"]
git-tree-sha1 = "d785f42445b63fc86caa08bb9a9351008be9b765"
uuid = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
version = "1.2.2"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "d1fff3a548102f48987a52a2e0d114fa97d730f0"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.13"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.DelimitedFiles]]
deps = ["Mmap"]
git-tree-sha1 = "9e2f36d3c96a820c678f2f1f1782582fcf685bae"
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"
version = "1.9.1"

[[deps.DiffResults]]
deps = ["StaticArraysCore"]
git-tree-sha1 = "782dd5f4561f5d267313f23853baaaa4c52ea621"
uuid = "163ba53b-c6d8-5494-b064-1a9d43ac40c5"
version = "1.1.0"

[[deps.DiffRules]]
deps = ["IrrationalConstants", "LogExpFunctions", "NaNMath", "Random", "SpecialFunctions"]
git-tree-sha1 = "a4ad7ef19d2cdc2eff57abbbe68032b1cd0bd8f8"
uuid = "b552c78f-8df3-52c6-915a-8e097449b14b"
version = "1.13.0"

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[deps.DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "2fb1e02f2b635d0845df5d7c167fec4dd739b00d"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.9.3"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.EarCut_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e3290f2d49e661fbd94046d7e3726ffcb2d41053"
uuid = "5ae413db-bbd1-5e63-b57d-d24a61df00f5"
version = "2.2.4+0"

[[deps.EpollShim_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "8e9441ee83492030ace98f9789a654a6d0b1f643"
uuid = "2702e6a9-849d-5ed8-8c21-79e8b8f9ee43"
version = "0.0.20230411+0"

[[deps.Expat_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "bad72f730e9e91c08d9427d5e8db95478a3c323d"
uuid = "2e619515-83b5-522b-bb60-26c02a35a201"
version = "2.4.8+0"

[[deps.Extents]]
git-tree-sha1 = "5e1e4c53fa39afe63a7d356e30452249365fba99"
uuid = "411431e0-e8b7-467b-b5e0-f676ba4f2910"
version = "0.1.1"

[[deps.FFMPEG]]
deps = ["FFMPEG_jll"]
git-tree-sha1 = "b57e3acbe22f8484b4b5ff66a7499717fe1a9cc8"
uuid = "c87230d0-a227-11e9-1b43-d7ebe4e7570a"
version = "0.4.1"

[[deps.FFMPEG_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "JLLWrappers", "LAME_jll", "Libdl", "Ogg_jll", "OpenSSL_jll", "Opus_jll", "PCRE2_jll", "Pkg", "Zlib_jll", "libaom_jll", "libass_jll", "libfdk_aac_jll", "libvorbis_jll", "x264_jll", "x265_jll"]
git-tree-sha1 = "74faea50c1d007c85837327f6775bea60b5492dd"
uuid = "b22a6f82-2f65-5046-a5b2-351ab43fb4e5"
version = "4.4.2+2"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[deps.Fontconfig_jll]]
deps = ["Artifacts", "Bzip2_jll", "Expat_jll", "FreeType2_jll", "JLLWrappers", "Libdl", "Libuuid_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "21efd19106a55620a188615da6d3d06cd7f6ee03"
uuid = "a3f928ae-7b40-5064-980b-68af3947d34b"
version = "2.13.93+0"

[[deps.Formatting]]
deps = ["Printf"]
git-tree-sha1 = "8339d61043228fdd3eb658d86c926cb282ae72a8"
uuid = "59287772-0a20-5a39-b81b-1366585eb4c0"
version = "0.4.2"

[[deps.ForwardDiff]]
deps = ["CommonSubexpressions", "DiffResults", "DiffRules", "LinearAlgebra", "LogExpFunctions", "NaNMath", "Preferences", "Printf", "Random", "SpecialFunctions"]
git-tree-sha1 = "00e252f4d706b3d55a8863432e742bf5717b498d"
uuid = "f6369f11-7733-5829-9624-2563aa707210"
version = "0.10.35"
weakdeps = ["StaticArrays"]

    [deps.ForwardDiff.extensions]
    ForwardDiffStaticArraysExt = "StaticArrays"

[[deps.FreeType2_jll]]
deps = ["Artifacts", "Bzip2_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "87eb71354d8ec1a96d4a7636bd57a7347dde3ef9"
uuid = "d7e528f0-a631-5988-bf34-fe36492bcfd7"
version = "2.10.4+0"

[[deps.FriBidi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "aa31987c2ba8704e23c6c8ba8a4f769d5d7e4f91"
uuid = "559328eb-81f9-559d-9380-de523a88c83c"
version = "1.0.10+0"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[deps.GLFW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libglvnd_jll", "Pkg", "Xorg_libXcursor_jll", "Xorg_libXi_jll", "Xorg_libXinerama_jll", "Xorg_libXrandr_jll"]
git-tree-sha1 = "d972031d28c8c8d9d7b41a536ad7bb0c2579caca"
uuid = "0656b61e-2033-5cc2-a64a-77c0f6c09b89"
version = "3.3.8+0"

[[deps.GPUArraysCore]]
deps = ["Adapt"]
git-tree-sha1 = "1cd7f0af1aa58abc02ea1d872953a97359cb87fa"
uuid = "46192b85-c4d5-4398-a991-12ede77f4527"
version = "0.1.4"

[[deps.GR]]
deps = ["Base64", "DelimitedFiles", "GR_jll", "HTTP", "JSON", "Libdl", "LinearAlgebra", "Pkg", "Printf", "Random", "Serialization", "Sockets", "Test", "UUIDs"]
git-tree-sha1 = "30f2b340c2fff8410d89bfcdc9c0a6dd661ac5f7"
uuid = "28b8d3ca-fb5f-59d9-8090-bfdbd6d07a71"
version = "0.62.1"

[[deps.GR_jll]]
deps = ["Artifacts", "Bzip2_jll", "Cairo_jll", "FFMPEG_jll", "Fontconfig_jll", "GLFW_jll", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libtiff_jll", "Pixman_jll", "Pkg", "Qt5Base_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "bc9f7725571ddb4ab2c4bc74fa397c1c5ad08943"
uuid = "d2c73de3-f751-5644-a686-071e5b155ba9"
version = "0.69.1+0"

[[deps.GeoInterface]]
deps = ["Extents"]
git-tree-sha1 = "e07a1b98ed72e3cdd02c6ceaab94b8a606faca40"
uuid = "cf35fbd7-0cd7-5166-be24-54bfbe79505f"
version = "1.2.1"

[[deps.GeometryBasics]]
deps = ["EarCut_jll", "GeoInterface", "IterTools", "LinearAlgebra", "StaticArrays", "StructArrays", "Tables"]
git-tree-sha1 = "303202358e38d2b01ba46844b92e48a3c238fd9e"
uuid = "5c1252a2-5f33-56bf-86c9-59e7332b4326"
version = "0.4.6"

[[deps.Gettext_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "9b02998aba7bf074d14de89f9d37ca24a1a0b046"
uuid = "78b55507-aeef-58d4-861c-77aaff3498b1"
version = "0.21.0+0"

[[deps.Glib_jll]]
deps = ["Artifacts", "Gettext_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Libiconv_jll", "Libmount_jll", "PCRE2_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "d3b3624125c1474292d0d8ed0f65554ac37ddb23"
uuid = "7746bdde-850d-59dc-9ae8-88ece973131d"
version = "2.74.0+2"

[[deps.Graphite2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "344bf40dcab1073aca04aa0df4fb092f920e4011"
uuid = "3b182d85-2403-5c21-9c21-1e1f0cc25472"
version = "1.3.14+0"

[[deps.Grisu]]
git-tree-sha1 = "53bb909d1151e57e2484c3d1b53e19552b887fb2"
uuid = "42e2da0e-8278-4e71-bc24-59509adca0fe"
version = "1.0.2"

[[deps.HTTP]]
deps = ["Base64", "Dates", "IniFile", "Logging", "MbedTLS", "NetworkOptions", "Sockets", "URIs"]
git-tree-sha1 = "0fa77022fe4b511826b39c894c90daf5fce3334a"
uuid = "cd3eb016-35fb-5094-929b-558a96fad6f3"
version = "0.9.17"

[[deps.HarfBuzz_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "Graphite2_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg"]
git-tree-sha1 = "129acf094d168394e80ee1dc4bc06ec835e510a3"
uuid = "2e76f6c2-a576-52d4-95c1-20adfe4de566"
version = "2.8.1+1"

[[deps.IniFile]]
git-tree-sha1 = "f550e6e32074c939295eb5ea6de31849ac2c9625"
uuid = "83e8ac13-25f8-5344-8a64-a9f2b223428f"
version = "0.5.1"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.InvertedIndices]]
git-tree-sha1 = "0dc7b50b8d436461be01300fd8cd45aa0274b038"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.3.0"

[[deps.Ipopt]]
deps = ["BinaryProvider", "Ipopt_jll", "Libdl", "MathOptInterface"]
git-tree-sha1 = "68ba332ff458f3c1f40182016ff9b1bda276fa9e"
uuid = "b6b21f68-93f8-5de0-b562-5493be1d77c9"
version = "0.9.1"

[[deps.Ipopt_jll]]
deps = ["ASL_jll", "Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "MUMPS_seq_jll", "OpenBLAS32_jll", "Pkg"]
git-tree-sha1 = "e3e202237d93f18856b6ff1016166b0f172a49a8"
uuid = "9cc047cb-c261-5740-88fc-0cf96f7bdcc7"
version = "300.1400.400+0"

[[deps.IrrationalConstants]]
git-tree-sha1 = "630b497eafcc20001bba38a4651b327dcfc491d2"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.2.2"

[[deps.IterTools]]
git-tree-sha1 = "fa6287a4469f5e048d763df38279ee729fbd44e5"
uuid = "c8e1da08-722c-5040-9ed9-7db0dc04731e"
version = "1.4.0"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.JLLWrappers]]
deps = ["Preferences"]
git-tree-sha1 = "abc9885a7ca2052a736a600f7fa66209f96506e1"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.4.1"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "3c837543ddb02250ef42f4738347454f95079d4e"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.3"

[[deps.JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "6f2675ef130a300a112286de91973805fcc5ffbc"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "2.1.91+0"

[[deps.JuMP]]
deps = ["Calculus", "DataStructures", "ForwardDiff", "JSON", "LinearAlgebra", "MathOptInterface", "MutableArithmetics", "NaNMath", "OrderedCollections", "Printf", "Random", "SparseArrays", "SpecialFunctions", "Statistics"]
git-tree-sha1 = "fe0f87cc077fc6a23c21e469318993caf2947d10"
uuid = "4076af6c-e467-56ae-b986-b466b2749572"
version = "0.22.3"

[[deps.LAME_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "f6250b16881adf048549549fba48b1161acdac8c"
uuid = "c1c5ebd0-6772-5130-a774-d5fcae4a789d"
version = "3.100.1+0"

[[deps.LERC_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "bf36f528eec6634efc60d7ec062008f171071434"
uuid = "88015f11-f218-50d7-93a8-a6af411a945d"
version = "3.0.0+1"

[[deps.LZO_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e5b909bcf985c5e2605737d2ce278ed791b89be6"
uuid = "dd4b983a-f0e5-5f8d-a1b7-129d4a5fb1ac"
version = "2.10.1+0"

[[deps.LaTeXStrings]]
git-tree-sha1 = "f2355693d6778a178ade15952b7ac47a4ff97996"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.3.0"

[[deps.Latexify]]
deps = ["Formatting", "InteractiveUtils", "LaTeXStrings", "MacroTools", "Markdown", "OrderedCollections", "Printf", "Requires"]
git-tree-sha1 = "2422f47b34d4b127720a18f86fa7b1aa2e141f29"
uuid = "23fbe1c1-3f47-55db-b15f-69d7ec21a316"
version = "0.15.18"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.4"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "8.4.0+0"

[[deps.LibGit2]]
deps = ["Base64", "LibGit2_jll", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibGit2_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll"]
uuid = "e37daf67-58a4-590a-8e99-b0245dd2ffc5"
version = "1.6.4+0"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.11.0+1"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.Libffi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "0b4a5d71f3e5200a7dff793393e09dfc2d874290"
uuid = "e9f186c6-92d2-5b65-8a66-fee21dc1b490"
version = "3.2.2+1"

[[deps.Libgcrypt_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgpg_error_jll", "Pkg"]
git-tree-sha1 = "64613c82a59c120435c067c2b809fc61cf5166ae"
uuid = "d4300ac3-e22c-5743-9152-c294e39db1e4"
version = "1.8.7+0"

[[deps.Libglvnd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll", "Xorg_libXext_jll"]
git-tree-sha1 = "6f73d1dd803986947b2c750138528a999a6c7733"
uuid = "7e76a0d4-f3c7-5321-8279-8d96eeed0f29"
version = "1.6.0+0"

[[deps.Libgpg_error_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c333716e46366857753e273ce6a69ee0945a6db9"
uuid = "7add5ba3-2f88-524e-9cd5-f83b8a55f7b8"
version = "1.42.0+0"

[[deps.Libiconv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c7cb1f5d892775ba13767a87c7ada0b980ea0a71"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.16.1+2"

[[deps.Libmount_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "9c30530bf0effd46e15e0fdcf2b8636e78cbbd73"
uuid = "4b2f31a3-9ecc-558c-b454-b3730dcb73e9"
version = "2.35.0+0"

[[deps.Libtiff_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "LERC_jll", "Libdl", "Pkg", "Zlib_jll", "Zstd_jll"]
git-tree-sha1 = "3eb79b0ca5764d4799c06699573fd8f533259713"
uuid = "89763e89-9b03-5906-acba-b20f662cd828"
version = "4.4.0+0"

[[deps.Libuuid_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "7f3efec06033682db852f8b3bc3c1d2b0a0ab066"
uuid = "38a345b3-de98-5d2b-a5d3-14cd9215e700"
version = "2.36.0+0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.LogExpFunctions]]
deps = ["DocStringExtensions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "0a1b7c2863e44523180fdb3146534e265a91870b"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.23"

    [deps.LogExpFunctions.extensions]
    LogExpFunctionsChainRulesCoreExt = "ChainRulesCore"
    LogExpFunctionsChangesOfVariablesExt = "ChangesOfVariables"
    LogExpFunctionsInverseFunctionsExt = "InverseFunctions"

    [deps.LogExpFunctions.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    ChangesOfVariables = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
    InverseFunctions = "3587e190-3f89-42d0-90ee-14403ec27112"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.METIS_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "1fd0a97409e418b78c53fac671cf4622efdf0f21"
uuid = "d00139f3-1899-568f-a2f0-47f597d42d70"
version = "5.1.2+0"

[[deps.MUMPS_seq_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "METIS_jll", "OpenBLAS32_jll", "Pkg"]
git-tree-sha1 = "29de2841fa5aefe615dea179fcde48bb87b58f57"
uuid = "d7ed1dd3-d0ae-5e8e-bfb4-87a502085b8d"
version = "5.4.1+0"

[[deps.MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "42324d08725e200c23d4dfb549e0d5d89dede2d2"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.10"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MathOptInterface]]
deps = ["BenchmarkTools", "CodecBzip2", "CodecZlib", "JSON", "LinearAlgebra", "MutableArithmetics", "OrderedCollections", "Printf", "SparseArrays", "Test", "Unicode"]
git-tree-sha1 = "e8c9653877adcf8f3e7382985e535bb37b083598"
uuid = "b8f27783-ece8-5eb3-8dc8-9495eed66fee"
version = "0.10.9"

[[deps.MathProgBase]]
deps = ["LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "9abbe463a1e9fc507f12a69e7f29346c2cdc472c"
uuid = "fdba3010-5040-5b88-9595-932c9decdf73"
version = "0.7.8"

[[deps.MbedTLS]]
deps = ["Dates", "MbedTLS_jll", "MozillaCACerts_jll", "Random", "Sockets"]
git-tree-sha1 = "03a9b9718f5682ecb107ac9f7308991db4ce395b"
uuid = "739be429-bea8-5141-9913-cc70e7f3736d"
version = "1.1.7"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.2+1"

[[deps.Measures]]
git-tree-sha1 = "c13304c81eec1ed3af7fc20e75fb6b26092a1102"
uuid = "442fdcdd-2543-5da2-b0f3-8c86c306513e"
version = "0.3.2"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "f66bdc5de519e8f8ae43bdc598782d35a25b1272"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.1.0"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2023.1.10"

[[deps.MutableArithmetics]]
deps = ["LinearAlgebra", "SparseArrays", "Test"]
git-tree-sha1 = "842b5ccd156e432f369b204bb704fd4020e383ac"
uuid = "d8a4904e-b15c-11e9-3269-09a3773c0cb0"
version = "0.3.3"

[[deps.NLopt]]
deps = ["MathOptInterface", "MathProgBase", "NLopt_jll"]
git-tree-sha1 = "5a7e32c569200a8a03c3d55d286254b0321cd262"
uuid = "76087f3c-5699-56af-9a33-bf431cd00edd"
version = "0.6.5"

[[deps.NLopt_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "9b1f15a08f9d00cdb2761dcfa6f453f5d0d6f973"
uuid = "079eb43e-fd8e-5478-9966-2cf3e3edb778"
version = "2.7.1+0"

[[deps.NaNMath]]
git-tree-sha1 = "b086b7ea07f8e38cf122f5016af580881ac914fe"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "0.3.7"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.Ogg_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "887579a3eb005446d514ab7aeac5d1d027658b8f"
uuid = "e7412a2a-1a6e-54c0-be00-318e2571c051"
version = "1.3.5+1"

[[deps.OpenBLAS32_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "2fb9ee2dc14d555a6df2a714b86b7125178344c2"
uuid = "656ef2d0-ae68-5445-9ca0-591084a874a2"
version = "0.3.21+0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.23+4"

[[deps.OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"
version = "0.8.1+2"

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "9ff31d101d987eb9d66bd8b176ac7c277beccd09"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "1.1.20+0"

[[deps.OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "13652491f6856acfd2db29360e1bbcd4565d04f1"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.5+0"

[[deps.Opus_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "51a08fb14ec28da2ec7a927c4337e4332c2a4720"
uuid = "91d4177d-7536-5919-b921-800302f37372"
version = "1.3.2+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "85f8e6578bf1f9ee0d11e7bb1b1456435479d47c"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.4.1"

[[deps.PCRE2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "efcefdf7-47ab-520b-bdef-62a2eaa19f15"
version = "10.42.0+1"

[[deps.Parsers]]
deps = ["Dates", "SnoopPrecompile"]
git-tree-sha1 = "478ac6c952fddd4399e71d4779797c538d0ff2bf"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.5.8"

[[deps.Pixman_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b4f5d02549a10e20780a24fce72bea96b6329e29"
uuid = "30392449-352a-5448-841d-b1acce4e97dc"
version = "0.40.1+0"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.10.0"

[[deps.PlotThemes]]
deps = ["PlotUtils", "Requires", "Statistics"]
git-tree-sha1 = "a3a964ce9dc7898193536002a6dd892b1b5a6f1d"
uuid = "ccf2f8ad-2431-5c83-bf29-c5338b663b6a"
version = "2.0.1"

[[deps.PlotUtils]]
deps = ["ColorSchemes", "Colors", "Dates", "Printf", "Random", "Reexport", "SnoopPrecompile", "Statistics"]
git-tree-sha1 = "c95373e73290cf50a8a22c3375e4625ded5c5280"
uuid = "995b91a9-d308-5afd-9ec6-746e21dbc043"
version = "1.3.4"

[[deps.Plots]]
deps = ["Base64", "Contour", "Dates", "Downloads", "FFMPEG", "FixedPointNumbers", "GR", "GeometryBasics", "JSON", "Latexify", "LinearAlgebra", "Measures", "NaNMath", "PlotThemes", "PlotUtils", "Printf", "REPL", "Random", "RecipesBase", "RecipesPipeline", "Reexport", "Requires", "Scratch", "Showoff", "SparseArrays", "Statistics", "StatsBase", "UUIDs", "UnicodeFun"]
git-tree-sha1 = "d73736030a094e8d24fdf3629ae980217bf1d59d"
uuid = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
version = "1.24.3"

[[deps.PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "a6062fe4063cdafe78f4a0a81cfffb89721b30e7"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.4.2"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "47e5f437cc0e7ef2ce8406ce1e7e24d44915f88d"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.3.0"

[[deps.PrettyTables]]
deps = ["Crayons", "Formatting", "Markdown", "Reexport", "Tables"]
git-tree-sha1 = "dfb54c4e414caa595a1f2ed759b160f5a3ddcba5"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "1.3.1"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.Profile]]
deps = ["Printf"]
uuid = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"

[[deps.Qt5Base_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Fontconfig_jll", "Glib_jll", "JLLWrappers", "Libdl", "Libglvnd_jll", "OpenSSL_jll", "Pkg", "Xorg_libXext_jll", "Xorg_libxcb_jll", "Xorg_xcb_util_image_jll", "Xorg_xcb_util_keysyms_jll", "Xorg_xcb_util_renderutil_jll", "Xorg_xcb_util_wm_jll", "Zlib_jll", "xkbcommon_jll"]
git-tree-sha1 = "0c03844e2231e12fda4d0086fd7cbe4098ee8dc5"
uuid = "ea2cea3b-5b76-57ae-a6ef-0a8af62496e1"
version = "5.15.3+2"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.RecipesBase]]
deps = ["SnoopPrecompile"]
git-tree-sha1 = "261dddd3b862bd2c940cf6ca4d1c8fe593e457c8"
uuid = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
version = "1.3.3"

[[deps.RecipesPipeline]]
deps = ["Dates", "NaNMath", "PlotUtils", "RecipesBase"]
git-tree-sha1 = "7ad0dfa8d03b7bcf8c597f59f5292801730c55b8"
uuid = "01d81517-befc-4cb6-b9ec-a95719d0359c"
version = "0.4.1"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "838a3a4188e2ded87a4f9f184b4b0d78a1e91cb7"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.0"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.Scratch]]
deps = ["Dates"]
git-tree-sha1 = "30449ee12237627992a99d5e30ae63e4d78cd24a"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.2.0"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"

[[deps.Showoff]]
deps = ["Dates", "Grisu"]
git-tree-sha1 = "91eddf657aca81df9ae6ceb20b959ae5653ad1de"
uuid = "992d4aef-0814-514b-bc4d-f2e9a6c4116f"
version = "1.0.3"

[[deps.SnoopPrecompile]]
deps = ["Preferences"]
git-tree-sha1 = "e760a70afdcd461cf01a575947738d359234665c"
uuid = "66db9d55-30c0-4569-8b51-7e840670fc0c"
version = "1.0.3"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "a4ada03f999bd01b3a25dcaa30b2d929fe537e00"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.1.0"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
version = "1.10.0"

[[deps.SpecialFunctions]]
deps = ["IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "ef28127915f4229c971eb43f3fc075dd3fe91880"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "2.2.0"

    [deps.SpecialFunctions.extensions]
    SpecialFunctionsChainRulesCoreExt = "ChainRulesCore"

    [deps.SpecialFunctions.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"

[[deps.StaticArrays]]
deps = ["LinearAlgebra", "Random", "StaticArraysCore", "Statistics"]
git-tree-sha1 = "b8d897fe7fa688e93aef573711cb207c08c9e11e"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.5.19"

[[deps.StaticArraysCore]]
git-tree-sha1 = "6b7ba252635a5eff6a0b0664a41ee140a1c9e72a"
uuid = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
version = "1.4.0"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.10.0"

[[deps.StatsAPI]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "f9af7f195fb13589dd2e2d57fdb401717d2eb1f6"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.5.0"

[[deps.StatsBase]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "d1bf48bfcc554a3761a133fe3a9bb01488e06916"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.33.21"

[[deps.StructArrays]]
deps = ["Adapt", "DataAPI", "GPUArraysCore", "StaticArraysCore", "Tables"]
git-tree-sha1 = "521a0e828e98bb69042fec1809c1b5a680eb7389"
uuid = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
version = "0.6.15"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "7.2.1+1"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[deps.Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "OrderedCollections", "TableTraits", "Test"]
git-tree-sha1 = "1544b926975372da01227b382066ab70e574a3ec"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.10.1"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.TensorCore]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1feb45f88d133a655e001435632f019a9a1bcdb6"
uuid = "62fd8b95-f654-4bbd-a8a5-9c27f68ccd50"
version = "0.1.1"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.TranscodingStreams]]
deps = ["Random", "Test"]
git-tree-sha1 = "94f38103c984f89cf77c402f2a68dbd870f8165f"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.9.11"

[[deps.URIs]]
git-tree-sha1 = "074f993b0ca030848b897beff716d93aca60f06a"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.4.2"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.UnicodeFun]]
deps = ["REPL"]
git-tree-sha1 = "53915e50200959667e78a92a418594b428dffddf"
uuid = "1cfade01-22cf-5700-b092-accc4b62d6e1"
version = "0.4.1"

[[deps.Wayland_jll]]
deps = ["Artifacts", "EpollShim_jll", "Expat_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "ed8d92d9774b077c53e1da50fd81a36af3744c1c"
uuid = "a2964d1f-97da-50d4-b82a-358c7fce9d89"
version = "1.21.0+0"

[[deps.Wayland_protocols_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4528479aa01ee1b3b4cd0e6faef0e04cf16466da"
uuid = "2381bf8a-dfd0-557d-9999-79630e7b1b91"
version = "1.25.0+0"

[[deps.XML2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "93c41695bc1c08c46c5899f4fe06d6ead504bb73"
uuid = "02c8fc9c-b97f-50b9-bbe4-9be30ff0a78a"
version = "2.10.3+0"

[[deps.XSLT_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgcrypt_jll", "Libgpg_error_jll", "Libiconv_jll", "Pkg", "XML2_jll", "Zlib_jll"]
git-tree-sha1 = "91844873c4085240b95e795f692c4cec4d805f8a"
uuid = "aed1982a-8fda-507f-9586-7b0439959a61"
version = "1.1.34+0"

[[deps.Xorg_libX11_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxcb_jll", "Xorg_xtrans_jll"]
git-tree-sha1 = "5be649d550f3f4b95308bf0183b82e2582876527"
uuid = "4f6342f7-b3d2-589e-9d20-edeb45f2b2bc"
version = "1.6.9+4"

[[deps.Xorg_libXau_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4e490d5c960c314f33885790ed410ff3a94ce67e"
uuid = "0c0b7dd1-d40b-584c-a123-a41640f87eec"
version = "1.0.9+4"

[[deps.Xorg_libXcursor_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXfixes_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "12e0eb3bc634fa2080c1c37fccf56f7c22989afd"
uuid = "935fb764-8cf2-53bf-bb30-45bb1f8bf724"
version = "1.2.0+4"

[[deps.Xorg_libXdmcp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4fe47bd2247248125c428978740e18a681372dd4"
uuid = "a3789734-cfe1-5b06-b2d0-1dd0d9d62d05"
version = "1.1.3+4"

[[deps.Xorg_libXext_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "b7c0aa8c376b31e4852b360222848637f481f8c3"
uuid = "1082639a-0dae-5f34-9b06-72781eeb8cb3"
version = "1.3.4+4"

[[deps.Xorg_libXfixes_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "0e0dc7431e7a0587559f9294aeec269471c991a4"
uuid = "d091e8ba-531a-589c-9de9-94069b037ed8"
version = "5.0.3+4"

[[deps.Xorg_libXi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll", "Xorg_libXfixes_jll"]
git-tree-sha1 = "89b52bc2160aadc84d707093930ef0bffa641246"
uuid = "a51aa0fd-4e3c-5386-b890-e753decda492"
version = "1.7.10+4"

[[deps.Xorg_libXinerama_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll"]
git-tree-sha1 = "26be8b1c342929259317d8b9f7b53bf2bb73b123"
uuid = "d1454406-59df-5ea1-beac-c340f2130bc3"
version = "1.1.4+4"

[[deps.Xorg_libXrandr_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "34cea83cb726fb58f325887bf0612c6b3fb17631"
uuid = "ec84b674-ba8e-5d96-8ba1-2a689ba10484"
version = "1.5.2+4"

[[deps.Xorg_libXrender_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "19560f30fd49f4d4efbe7002a1037f8c43d43b96"
uuid = "ea2f1a96-1ddc-540d-b46f-429655e07cfa"
version = "0.9.10+4"

[[deps.Xorg_libpthread_stubs_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "6783737e45d3c59a4a4c4091f5f88cdcf0908cbb"
uuid = "14d82f49-176c-5ed1-bb49-ad3f5cbd8c74"
version = "0.1.0+3"

[[deps.Xorg_libxcb_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "XSLT_jll", "Xorg_libXau_jll", "Xorg_libXdmcp_jll", "Xorg_libpthread_stubs_jll"]
git-tree-sha1 = "daf17f441228e7a3833846cd048892861cff16d6"
uuid = "c7cfdc94-dc32-55de-ac96-5a1b8d977c5b"
version = "1.13.0+3"

[[deps.Xorg_libxkbfile_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "926af861744212db0eb001d9e40b5d16292080b2"
uuid = "cc61e674-0454-545c-8b26-ed2c68acab7a"
version = "1.1.0+4"

[[deps.Xorg_xcb_util_image_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "0fab0a40349ba1cba2c1da699243396ff8e94b97"
uuid = "12413925-8142-5f55-bb0e-6d7ca50bb09b"
version = "0.4.0+1"

[[deps.Xorg_xcb_util_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxcb_jll"]
git-tree-sha1 = "e7fd7b2881fa2eaa72717420894d3938177862d1"
uuid = "2def613f-5ad1-5310-b15b-b15d46f528f5"
version = "0.4.0+1"

[[deps.Xorg_xcb_util_keysyms_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "d1151e2c45a544f32441a567d1690e701ec89b00"
uuid = "975044d2-76e6-5fbe-bf08-97ce7c6574c7"
version = "0.4.0+1"

[[deps.Xorg_xcb_util_renderutil_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "dfd7a8f38d4613b6a575253b3174dd991ca6183e"
uuid = "0d47668e-0667-5a69-a72c-f761630bfb7e"
version = "0.3.9+1"

[[deps.Xorg_xcb_util_wm_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "e78d10aab01a4a154142c5006ed44fd9e8e31b67"
uuid = "c22f9ab0-d5fe-5066-847c-f4bb1cd4e361"
version = "0.4.1+1"

[[deps.Xorg_xkbcomp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxkbfile_jll"]
git-tree-sha1 = "4bcbf660f6c2e714f87e960a171b119d06ee163b"
uuid = "35661453-b289-5fab-8a00-3d9160c6a3a4"
version = "1.4.2+4"

[[deps.Xorg_xkeyboard_config_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xkbcomp_jll"]
git-tree-sha1 = "5c8424f8a67c3f2209646d4425f3d415fee5931d"
uuid = "33bec58e-1273-512f-9401-5d533626f822"
version = "2.27.0+4"

[[deps.Xorg_xtrans_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "79c31e7844f6ecf779705fbc12146eb190b7d845"
uuid = "c5fb5394-a638-5e4d-96e5-b29de1b5cf10"
version = "1.4.0+3"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.13+1"

[[deps.Zstd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "c6edfe154ad7b313c01aceca188c05c835c67360"
uuid = "3161d3a3-bdf6-5164-811a-617609db77b4"
version = "1.5.4+0"

[[deps.libaom_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "3a2ea60308f0996d26f1e5354e10c24e9ef905d4"
uuid = "a4ae2306-e953-59d6-aa16-d00cac43593b"
version = "3.4.0+0"

[[deps.libass_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "5982a94fcba20f02f42ace44b9894ee2b140fe47"
uuid = "0ac62f75-1d6f-5e53-bd7c-93b484bb37c0"
version = "0.15.1+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.8.0+1"

[[deps.libfdk_aac_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "daacc84a041563f965be61859a36e17c4e4fcd55"
uuid = "f638f0a6-7fb0-5443-88ba-1cc74229b280"
version = "2.0.2+0"

[[deps.libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "94d180a6d2b5e55e447e2d27a29ed04fe79eb30c"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.38+0"

[[deps.libvorbis_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Ogg_jll", "Pkg"]
git-tree-sha1 = "b910cb81ef3fe6e78bf6acee440bda86fd6ae00c"
uuid = "f27f6e37-5d2b-51aa-960f-b287f2bc3b7a"
version = "1.3.7+1"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.52.0+1"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+2"

[[deps.x264_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4fea590b89e6ec504593146bf8b988b2c00922b2"
uuid = "1270edf5-f2f9-52d2-97e9-ab00b5d0237a"
version = "2021.5.5+0"

[[deps.x265_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "ee567a171cce03570d77ad3a43e90218e38937a9"
uuid = "dfaa095f-4041-5dcd-9319-2fabd8486b76"
version = "3.5.0+0"

[[deps.xkbcommon_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Wayland_jll", "Wayland_protocols_jll", "Xorg_libxcb_jll", "Xorg_xkeyboard_config_jll"]
git-tree-sha1 = "9ebfc140cc56e8c2156a15ceac2f0302e327ac0a"
uuid = "d8fb68d0-12a3-5cfd-a85a-d49703b185fd"
version = "1.4.1+0"
"""

# ╔═╡ Cell order:
# ╠═c69606ac-7b41-11eb-075f-27802f4d671e
# ╠═313a1e80-7b42-11eb-2b4c-cd7fe27b5483
# ╟─4d3447d2-7b42-11eb-1ce3-095b89785f6c
# ╠═06219b52-7b43-11eb-3ca9-c334f6d53908
# ╟─1532e6bc-7b43-11eb-3f27-59134ea6acc0
# ╟─f07efffc-7cd9-11eb-15aa-338b74552e6a
# ╠═03302a44-7cdb-11eb-0e34-73d2add94f8e
# ╟─2757d17a-7cda-11eb-3694-65c409660196
# ╟─d44226c2-7cda-11eb-1e95-d5c362a2a27c
# ╠═12a088f2-7cdb-11eb-01a6-21baf4b9ba02
# ╟─20316894-7cdb-11eb-2fec-f3f6876126ba
# ╟─632f1fea-7ce5-11eb-17ab-b5d2e8fa6995
# ╟─39f70dac-7b45-11eb-16d7-316a34077ace
# ╠═5124ed8a-7b45-11eb-0984-a944bd9302e0
# ╟─6183c9a8-7b45-11eb-0bd5-1302c23d6570
# ╠═587f244c-7b45-11eb-0238-070d76122af1
# ╟─5bef3e96-7b45-11eb-257a-09f7dbe66aaa
# ╟─a6f5e970-7ce5-11eb-179c-39d4f242c202
# ╟─c78a0e3d-fe92-4fe9-8c2b-da51c9651648
# ╟─f149f7b0-7ce6-11eb-207b-d3830fbf83ef
# ╟─d5555454-7da6-11eb-052e-7313220e3edb
# ╠═f22090dc-7da6-11eb-29dc-51aac7458cb2
# ╟─1910d264-7da8-11eb-1434-fb54dbeda64c
# ╟─fca315d4-d092-4eed-9d5b-62ad815cfdee
# ╟─13b50308-7b46-11eb-034c-c3e2b017e5e9
# ╟─c1a8d1ec-7b99-11eb-02bb-6917b65f33a7
# ╟─b1e51722-7b99-11eb-33ec-9dc089e8b7fe
# ╠═32f9d464-7b46-11eb-274c-0713593fe800
# ╠═3af65458-7b46-11eb-2d0c-e5a480ffe003
# ╟─389f51a0-7cea-11eb-19a3-438cb29fc2e0
# ╠═742bf3ec-a9bb-44ac-a3be-6e5c624222c4
# ╟─241521be-7ceb-11eb-0553-2de70f4c57e9
# ╟─74ada204-7ceb-11eb-0f48-ddc9c1a5fec8
# ╠═504b0b2d-f7ce-4a80-b148-ad4c438f8139
# ╟─e5233fa0-7b9a-11eb-39cc-c70c0addca97
# ╠═ef08e970-7b9a-11eb-203d-41095002a3b7
# ╟─aa8e4912-7ceb-11eb-0705-2bf588d303fe
# ╠═2de86fba-7b9b-11eb-379d-0b0f85d9c9a3
# ╟─06aba85e-7cec-11eb-075f-23d500eda202
# ╟─f910cfce-7b9b-11eb-3162-9be77eb705ee
# ╠═8913fa58-7cec-11eb-1bfa-cf84ef627bd2
# ╟─cac793ec-7cec-11eb-12a0-b7caf963d07f
# ╟─84b43576-7ced-11eb-37c3-5f6b595f0730
# ╟─0a5c81f2-7b4c-11eb-2a96-7163671eed67
# ╟─f078be5a-7b4c-11eb-3f03-138505242d43
# ╟─316f5b3e-7da6-11eb-1d30-5f7a350de422
# ╠═e7b74f8e-ffcc-4c8d-8d67-62d4fa05be79
# ╟─0e41d664-7da6-11eb-3598-bd1ce2944ebd
# ╟─19d9f3f8-7da6-11eb-169c-9765c55cfac6
# ╟─7cc76266-7da6-11eb-3c61-6d4b7206c46c
# ╠═6bd9598d-817f-45eb-b2b7-d8629e78b178
# ╠═83812582-d6a1-448f-9630-8560c6833843
# ╠═ecf9521c-97f7-4645-a111-da5a00dc4586
# ╠═3f374470-d174-4bd1-84e5-aa4608fd91c0
# ╠═9b9ec0d6-e54f-4838-89c6-a1807ba59349
# ╟─a1e0ec36-7cee-11eb-3e4c-69ad1c5d018f
# ╟─061b765e-7b4c-11eb-337a-61f8783875bb
# ╟─13d41f9e-7cf0-11eb-1e01-f1ddcbe01b8a
# ╠═88317198-7b42-11eb-1364-470e8ef725d9
# ╠═babf2e98-7b42-11eb-09ef-1bfcc53d3d16
# ╠═bf3b2792-7b42-11eb-0e28-295cbed65a13
# ╠═c47c5640-7b42-11eb-3b72-25362925c2d1
# ╠═c961ea44-7b42-11eb-3a35-bfd505fb99fb
# ╠═cd08f232-7b42-11eb-3b5b-55079d868638
# ╠═d0d5d506-7b42-11eb-0517-6318fd0ede8b
# ╠═d4548c4a-7b42-11eb-294f-d1c27fe76543
# ╠═d7915d7a-7b42-11eb-2ea7-4f0b7bd6a904
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
