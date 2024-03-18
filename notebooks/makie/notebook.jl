### A Pluto.jl notebook ###
# v0.19.37

using Markdown
using InteractiveUtils

# ╔═╡ a1497a7c-dca1-11ee-33b5-05d8568a45d6
begin
	using DataFrames
	using JLD2 #Julia format with type information
	using CSV
	#using CairoMakie
	using Statistics  # mean
	using Chain
end

# ╔═╡ ab015d73-5a37-49aa-8477-39bd96440bf8
md"""
# Data and Makie Plotting

objectives of this notebook:

1. read a dataset from jld2 format
2. describe a dataframe
3. do simple summaries and transformations on dataframes, where to find help for dataframes.jl
4. how to do a split-apply-combine operation
5. how to normalize values in a column by their initial value
6. how to normalize values in a column by the value of some other column (when that column takes on a particular value?)
7. how to compute a share across columns?
7. How to make a simple makie plot
8. How to combine several makie plots into one layout
9. Styling an existing plot to make it more beautiful
"""

# ╔═╡ 5f77e0cc-6e87-4754-9f1c-1b4433854d09
d = jldopen("data.jld2")["d"] # d is a dict inside

# ╔═╡ 71993230-52b7-477e-a35d-f390900dc816
describe(d)

# ╔═╡ 45c730b4-db3f-4358-80e3-859fc672e804
select(d, :year, "region", :ρr, 10)

# ╔═╡ 92b56650-415f-4314-940b-876f45243f46
names(d)

# ╔═╡ 8d0284b0-5d93-4b36-9be6-bfa1b8e109d5
md"""
suppose I want to get all columns with an ρ in the name
"""

# ╔═╡ 23c1594d-aacd-467c-ab49-61e7e6ccc7f3
select(d, r"ρ")  # r for regex, starts with ρ

# ╔═╡ a951a6ed-36c4-49f6-948b-d7072e52a6f9
select(sort!(d,[:year,:region]), :year, :region, r"pop") # what is that thing `popshare`?

# ╔═╡ b847c022-728f-4095-8718-5679c56f8154
md"""
1. how to compute it
2. how to test it?
"""

# ╔═╡ 8c73e695-308f-4a33-a47d-eb3108135c1a
select(subset(d, :year => x -> x .== 1840), :year, :region, :pop, :popshare)

# ╔═╡ 315abb51-a542-4e92-9b4a-445813ae147b
d1840 = subset(d, :year => x -> x.==1840)

# ╔═╡ f1cbdf84-a4e0-489d-bc69-e73919239887
select!(d1840, :year, :pop)  # let's recompute this

# ╔═╡ 3e10cfd7-215f-4c7f-ab37-999e640165d2
transform(d1840, :pop => mean) # which column you want to transform, what you want to do with it

# ╔═╡ 657d4a83-2ca3-4d11-ad5c-a5b6234261f3
transform(d1840, :pop_share2 => sum) # which column you want to transform, what you want to do with it

# ╔═╡ dcf04f62-7dc3-43cf-ba4c-1ed92f504eff
combine(d1840, :pop => mean) 

# ╔═╡ 3973cad9-18e5-456e-9f7d-ee4128257cdb
transform(d1840, :pop => x -> x.^2)    # any function works

# ╔═╡ 4e14d981-731a-4548-b9ff-ad949cd0ac64
transform(d1840, :pop => x -> x ./ sum(x))    # ... definintion of the share

# ╔═╡ b16f6a35-6e58-4ee4-818e-45fc79bd2265
transform(d1840, :pop => (x -> x ./ sum(x)) => :pop_share2)   #nicer name

# ╔═╡ 265a1bc8-9823-4f3f-8418-b43825307be4
select(subset(d, :year => x -> x.==1840), :year, :pop, :popshare)

# ╔═╡ 023cfc1d-3568-45cd-8f04-182cfd6f7f47
md"""
but do those shares sum to 1?
"""

# ╔═╡ 6317f21e-7c18-40b7-b668-f25b4dd31fa6
transform!(d1840, :pop => (x -> x ./ sum(x)) => :pop_share2)  # keep the column

