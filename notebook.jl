### A Pluto.jl notebook ###
# v0.19.13

using Markdown
using InteractiveUtils

# ╔═╡ c17fde86-3846-11ed-08c9-7578912ec511
begin
	using Pkg
	Pkg.activate(@__DIR__)
	
	using StatsPlots
	using CSV
	using StatsBase
	using Dates
	using DataFrames
	using PlutoUI
	using Cobweb: h
	using FreqTables
	using HypothesisTests
	using OnlineStats
	using GeoJSON
	using GLM
	
	gr()

	exercise(i, description) = h.div(
		md"""
		## Exercise $i

		- $description
		""";
		style="border-radius: 5px; padding: 1px 12px 1px 12px; background: #155e75; color: #67e8f9;"
	)
	
	md"(setup) $(PlutoUI.TableOfContents())"
end

# ╔═╡ 283ae22b-7d10-45a9-9470-584a996549be
md"# Load Data"

# ╔═╡ c2d7156f-7d2c-4aa4-8972-610751ade61b
md"""
We load the data with [**CSV.jl**](https://github.com/JuliaData/CSV.jl).  We are providing the following keyword arguments to `CSV.read`:
- `dateformat`: Tell Julia how dates are formatted.
- `normalizenames`: Replace spaces with underscores in variable names.
- `stringtype`: Tell Julia to use the `Base.String` type for strings.
  - There are several string types **CSV.jl** can use for various performance reasons, but `String` is often the easiest to work with.
"""

# ╔═╡ 5d7a6d11-d087-4e02-890a-7df1d15d8514
begin 
	csv_url = "https://raw.githubusercontent.com/statds/ids-s22/main/notes/data/nyc_mv_collisions_202201.csv"
	
	df =  CSV.read(download(csv_url), DataFrame; 
		dateformat = "mm/dd/yyyy", # interpret dates as `Dates.Date` vs. `String`
		normalizenames = true,     # remove spaces in names
		stringtype = String)	   # use the `Base.String` type
	
	describe(df)
end

# ╔═╡ 92086a7b-62f9-4141-b7cb-2aaa0fdc8c66
md"# Scientific Exercises"

# ╔═╡ c4a7b0a7-4f09-4448-8df3-9452b4b45eab
exercise(1, md"Create a frequency table of the number of crashes by borough.")

# ╔═╡ 63b3f088-fe29-4771-ac01-a4f299fa3a54
md"""
- **Split**: Group by `BOROUGH`.
- **Apply/Combine**: Use `combine` to return the `nrow` of each group.
"""

# ╔═╡ 6f7c3df2-34f9-4184-801d-7a40f2926246
combine(groupby(df, :BOROUGH), nrow => :count)

# ╔═╡ 5a4f9311-5816-4dc1-9840-6f7cc06f23a5
exercise(2, md"Create an hour variable with integer values from 0 to 23, and plot of the histogram of crashes by hour.")

# ╔═╡ 7aae64cb-3888-4d79-898f-65ccfb17a5d8
md"""
- First, we use Julia's **`Dates`** standard library to combine the `CRASH_DATE`/`CRASH_TIME` fields into `Dates.DateTime`s.  Note the "dot" syntax is used for [broadcasting](https://docs.julialang.org/en/v1/manual/arrays/#Broadcasting) in Julia.
- We then extract the `Dates.hour`.
"""

# ╔═╡ e71c369b-2aaf-43bd-be96-c183ac1b098c
begin 
	df.datetime = DateTime.(df.CRASH_DATE, Time.(df.CRASH_TIME))
	df.hour = hour.(df.datetime)
	
	histogram(df.hour; xlab="Hour of Day", ylab="Count", 
		title="Crashes by Hour of Day", label="",
		xticks=0:4:24, xlim=(0,24), ylim=(0, Inf))
end

# ╔═╡ 2c967d81-6ee6-483a-9b7b-aa137f9bd409
exercise(3, md"Check if the number of persons killed is the summation of the number of pedestrians killed, cyclist killed, and motorists killed. From now on, use the number of persons killed as the sum of the pedestrians, cyclists, and motorists killed.")

