### A Pluto.jl notebook ###
# v0.19.14

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
end

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
	using RCall
	using Shapefile
	
	plotly()

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
let
	row = df[df.NUMBER_OF_PERSONS_KILLED .!= df.nkilled, r"KILLED"]
	
	md"""
	##### Row that doesn't have a matching sum:

	$row
	"""
end

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

# ╔═╡ 5ff69001-b1f9-4545-a3cb-1c73ff6df77a
exercise(5, md"Create a new variable death which is one if the number of persons killed is 1 or more; and zero otherwise. Construct a cross table for death versus borough. Test the null hypothesis that the two variables are not associated.")

# ╔═╡ d6155a22-b3b9-4a6e-988a-71a2f880c0ef
md"""
- We cannot answer this question until we decide what to do with the missing values for `BOROUGH`.  **Let's include missing values as their own group.**
"""

# ╔═╡ bc667107-a348-43b6-a19a-ed8de2fb269a
begin 
	df.death = df.nkilled .> 0
	df.BOROUGH2 = string.(df.BOROUGH)
	death_vs_borough = freqtable(df, :BOROUGH2, :death)
end

# ╔═╡ 924f7efc-4872-4ad7-a367-d119de956806
begin 
	death_vs_borough_test = ChisqTest(death_vs_borough);
	md"""
	#### Test for Association between "Death" and "Borough"
	- Test Statistic: $(death_vs_borough_test.stat)
	- DoF: $(death_vs_borough_test.df)
	- N: $(death_vs_borough_test.n)
	- P-value: $(pvalue(death_vs_borough_test))
	"""
end

# ╔═╡ 13657bc4-22d8-4734-bd60-f74fedd35282
md"""
### Side Quest: HypothesisTests.jl bug

- Unfortunately there is a [bug in HypothesisTest.jl's code for confidence intervals](https://github.com/JuliaStats/HypothesisTests.jl/issues/125)!
  - Confidence intervals get printed in the results for `ChisqTest`, so we get an error when we try to display `ChisqTest(death_vs_borough)`.
- So let's "cheat" and use R via [RCall.jl](https://github.com/JuliaInterop/RCall.jl).
"""

# ╔═╡ 8c8b591e-aee7-43a8-9282-b311c6b7064e
@rput death_vs_borough;

# ╔═╡ e60fba21-4d84-4d5e-a208-1e16442d3ca7
R"chisq.test(death_vs_borough)"

# ╔═╡ b5beea57-a135-48f2-b47b-6afe4e0b9433
exercise(6, md"Visualize the crashes using their latitude and longitude (and time, possibly in an animation).")

# ╔═╡ cebe0d80-e283-4dc0-8eed-727db55d0c47
md"- First, let's look at the boroughs on a map."

# ╔═╡ 8a33fbd4-023f-41da-828c-d91ea597a390
HTML("""
<p><a href="https://commons.wikimedia.org/wiki/File:5_Boroughs_Labels_New_York_City_Map.svg#/media/File:5_Boroughs_Labels_New_York_City_Map.svg"><img src="https://upload.wikimedia.org/wikipedia/commons/thumb/3/34/5_Boroughs_Labels_New_York_City_Map.svg/1200px-5_Boroughs_Labels_New_York_City_Map.svg.png" alt="5 Boroughs Labels New York City Map.svg" height=400></a>
""")

# ╔═╡ 687529e2-f44a-42de-aa3b-2e5947d5f673
md"""
- GeoJSON of Borough boundaries can be downloaded [here](https://data.cityofnewyork.us/City-Government/Borough-Boundaries/tqmj-j8zm).
"""

# ╔═╡ 91a3b321-5ba6-4cd6-bfe6-555dcde75b2c
begin
	features = GeoJSON.read(read(joinpath(@__DIR__, "data", "boundaries.geojson")))
	borough_map = plot()
	for g in features.geometry 
		plot!(borough_map, g, fillalpha=0, lw=1, linealpha=.5, aspect_ratio=1.3)
	end
	md"(get map data)"
end

# ╔═╡ 8990fd03-281c-40ca-88ef-9fc3cc8e22a7
md"""#### Begin Animation: 

$(@bind _hour Clock(1, true))
"""

# ╔═╡ 97b31aac-95fd-46f3-98ac-e3cbe835ff98
let 
	t = (_hour-1) % 24
	# filter out bad values of lat/lon
	subset = filter(df) do row 
		!ismissing(row.LONGITUDE) && row.LONGITUDE != 0 &&
		!ismissing(row.LATITUDE) && row.LATITUDE != 0 &&
		row.hour == t
	end

	p = plot(borough_map)
	scatter!(p, subset.LONGITUDE, subset.LATITUDE; title="Crashes in hour $t", 
		label="", xlab="Longitude", ylab="Latitude", markerstrokewidth=0, markersize=3)
end

# ╔═╡ 7bfa4449-f2d8-4692-b626-20cf35e8d4be
exercise(7, md"Fit a logistic model with death as the outcome variable and covariates that are available in the data or can be engineered from the data. Example covariates are crash hour, borough, number of vehicles involved, etc. Interprete your results.")

# ╔═╡ d0021a19-03e7-4d00-8aca-52ab233b590d
md"- Note: there are only $(sum(df.death)) deaths in the entire dataset of $(nrow(df)) observations."