# ╔═╡ 59ec5953-0770-4c33-a55c-bd21d1df9d7c
sum(d1840.pop_share2) == 1.0

# ╔═╡ 3e5b61f2-b3a5-4e7d-9bb1-35f8687502cb
d1840.pop_share3 = d1840.pop ./ sum(d1840.pop) # create new column

# ╔═╡ 0bc7864f-86cb-47b1-899d-7cb7df06b41c
md"""
ok great. now, how could we check that this is correct for all years in this data?
"""

# ╔═╡ 4dfe726c-3607-4795-8d1b-04b650a5826d
select(subset(d, :year => x -> x .<= 1860), :year, :region, :pop, :popshare)

# ╔═╡ 469baa5b-26f2-4ea2-9033-e6acff45db49
md"""
### Grouped DataFrames

let's just do the same operation as above, but now *by group*
"""

# ╔═╡ 9efbe379-c6cb-4250-925b-8e6561680213
gd = groupby(d, :year);

# ╔═╡ 56cdc06f-8c82-42cf-a656-0d6b50fbe3d4
gd[1]

# ╔═╡ 657f9328-d9c0-4bb9-a9ca-3c4ad6d4f10d
gd[2]

# ╔═╡ 826cae8d-919d-4dc7-824b-cc68c43fd79b
show(gd, allgroups = true)

# ╔═╡ 88366668-74a9-4b18-83d3-0869f2e74614
for (key, subdf) in pairs(gd)
           println("Number of data points for $(key.year): $(nrow(subdf))")
end

# ╔═╡ 44f3119d-e79e-4cc9-97d6-1b0f448552ac
gd[Dict(:year => 1900)]

# ╔═╡ cff66dce-6e54-4690-9f32-66d6675a3b9f
gd[(year = 1900,)] # this comma makes it a tuple

# ╔═╡ c0c44771-32fa-409f-b08a-76cea0729710
gd[[ (year = 1900,), (year = 2000,)]]

# ╔═╡ 20a6d0e8-6d16-43aa-9eaf-73b5b8aafb11
mykey = keys(gd) |> last #native pipe

# ╔═╡ 4725b9ab-0008-4b46-bb58-048e1e5a8d85
gd[ mykey ]

# ╔═╡ 90b9088e-5af5-40aa-88c6-1b43de954621
md"""
compute pop share by year!
"""

# ╔═╡ b9f500f9-c616-44fe-ab02-e6013fbb01d6
select(
	transform(gd, 
	:pop => (x -> x ./ sum(x)) => :pop_share2),
	:pop, :region, :year, :pop_share2 , :popshare) # as grouped by year

# ╔═╡ 31a2bb87-11db-4c6e-a60e-853d35f9188e
combine(
	groupby(d, :year),
	[:Lu, :Lr] .=> mean
)

# ╔═╡ 849cb6c7-2619-462f-8f6e-d30b8be8cfc5
combine(
	groupby(d, :year),
	["$i" => mean for i in [:Lu, :Lr]] #"$i" => mean => "$(i)_mean" to give it name
)

# ╔═╡ 0adc839b-953b-402f-96e8-dcf2eaa9311f
select(d, r"C.", :region, :year)

# ╔═╡ 4b4aa51c-1b9b-4b72-a21a-fe712c67f78c
sum(d.Cu) ./ sum(d.Cu .+ d.Cr .+ d.Ch)

# ╔═╡ 467058f6-428a-45c1-b3ff-85c0800a464a
combine(
	groupby(d, :year),
	[:Cu, :Cr, :Ch] => (
		(x,y,z) -> (rshare = sum(x) / sum(x + y + z),
					ushare = sum(y) / sum(x + y + z),
					hshare = sum(z) / sum(x + y + z)) 
	)=> AsTable # if you want to use this name, you have to use a table
)

# ╔═╡ a0dc9f62-470d-4135-8e9c-3c215f5ecdf7
md"""
digression: iris data set with 2 keys:
"""

# ╔═╡ 38d801f2-d722-4fae-ae27-1b44c204d193
path = joinpath(pkgdir(DataFrames), "docs", "src", "assets", "iris.csv");