# ╔═╡ bc6a445e-85e2-4217-8261-3d1250460480
let 
	# create "nkilled" variable
	df.nkilled = map(+,
		df.NUMBER_OF_PEDESTRIANS_KILLED,
		df.NUMBER_OF_CYCLIST_KILLED,
		df.NUMBER_OF_MOTORIST_KILLED
	)
	
	# Check "NUMBER_OF_PERSONS_KILLED" vs. "nkilled"
	n = nrow(df)
	n2 = sum(df.NUMBER_OF_PERSONS_KILLED .== df.nkilled)
	perc = round(100n2 / n, digits=2)
	
	# Pretty print the result
	Markdown.parse("#### $n / $n2 ($perc%) rows have a matching sum!")
end

# ╔═╡ 89d270f1-95ec-491e-a007-5ddcdc2e642d
# Only one row has a sum that doesn't match
df[df.NUMBER_OF_PERSONS_KILLED .!= df.nkilled, r"KILLED"]

# ╔═╡ 54c2966f-0152-49c1-b862-da547a8cbd6b
exercise(4, md"Construct a cross table for the number of persons killed by the contributing factors of vehicle one. Collapse the contributing factors with a count of less than 100 to “other”. Is there any association between the contributing factors and the number of persons killed?")

# ╔═╡ 364dc26c-b994-4a06-9e37-ac9a5d4f11bb
cross_table = let
	# get countmap of factors
	cm = countmap(df.CONTRIBUTING_FACTOR_VEHICLE_1)
	# get factors that occur <100 times
	small_factors = filter(kv -> kv[2] < 100, cm)
	# recode rare factors as "Other"
	_recode(x) = x in keys(small_factors) ? "Other" : x
	df.factor1 = _recode.(df.CONTRIBUTING_FACTOR_VEHICLE_1)

	# cross table
	freqtable(df, :factor1, :nkilled)
end

# ╔═╡ e3b2ef1c-84fd-43fe-a22c-3dce55d01df2
# Weak evidence of association between :factor1 and :nkilled
ChisqTest(cross_table)

# ╔═╡ 3881c9dd-ff8c-45f7-aa03-74dfe35506ba


# ╔═╡ 5ff69001-b1f9-4545-a3cb-1c73ff6df77a
exercise(5, md"Create a new variable death which is one if the number of persons killed is 1 or more; and zero otherwise. Construct a cross table for death versus borough. Test the null hypothesis that the two variables are not associated.")

# ╔═╡ d6155a22-b3b9-4a6e-988a-71a2f880c0ef
md"""
- We cannot answer this question until we decide what to do with the missing values for `BOROUGH`.
- Let's include them as a group.
"""

# ╔═╡ bc667107-a348-43b6-a19a-ed8de2fb269a
begin 
	df.death = df.nkilled .> 0
	df.BOROUGH2 = string.(df.BOROUGH)
	death_vs_borough = freqtable(df, :BOROUGH2, :death)
end

# ╔═╡ 53627488-f791-461a-b11e-326f612ed136
Matrix(death_vs_borough)

# ╔═╡ b27d4f0f-5714-400b-a60b-eb1dfca05d13
# Hmm, why DomainError?
ChisqTest(death_vs_borough)

# ╔═╡ 14ead7fa-677d-4b79-abf1-b13a0a6c7e1e
let 
	O = Matrix(death_vs_borough)
	E = sum(O, dims=1) .* sum(O, dims=2) ./ sum(O)
	sum((o - e) ^ 2 / e for (o,e) in zip(O,E))
end

# ╔═╡ b5beea57-a135-48f2-b47b-6afe4e0b9433
exercise(6, md"Visualize the crashes using their latitude and longitude (and time, possibly in an animation).")

# ╔═╡ 687529e2-f44a-42de-aa3b-2e5947d5f673
md"""
- Downloaded GeoJSON of Borough boundaries [here](https://data.cityofnewyork.us/City-Government/Borough-Boundaries/tqmj-j8zm).
"""

# ╔═╡ 91a3b321-5ba6-4cd6-bfe6-555dcde75b2c
features = GeoJSON.read(read(joinpath(@__DIR__, "data", "boundaries.geojson")))

# ╔═╡ ba735e38-e73d-479b-86ae-8a0b4fea54be