# ╔═╡ 5cf3f941-3bf0-4698-bdfc-10fa10df2184
logmodel = let 
	f = @formula(death ~ factor1)
	glm(f, df, Binomial())
end

# ╔═╡ bc33075b-987c-42ce-9a2d-815ba034cad8
exercise(8, md"Aggregate the data to the zip-code level and connect with the census data at the zip-code level.")

# ╔═╡ 5e60806a-ec75-449e-8076-e244941cb901
begin
	zip_csv_path = joinpath(@__DIR__, "data", "ACSST5Y2020", 
		"ACSST5Y2020.S1903_data_with_overlays_2022-04-25T213110.csv")
	
	zipdf = CSV.read(zip_csv_path, DataFrame, skipto=3)
	
	rename!(zipdf, "S1903_C03_015E" => "MEDIAN_INCOME")

	select!(zipdf, [:NAME, :MEDIAN_INCOME])

	transform!(zipdf, :NAME => ByRow(x -> parse(Int, x[end-4:end])) => :ZIP_CODE)

	md"(Load the zip code data)"
end

# ╔═╡ d6f66c41-cc75-45e0-a902-3d0538775b60
begin
	shp_path = joinpath(@__DIR__, "data", "ZIP_CODE_040114", "ZIP_CODE_040114.shp")
	shp_df = DataFrame(Shapefile.Table(shp_path))
	unique_zips = unique(skipmissing(df.ZIP_CODE))

	# filter only those zip codes that we have in our dataset
	filter!(row -> parse(Int, row.ZIPCODE) in unique_zips, shp_df)

	# Only select the fields we want
	select!(shp_df, [:geometry, :ZIPCODE])

	# Convert `String` to `Int` for zip codes
	transform!(shp_df, :ZIPCODE => ByRow(x -> parse(Int, x)) => :ZIPCODE)
	
	md"(load zip code geometries from Shapefile)"
end

# ╔═╡ 8339b8f1-4569-4a4b-ac06-f84c4432d8ab
begin
	crash_by_zip = combine(groupby(df, :ZIP_CODE), nrow => :count)
	dropmissing!(crash_by_zip)
	leftjoin!(crash_by_zip, zipdf, on = :ZIP_CODE)
	crash_by_zip2 = outerjoin(crash_by_zip, shp_df, on = :ZIP_CODE => :ZIPCODE)
	dropmissing!(crash_by_zip2)
end

# ╔═╡ 1abb1322-1bc3-451b-ae99-a31d4586386b
exercise(9, md"Visualize and model the count of crashes at the zip-code level.")

# ╔═╡ 5c8080f3-bad8-4327-8091-1f11e2c28c82
let
	hover = map(eachrow(crash_by_zip2)) do row 
		"Zip Code: $(row.ZIP_CODE)<br>Crash count: $(row.count)"
	end
	plot(crash_by_zip2.geometry; fill_z = crash_by_zip2.count', 
		color = palette(:viridis),
		aspect_ratio = 1, 
	    linecolor = :white, 
		linewidth = .5, 
		title = "N Crashes by Zip Code",
		framestyle = :none, 
		hover = hover
	)
end

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
# ╠═bc6a445e-85e2-4217-8261-3d1250460480
# ╟─89d270f1-95ec-491e-a007-5ddcdc2e642d
# ╟─54c2966f-0152-49c1-b862-da547a8cbd6b
# ╟─364dc26c-b994-4a06-9e37-ac9a5d4f11bb
# ╟─e3b2ef1c-84fd-43fe-a22c-3dce55d01df2
# ╟─5ff69001-b1f9-4545-a3cb-1c73ff6df77a
# ╟─d6155a22-b3b9-4a6e-988a-71a2f880c0ef
# ╟─bc667107-a348-43b6-a19a-ed8de2fb269a
# ╟─924f7efc-4872-4ad7-a367-d119de956806
# ╟─13657bc4-22d8-4734-bd60-f74fedd35282
# ╠═8c8b591e-aee7-43a8-9282-b311c6b7064e
# ╠═e60fba21-4d84-4d5e-a208-1e16442d3ca7
# ╟─b5beea57-a135-48f2-b47b-6afe4e0b9433
# ╟─cebe0d80-e283-4dc0-8eed-727db55d0c47
# ╟─8a33fbd4-023f-41da-828c-d91ea597a390
# ╟─687529e2-f44a-42de-aa3b-2e5947d5f673
# ╟─91a3b321-5ba6-4cd6-bfe6-555dcde75b2c
# ╟─8990fd03-281c-40ca-88ef-9fc3cc8e22a7
# ╟─97b31aac-95fd-46f3-98ac-e3cbe835ff98
# ╟─7bfa4449-f2d8-4692-b626-20cf35e8d4be
# ╟─d0021a19-03e7-4d00-8aca-52ab233b590d
# ╠═5cf3f941-3bf0-4698-bdfc-10fa10df2184
# ╟─bc33075b-987c-42ce-9a2d-815ba034cad8
# ╟─5e60806a-ec75-449e-8076-e244941cb901
# ╟─d6f66c41-cc75-45e0-a902-3d0538775b60
# ╠═8339b8f1-4569-4a4b-ac06-f84c4432d8ab
# ╟─1abb1322-1bc3-451b-ae99-a31d4586386b
# ╟─5c8080f3-bad8-4327-8091-1f11e2c28c82