# ╔═╡ a692e2b8-2a99-40e7-8c1d-6e20e043f18b
iris = CSV.read(path, DataFrame)

# ╔═╡ e2b15fa7-b422-4f82-a968-026f9c01c820


# ╔═╡ a304d256-cb36-4363-930f-73c34cb65d9d
function figure1_plot(d::DataFrame,offs::OrderedDict)

    K = length(unique(d.region))
    
    d[!,:LIBGEO] .= ""
    ko = collect(keys(offs))
    for i in 1:length(ko)
        d[d.region .== i, :LIBGEO] .= ko[i]
    end
    # compute shares of rural and urban land rent over income
    d.rural_rent = 100 .* d.ρr .* (d.Sr .+ d.Srh) ./ d.GDP
    d.urban_rent = 100 .* d.iq ./ d.GDP

    # create the aggregate/average city
    agg_city = combine(
        groupby(d, :year),
            :Lu => mean => :Lu,
            :Lr => mean => :Lr,
            :ρr => mean => :ρr,
            :pr => mean => :pr,
            :cityarea => mean => :cityarea,
            [:Cr,:Cu,:Ch] => ((x,y,z) -> (rshare = sum(x) / sum((x + y + z)),
                                          ushare = sum(y) / sum((x + y + z)),
                                          hshare = sum(z) / sum((x + y + z)))) => AsTable,
            [:citydensity,:Lu] => ((x,y) -> mean(x)) => :density,
            [:avgd_n,:Lu] => ((x,y) -> mean(x)) => :density_n,
            [:dr_n,:Lu] => ((x,y) -> mean(x)) => :dr_n,
            [:d0_n,:Lu] => ((x,y) -> mean(x)) => :d0_n,
            [:ρr,:Sr,:Srh,:GDP] => ((x,y,z,g) -> 100 * sum(x .* (y .+ z)) / sum(g)) => :rural_rent,
            [:iq,:GDP] => ((r,p) -> 100 * sum(r) / sum(p)) => :urban_rent,
        )

    normalizers = @chain agg_city begin
        subset(:year => ByRow(==(1840)))
        select(:Lu,:cityarea,:density, :ρr)
    end    

    # plotter setup
    idx = subset(d, :it => ieq(1))
    labs = reshape(idx.LIBGEO, 1,K)
    cols = reshape([:darkgreen,:darkgreen,:firebrick,:firebrick], 1,K)
    styles = reshape([:solid,:dot,:solid,:dot], 1,K)
    widths = reshape([3,3,3,3], 1,K)

    def_theme()
    
    pl = Dict()

    # row 1
    # Lr
    pl[:Lr] = plot(agg_city.year, agg_city.Lr, color = :darkgreen, legend = false, size = panelsizef(npanels = 3))

    # spending
    pl[:spending] = @df agg_city plot(:year, [:rshare, :ushare, :hshare], color = [:darkgreen :firebrick :darkblue], linestyle = [:solid :dot :dashdot], legend = :topleft, label = ["Rural Good" "Urban Good" "Housing"],ylims = (0,0.9), size = panelsizef(npanels = 3))

    # food price - only aggregate
    pl[:pr] = @df agg_city plot(:year, :pr, color = :darkgreen, leg = false, size = panelsizef(npanels = 3))

    # row 2
    # Urban area and population
    pl[:LuArea] = @df agg_city plot(:year, [:Lu ./ normalizers.Lu,
                                            :cityarea ./ normalizers.cityarea], yscale = :log10,yticks = [1,2,10,50,100], yformatter = x -> string(round(Int,x)),
                                            color = [reds()[1] golds()[1]],
                                            linestyle = [:solid :dash],
                                            label = ["Urban population" "Urban area"], size = panelsizef(npanels = 3))

    # Urban densities 
    pl[:aggDensities] = @df agg_city plot(:year, [:density_n ,
                                                  :d0_n ,
                                                  :dr_n ],
                                                  color = [reds()[1] golds()[1] blues()[3]],
                                                  linestyle = [:solid :dash :dashdot], size = panelsizef(npanels = 3),
                                                  label = ["Average" "Central" "Fringe"])
    pl[:aggDensities_log] = @df agg_city plot(:year, [:density_n ,
                                                  :d0_n ,
                                                  :dr_n ],
                                                  color = [reds()[1] golds()[1] blues()[3]],
                                                  linestyle = [:solid :dash :dashdot], size = panelsizef(npanels = 3),
                                                  label = ["Average" "Central" "Fringe"], yscale = :log10, yticks = [0.05,0.1,0.25,1], yformatter = x -> string(round(x,digits=2)))                                                  
    # pl[:aggDensities] = @df agg_city plot(:year, [:density ,
    # :d0 ,
    # :dr],
    # color = [reds()[1] golds()[1] blues()[3]],
    # linestyle = [:solid :dash :dashdot])

     # rural rent and urban rent
    pl[:landrents] = @df agg_city plot(:year, [:rural_rent :urban_rent],  size = panelsizef(npanels = 3), labels = ["Rural Rents" "Urban Rents"], color = [greens()[3] reds()[1]], yticks = 0:2:18, linestyle = [:solid :dot])
    # plot!(pl[:ruralrents],agg_city.year, agg_city.rural_rent, color = :grey, lw = 3, label = "")

    # third row
    # spreads 
    pl[:Lu_spread] = @df d plot(:year, :Lu ./ normalizers.Lu, group = :region, color = cols, label = labs, linestyle = styles, size = panelsizef(npanels = 3))

    pl[:cityarea_spread] = @df d plot(:year, :cityarea ./ normalizers.cityarea, group = :region, color = cols, label = labs, linestyle = styles, size = panelsizef(npanels = 3),  yscale = :log10,yticks = [1,2,5,30,100], yformatter = x -> string(round(x, digits = 2)))

    # normalize by first obs of aggregated city.
    # and do a second panel with fringe and center
    # average density
    pl[:density_spread_log] = @df d plot(:year, :citydensity ./ normalizers.density, group = :region, color = cols, label = labs, linestyle = styles, size = panelsizef(npanels = 3), yscale = :log10, yticks = [0.01,0.05,0.2,0.5,1], yformatter = x -> string(round(x,digits=2)))

    pl[:density_spread] = @df d plot(:year, :citydensity ./ normalizers.density, group = :region, color = cols, label = labs, linestyle = styles, size = panelsizef(npanels = 3))
    # # add aggregate
    # plot!(pl[:avg_density], agg_city.year, agg_city.density ./ normalizers.density, color = :grey, lw = 3, label = "")

    # # fringe density
    # pl[:fringe_density] = @df d plot(:year, :dr ./ normalizers.dr, group = :region, color = cols, label = labs, linestyle = styles, linewidth = widths, size = panelsizef(npanels = 3), yscale = :log10, yticks = [0.01,0.05,0.2,0.5,1], yformatter = x -> string(round(x,digits=2)))
    # # add aggregate
    # plot!(pl[:fringe_density], agg_city.year, agg_city.dr ./ normalizers.dr, color = :grey, lw = 3, label = "")

    # # central density
    # pl[:central_density] = @df d plot(:year, :d0 ./ normalizers.d0, group = :region, color = cols, label = labs, linestyle = styles, linewidth = widths, size = panelsizef(npanels = 3), yscale = :log10, yticks = [0.01,0.05,0.2,0.5,1], yformatter = x -> string(round(x,digits=2)))
    # # add aggregate
    # plot!(pl[:central_density], agg_city.year, agg_city.d0 ./ normalizers.d0, color = :grey, lw = 3, label = "")

    # # Urban population
    # pl[:Lu] = @df d plot(:year, :Lu ./ normalizers.Lu, group = :region, color = cols, label = labs, linestyle = styles, linewidth = widths, size = panelsizef(npanels = 3))
    # # add aggregate
    # plot!(pl[:Lu], agg_city.year, agg_city.Lu ./ normalizers.Lu, color = :grey, lw = 3, label = "")

   
    # # agg
    # plot!(pl[:cityarea], agg_city.year, agg_city.cityarea ./ normalizers.cityarea, color = :grey, lw = 3, label = "")

    # # rural rent and urban rent
    # pl[:ruralrents] = @df d plot(:year, :rural_rent, group = :region, color = cols, label = labs, linestyle = styles, linewidth = widths, size = panelsizef(npanels = 3))
    # plot!(pl[:ruralrents],agg_city.year, agg_city.rural_rent, color = :grey, lw = 3, label = "")


    # # Rural Population
    # pl[:Lr] = @df d plot(:year, :Lr, group = :region, color = cols, label = labs, linestyle = styles, linewidth = widths, size = panelsizef(npanels = 3))
    # # add aggregate
    # plot!(pl[:Lr], agg_city.year, agg_city.Lr, color = :grey, lw = 3, label = "")

    # # spending shares - only aggregate 
    # pl[:spending] = @df agg_city plot(:year, [:rshare, :ushare, :hshare], color = [:darkgreen :firebrick :darkblue], linestyle = [:solid :dot :dashdot], legend = :topleft, label = ["Rural Good" "Urban Good" "Housing"],ylims = (0,0.9))

    # # food price - only aggregate
    # pl[:pr] = @df agg_city plot(:year, :pr, color = :darkgreen, lw = 3, leg = false)
    pl
