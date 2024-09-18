using Random
using OrderedCollections
f(x) = sin(x)^2 + 0.1x

function V(sample_points, f)
    n = length(sample_points)
    F = f.(sample_points)
    f_avg = sum(F) / n
    stdd = sqrt(sum((F .- f_avg).^2) / (n-1))
    return stdd
end

sample_points = rand(1000)*5

mc_integrate = function(fun, n)
    Random.seed!(0)
    sample_points = rand(n)*5
    stdd = V(sample_points, fun)
    Q_n = 5 * sum(fun.(sample_points)) / n
    return Q_n, stdd
end

ns = [2, 4, 10, 20, 50, 100, 1000, 10000]
mc_results = OrderedDict(k => mc_integrate(f, k) for k in ns)
