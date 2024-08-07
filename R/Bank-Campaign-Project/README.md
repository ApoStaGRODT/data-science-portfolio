# Bank Campaign Analysis

This project analyzes a bank marketing campaign dataset to understand customer responses and build predictive models.

## Project Structure

- **Data**: The dataset used for analysis.
- **Scripts**: The R script used for the analysis.
- **Results**: Outputs and visualizations from the analysis.

## Main Script

- `BankCampaignRproject.R`: This script includes:
  - Loading the data
  - Data cleaning and preprocessing
  - Exploratory data analysis (EDA)
  - Building and evaluating models
  - Visualizing results

## Data

The dataset comes from a bank's direct marketing campaign. The goal is to predict if a client will subscribe to a term deposit.

https://archive.ics.uci.edu/dataset/222/bank+marketing


## Running the Project

1. **Install Required Packages**:
    ```R
    install.packages(c("dplyr", "ggplot2", "caret", "randomForest"))
    ```

2. **Load the Data**: Ensure your dataset is available in the working directory or specify the correct path in the script.

3. **Run the Script**: Execute `BankCampaignRproject.R` to perform the analysis.

## Summary of the Script

### 1. Loading the Data
The script starts by loading the dataset into R.

### 2. Data Cleaning and Preprocessing
Includes steps to handle missing values, encode categorical variables, and split the data into training and test sets.

### 3. Exploratory Data Analysis (EDA)
Uses `ggplot2` for visualizing data distributions, correlations, and other insights.

### 4. Building and Evaluating Models
Models such as logistic regression and random forests are built and evaluated using metrics like accuracy, precision, and recall.

### 5. Visualizing Results
Plots the performance of the models and important features affecting the predictions.

## Results

The analysis results, including visualizations and model evaluations, are generated and saved during the script execution.

# Author

- [Apostolos Stavrou](https://www.linkedin.com/in/apostolos-stavrou-644982230/)