end

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
CSV = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
Chain = "8be319e6-bccf-4806-a6f7-6fae938471bc"
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
JLD2 = "033835bb-8acc-5ee8-8aae-3f567f8a3819"
Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[compat]
CSV = "~0.10.13"
Chain = "~0.6.0"
DataFrames = "~1.6.1"
JLD2 = "~0.4.46"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.10.2"
manifest_format = "2.0"
project_hash = "de9961f46fea11dd7987f07aa5386a900c9619c8"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.1"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.CSV]]
deps = ["CodecZlib", "Dates", "FilePathsBase", "InlineStrings", "Mmap", "Parsers", "PooledArrays", "PrecompileTools", "SentinelArrays", "Tables", "Unicode", "WeakRefStrings", "WorkerUtilities"]
git-tree-sha1 = "a44910ceb69b0d44fe262dd451ab11ead3ed0be8"
uuid = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
version = "0.10.13"

[[deps.Chain]]
git-tree-sha1 = "9ae9be75ad8ad9d26395bf625dea9beac6d519f1"
uuid = "8be319e6-bccf-4806-a6f7-6fae938471bc"
version = "0.6.0"

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "59939d8a997469ee05c4b4944560a820f9ba0d73"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.4"

[[deps.Compat]]
deps = ["TOML", "UUIDs"]
git-tree-sha1 = "c955881e3c981181362ae4088b35995446298b80"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.14.0"
weakdeps = ["Dates", "LinearAlgebra"]

    [deps.Compat.extensions]
    CompatLinearAlgebraExt = "LinearAlgebra"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.1.0+0"