# ╔═╡ c7b372c4-456d-43da-8521-61ccbce0532c
let 
	# create map to plot over
	borough_map = plot()
	for g in features.geometry 
		plot!(borough_map, g, fillalpha=0, aspect_ratio=1)
	end

	# filter out bad values of lat/lon
	df2 = filter(df) do row 
		!ismissing(row.LONGITUDE) && row.LONGITUDE > 0
			!ismissing(row.LATITUDE) && row.LATITUDE > 0
			
	end

	# Create animation (1 hour/frame)
	anim = @animate for i in 0:23
		subset = filter(row -> row.hour == i, df2)
		plot(borough_map)
		scatter!(subset.LONGITUDE, df2.LATITUDE; title="Crashes in hour $i", 
			label="", xlab="Longitude", ylab="Latitude", markerstrokewidth=0, markersize=3)
	end
	gif(anim, fps=4)
end

# ╔═╡ 7bfa4449-f2d8-4692-b626-20cf35e8d4be
exercise(7, md"Fit a logistic model with death as the outcome variable and covariates that are available in the data or can be engineered from the data. Example covariates are crash hour, borough, number of vehicles involved, etc. Interprete your results.")

# ╔═╡ 5cf3f941-3bf0-4698-bdfc-10fa10df2184
logmodel = let 
	f = @formula(death ~ hour + BOROUGH)
	glm(f, df, Binomial())
end

# ╔═╡ bc33075b-987c-42ce-9a2d-815ba034cad8
exercise(8, md"Aggregate the data to the zip-code level and connect with the census data at the zip-code level.")

# ╔═╡ 1abb1322-1bc3-451b-ae99-a31d4586386b
exercise(9, md"Visualize and model the count of crashes at the zip-code level.")

# ╔═╡ Cell order:
# ╟─c17fde86-3846-11ed-08c9-7578912ec511
# ╟─283ae22b-7d10-45a9-9470-584a996549be
# ╟─c2d7156f-7d2c-4aa4-8972-610751ade61b
# ╟─5d7a6d11-d087-4e02-890a-7df1d15d8514
# ╟─92086a7b-62f9-4141-b7cb-2aaa0fdc8c66
# ╟─c4a7b0a7-4f09-4448-8df3-9452b4b45eab
# ╟─63b3f088-fe29-4771-ac01-a4f299fa3a54
# ╟─6f7c3df2-34f9-4184-801d-7a40f2926246
# ╟─5a4f9311-5816-4dc1-9840-6f7cc06f23a5
# ╟─7aae64cb-3888-4d79-898f-65ccfb17a5d8
# ╟─e71c369b-2aaf-43bd-be96-c183ac1b098c
# ╟─2c967d81-6ee6-483a-9b7b-aa137f9bd409
# ╟─bc6a445e-85e2-4217-8261-3d1250460480
# ╠═89d270f1-95ec-491e-a007-5ddcdc2e642d
# ╟─54c2966f-0152-49c1-b862-da547a8cbd6b
# ╟─364dc26c-b994-4a06-9e37-ac9a5d4f11bb
# ╠═e3b2ef1c-84fd-43fe-a22c-3dce55d01df2
# ╠═3881c9dd-ff8c-45f7-aa03-74dfe35506ba
# ╟─5ff69001-b1f9-4545-a3cb-1c73ff6df77a
# ╟─d6155a22-b3b9-4a6e-988a-71a2f880c0ef
# ╠═bc667107-a348-43b6-a19a-ed8de2fb269a
# ╠═53627488-f791-461a-b11e-326f612ed136
# ╠═b27d4f0f-5714-400b-a60b-eb1dfca05d13
# ╠═14ead7fa-677d-4b79-abf1-b13a0a6c7e1e
# ╟─b5beea57-a135-48f2-b47b-6afe4e0b9433
# ╟─687529e2-f44a-42de-aa3b-2e5947d5f673
# ╠═91a3b321-5ba6-4cd6-bfe6-555dcde75b2c
# ╠═ba735e38-e73d-479b-86ae-8a0b4fea54be
# ╟─c7b372c4-456d-43da-8521-61ccbce0532c
# ╟─7bfa4449-f2d8-4692-b626-20cf35e8d4be
# ╠═5cf3f941-3bf0-4698-bdfc-10fa10df2184
# ╟─bc33075b-987c-42ce-9a2d-815ba034cad8
# ╟─1abb1322-1bc3-451b-ae99-a31d4586386b
