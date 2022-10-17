# Data Jamboree 2022: Julia

- https://asa-ssc.github.io/minisymp2022/jamboree/

## Exercises

- Create a frequency table of the number of crashes by borough.
- Create an `hour` variable with integer values from 0 to 23, and plot of the histogram of crashes by hour.
- Check if the number of persons killed is the summation of the number of pedestrians killed, cyclist killed, and motorists killed. From now on, use the number of persons killed as the sum of the pedestrians, cyclists, and motorists killed.
- Construct a cross table for the number of persons killed by the contributing factors of vehicle one. Collapse the contributing factors with a count of less than 100 to “other”. Is there any association between the contributing factors and the number of persons killed?
- Create a new variable death which is one if the number of persons killed is 1 or more; and zero otherwise. Construct a cross table for death versus borough. Test the null hypothesis that the two variables are not associated.
- Visualize the crashes using their latitude and longitude (and time, possibly in an animation).
- Fit a logistic model with death as the outcome variable and covariates that are available in the data or can be engineered from the data. Example covariates are crash hour, borough, number of vehicles involved, etc. Interprete your results.
- Aggregate the data to the zip-code level and connect with the census data at the zip-code level.
- Visualize and model the count of crashes at the zip-code level.