[[deps.Crayons]]
git-tree-sha1 = "249fe38abf76d48563e2f4556bebd215aa317e15"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.1.1"

[[deps.DataAPI]]
git-tree-sha1 = "abe83f3a2f1b857aac70ef8b269080af17764bbe"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.16.0"

[[deps.DataFrames]]
deps = ["Compat", "DataAPI", "DataStructures", "Future", "InlineStrings", "InvertedIndices", "IteratorInterfaceExtensions", "LinearAlgebra", "Markdown", "Missings", "PooledArrays", "PrecompileTools", "PrettyTables", "Printf", "REPL", "Random", "Reexport", "SentinelArrays", "SortingAlgorithms", "Statistics", "TableTraits", "Tables", "Unicode"]
git-tree-sha1 = "04c738083f29f86e62c8afc341f0967d8717bdb8"
uuid = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
version = "1.6.1"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "0f4b5d62a88d8f59003e43c25a8a90de9eb76317"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.18"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.FileIO]]
deps = ["Pkg", "Requires", "UUIDs"]
git-tree-sha1 = "c5c28c245101bd59154f649e19b038d15901b5dc"
uuid = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
version = "1.16.2"

[[deps.FilePathsBase]]
deps = ["Compat", "Dates", "Mmap", "Printf", "Test", "UUIDs"]
git-tree-sha1 = "9f00e42f8d99fdde64d40c8ea5d14269a2e2c1aa"
uuid = "48062228-2e41-5def-b9a4-89aafe57970f"
version = "0.9.21"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[deps.InlineStrings]]
deps = ["Parsers"]
git-tree-sha1 = "9cc2baf75c6d09f9da536ddf58eb2f29dedaf461"
uuid = "842dd82b-1e85-43dc-bf29-5d0ee9dffc48"
version = "1.4.0"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.InvertedIndices]]
git-tree-sha1 = "0dc7b50b8d436461be01300fd8cd45aa0274b038"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.3.0"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.JLD2]]
deps = ["FileIO", "MacroTools", "Mmap", "OrderedCollections", "Pkg", "PrecompileTools", "Printf", "Reexport", "Requires", "TranscodingStreams", "UUIDs"]
git-tree-sha1 = "5ea6acdd53a51d897672edb694e3cc2912f3f8a7"
uuid = "033835bb-8acc-5ee8-8aae-3f567f8a3819"
version = "0.4.46"

[[deps.LaTeXStrings]]
git-tree-sha1 = "50901ebc375ed41dbf8058da26f9de442febbbec"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.3.1"

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

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "2fa9ee3e63fd3a4f7a9a4f4744a52f4856de82df"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.13"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.2+1"

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

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.23+4"

[[deps.OrderedCollections]]
git-tree-sha1 = "dfdf5519f235516220579f949664f1bf44e741c5"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.6.3"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools", "UUIDs"]
git-tree-sha1 = "8489905bcdbcfac64d1daa51ca07c0d8f0283821"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.8.1"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.10.0"

[[deps.PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "36d8b4b899628fb92c2749eb488d884a926614d3"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.4.3"

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "03b4c25b43cb84cee5c90aa9b5ea0a78fd848d2f"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.2.0"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "9306f6085165d270f7e3db02af26a400d580f5c6"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.4.3"

[[deps.PrettyTables]]
deps = ["Crayons", "LaTeXStrings", "Markdown", "PrecompileTools", "Printf", "Reexport", "StringManipulation", "Tables"]
git-tree-sha1 = "88b895d13d53b5577fd53379d913b9ab9ac82660"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "2.3.1"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

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

[[deps.SentinelArrays]]
deps = ["Dates", "Random"]
git-tree-sha1 = "0e7508ff27ba32f26cd459474ca2ede1bc10991f"
uuid = "91c51154-3ec4-41a3-a24f-3f23e20d615c"
version = "1.4.1"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "66e0a8e672a0bdfca2c3f5937efb8538b9ddc085"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.2.1"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
version = "1.10.0"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.10.0"

[[deps.StringManipulation]]
deps = ["PrecompileTools"]
git-tree-sha1 = "a04cabe79c5f01f4d723cc6704070ada0b9d46d5"
uuid = "892a3eda-7b42-436c-8928-eab12a02cf0e"
version = "0.3.4"

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
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "OrderedCollections", "TableTraits"]
git-tree-sha1 = "cb76cf677714c095e535e3501ac7954732aeea2d"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.11.1"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.TranscodingStreams]]
git-tree-sha1 = "3caa21522e7efac1ba21834a03734c57b4611c7e"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.10.4"
weakdeps = ["Random", "Test"]

    [deps.TranscodingStreams.extensions]
    TestExt = ["Test", "Random"]

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.WeakRefStrings]]
deps = ["DataAPI", "InlineStrings", "Parsers"]
git-tree-sha1 = "b1be2855ed9ed8eac54e5caff2afcdb442d52c23"
uuid = "ea10d353-3f73-51f8-a26c-33c1cb351aa5"
version = "1.4.2"

[[deps.WorkerUtilities]]
git-tree-sha1 = "cd1659ba0d57b71a464a29e64dbc67cfe83d54e7"
uuid = "76eceee3-57b5-4d4a-8e66-0e911cebbf60"
version = "1.6.1"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.13+1"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.8.0+1"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.52.0+1"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+2"
"""

# ╔═╡ Cell order:
# ╠═a1497a7c-dca1-11ee-33b5-05d8568a45d6
# ╟─ab015d73-5a37-49aa-8477-39bd96440bf8
# ╠═5f77e0cc-6e87-4754-9f1c-1b4433854d09
# ╠═71993230-52b7-477e-a35d-f390900dc816
# ╠═45c730b4-db3f-4358-80e3-859fc672e804
# ╠═92b56650-415f-4314-940b-876f45243f46
# ╟─8d0284b0-5d93-4b36-9be6-bfa1b8e109d5
# ╠═23c1594d-aacd-467c-ab49-61e7e6ccc7f3
# ╠═a951a6ed-36c4-49f6-948b-d7072e52a6f9
# ╟─b847c022-728f-4095-8718-5679c56f8154
# ╠═8c73e695-308f-4a33-a47d-eb3108135c1a
# ╠═315abb51-a542-4e92-9b4a-445813ae147b
# ╠═f1cbdf84-a4e0-489d-bc69-e73919239887
# ╠═3e10cfd7-215f-4c7f-ab37-999e640165d2
# ╠═657d4a83-2ca3-4d11-ad5c-a5b6234261f3
# ╠═dcf04f62-7dc3-43cf-ba4c-1ed92f504eff
# ╠═3973cad9-18e5-456e-9f7d-ee4128257cdb
# ╠═4e14d981-731a-4548-b9ff-ad949cd0ac64
# ╠═b16f6a35-6e58-4ee4-818e-45fc79bd2265
# ╠═265a1bc8-9823-4f3f-8418-b43825307be4
# ╟─023cfc1d-3568-45cd-8f04-182cfd6f7f47
# ╠═6317f21e-7c18-40b7-b668-f25b4dd31fa6
# ╠═59ec5953-0770-4c33-a55c-bd21d1df9d7c
# ╠═3e5b61f2-b3a5-4e7d-9bb1-35f8687502cb
# ╟─0bc7864f-86cb-47b1-899d-7cb7df06b41c
# ╠═4dfe726c-3607-4795-8d1b-04b650a5826d
# ╟─469baa5b-26f2-4ea2-9033-e6acff45db49
# ╠═9efbe379-c6cb-4250-925b-8e6561680213
# ╠═56cdc06f-8c82-42cf-a656-0d6b50fbe3d4
# ╠═657f9328-d9c0-4bb9-a9ca-3c4ad6d4f10d
# ╠═826cae8d-919d-4dc7-824b-cc68c43fd79b
# ╠═88366668-74a9-4b18-83d3-0869f2e74614
# ╠═44f3119d-e79e-4cc9-97d6-1b0f448552ac
# ╠═cff66dce-6e54-4690-9f32-66d6675a3b9f
# ╠═c0c44771-32fa-409f-b08a-76cea0729710
# ╠═20a6d0e8-6d16-43aa-9eaf-73b5b8aafb11
# ╠═4725b9ab-0008-4b46-bb58-048e1e5a8d85
# ╟─90b9088e-5af5-40aa-88c6-1b43de954621
# ╠═b9f500f9-c616-44fe-ab02-e6013fbb01d6
# ╠═31a2bb87-11db-4c6e-a60e-853d35f9188e
# ╠═849cb6c7-2619-462f-8f6e-d30b8be8cfc5
# ╠═0adc839b-953b-402f-96e8-dcf2eaa9311f
# ╠═4b4aa51c-1b9b-4b72-a21a-fe712c67f78c
# ╠═467058f6-428a-45c1-b3ff-85c0800a464a
# ╟─a0dc9f62-470d-4135-8e9c-3c215f5ecdf7
# ╠═38d801f2-d722-4fae-ae27-1b44c204d193
# ╠═a692e2b8-2a99-40e7-8c1d-6e20e043f18b
# ╠═e2b15fa7-b422-4f82-a968-026f9c01c820
# ╠═a304d256-cb36-4363-930f-73c34cb65d9d
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
