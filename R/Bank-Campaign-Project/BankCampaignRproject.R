#The dataset that will be reviewed originates from direct marketing campaigns conducted by
# a Portuguese banking institution. These campaigns were executed through phone calls, with some clients
# being contacted multiple times to evaluate their interest in subscribing to a bank term deposit.

#The primary classification goal of this project is to predict whether a client will subscribe
# to a term deposit.
#By understanding the demographic and transactional characteristics that affect a client's decision
# and identifying patterns and insights in the data that can result in effective marketing strategies,
# we'll build and evaluate a predictive model that can accurately forecast subscription outcomes.

# Starting by importing some essential and commonly used packages.
library(dplyr)
library(tidyr)
library(ggplot2)
library(caret)
library(pROC)
library(ROSE)
library(randomForest)
library(glmnet)
library(knitr)
library(rmarkdown)

# Loading the data
data1 <- read.csv("C:/Users/teleu/.data/Rstudio/BankProject/bank-full.csv",sep=';')

# Data exploration
head(data1)
dim(data1) #45211 rows and 17 columns
str(data1) #datatypes appear to be correct
summary(data1) #Noticeable in 'Balance' column there is significantly higher mean than median 
# which suggests a right-skewed distribution with potential outliers (especially on the higher end).
#Also, the presence of negative values indicates that some clients might be in debt.


#Testing for missing values, first we replace 'unknown' with 'NA'
columns_with_unknown <- sapply(data1, function(x) any(x == "unknown"))
data1[columns_with_unknown] <- lapply(data1[columns_with_unknown], 
                                      function(x) replace(x, x == "unknown", NA))


sum(is.na(data1)) #52124 overall missing values.
colSums(is.na(data1)) #A lot of missing values spotted in 'contact' and 'poutcome' columns,
# we'll exclude them for now as intuitively, they won't be our most important parameters.
data2 <- select(data1, -poutcome, -contact)
#We'll also exclude rows with missing values on 'education' and 'age' columns.
data <- data2[!(is.na(data1$education) | is.na(data1$job)), ]
#We use '!' to exclude rows where education OR job are NA.


#Correcting erroneous data
any(data$age < 18) 
any(data$day < 0) 
any(data$month < 0)
any(data$duration < 0) 
any(data$campaign < 0) 
any(data$previous < 0)
#All return FALSE, there are no negative values on these numeric attributes as expected.


#Transforming age from a continuous variable to a discreet one, split into 5 quintiles.
age_quintiles <- quantile(data$age, probs = seq(0, 1, by = 0.2))
age_quintiles[6] <- max(data$age) + 0.1 
data$age_group <- cut(data$age, breaks = age_quintiles,include.lowest = TRUE,
                      right = TRUE, #Make intervals right-inclusive.
                      labels = c('Q1', 'Q2', 'Q3', 'Q4', 'Q5'))

print(age_quintiles) #We can see the age range of each quintile as: (18-31,32-35,36-41,42-50,51+).
table(data$age_group)
#While not as symmetric as usual ranges of age, the count of each quintile is split fairly evenly.
sum(is.na(data$age_group)) #Thanks to adjustments such as include.lowest and right = true
# there are no missing values in the newly created categorical age_group.


#Reordering columns 'age_group' and 'y' so that 'y' is again the last column.
all_columns <- names(data)
rest_columns <- all_columns[!all_columns %in% c("age_group",'y')]
data <- data[, c(rest_columns, "age_group",'y')]
print(names(data))




#Histogram creation for 'Age' and bar chart for 'Education'.
ggplot(data,aes(x = age)) +
  geom_histogram(binwidth = 5, fill = 'darkorange', color = 'black') + 
  theme_minimal() + labs(title = "Histogram of Age", x = 'Age', y = 'Frequency')
#Results in a right-skewed distirbution, indicating a higher concentration of younger clients.


ggplot(data,aes(x = education)) +
  geom_bar(fill = 'salmon', color = 'black') + theme_minimal() +
  labs(title = "Bar Chart of Education Levels", x = "Education Levels", y = 'Count')
# Majority of clients in the dataset consist of secondary and tertiary eudcation levels.


#Identifying outliers.
boxplot_stats <- boxplot(data$duration, plot=TRUE)
#For duration we see most calls last under 15 minutes (900 seconds) with some calls
# going for as long as 50 minutes.
print(data[data$duration > 3000, c('duration', 'y')])
#Interestingly, more than half of those calls ended up with the customers not
# making a term deposit.

#Utilizing correlation matrices and scatter plots to understand relationships between variables.
library(corrplot)
CorrMatrix <- cor(data[, sapply(data,is.numeric)], use = 'complete.obs')
corrplot(CorrMatrix, method = 'circle')

#Few interesting observations to make by this correlation matrix are:
#Age does not seem to have a strong linear correlation with balance, indicating that client's age
# might not necessarily predict their bank balance within this dataset.
#Fair correlation between 'pdays' and 'previous' might reflect that the bank targets clients
# who showed interest in previous campaigns and they tend to reach out to these interested clients
# sooner rather than later in new campaigns.


#This takes a while to load, in order to prevent accidentally loading it will be included
# as comment.

#pairs(data[, sapply(data, is.numeric)], main = "Scatterplot Matrix")

#Lower 'pdays' associated with longer call 'duration' may indicate more in-depth discussions in
# recent contacts, suggesting increased engagement during calls made closer to the last contact.
#Lack of linear relationships suggests that simple linear regression may not be the best model
# for this data.


#Converting 'y' to  factor and releveling of the output so that 'yes' is considered the 
# positive class.
data$y <- factor(data$y, levels = c('yes','no'))


#Time to split the data (using caret library) into training and testing, personal preference
# for large datasets is 85/15 split. 
set.seed(1)
split <- createDataPartition(data$y, p = 0.85, list = FALSE)
train_set <- data[split, ]
test_set <- data[-split, ]


#Time to apply recursive feature elimination, a popular method for feature ranking
# and recursively removing variables. First, defining control using linear model 
# functions. 
#Using Cross-validation method with 5 folds for relatively quick computation.
control <- rfeControl(functions = rfFuncs, method = 'cv', number = 5, verbose = TRUE)

#Running RFE. Warning this will take a long time.
results <- rfe(train_set[, -ncol(train_set)], train_set$y, sizes = c(1:15),
               rfeControl = control)

print(results)
predictors(results)

#Features ranked by order according to their contribution to modeling:
# Duration, month, housing, pdays, age, day, previous, campaign, loan, job,
# age_group, education, balance, marital.
#Intuitively, selecting top 5 features should not affect metrics much
# compared to taking top 8 features (as recommended by RFE) 
# and it will also help prevent overfitting.

dataf <- data[c('duration', 'month', 'housing', 'pdays', 'y')]

#Encoding categorical variables using One Hot Encoding.
dummies <- dummyVars(~ . - y, data = dataf)
dataf <- predict(dummies, newdata = dataf)
dataf <- as.data.frame(dataf)
dataf$y <- data$y
head(dataf)


#Splitting the data of 'dataf'.
split <- createDataPartition(dataf$y, p = 0.85, list = FALSE)
train_set <- dataf[split, ]
test_set <- dataf[-split, ]

#Setting up cross-validation for model training with trainControl method.
train_control <- trainControl(method = 'repeatedcv', number = 10, repeats = 3,
                              classProbs = TRUE)

#Training the model with caret function 'train', using generalized linear model method.
log_model <- train(y~., data = dataf, method = 'glm', family = 'binomial',
                   trControl = train_control)

print(log_model)
#Shows an impressive accuracy of 89%, but a low Kappa statistic of 31%. This indicates that there
# is room for improvement in how effectively it discriminates between the two classes.

#Predict on testing set.
test_pred_prob <- predict(log_model, newdata = test_set, type = 'prob')
test_pred_class <- predict(log_model, newdata = test_set, type = 'raw')

#Further evaluating the model with metrics obtained by confusion matrix.
conf_matrix <- confusionMatrix(test_pred_class, test_set$y)
print(conf_matrix)


#Current model is strong at predicting majority class ('no') but less effective at predicting
# 'yes' subscriptions, as indicated by the imbalance between sensitivity and specificity 
# (0.25 and 0.98 respectively).
#Low positive predictive value (0.63) could potentially lead to missed opportunities in
# targeting potential subscribers.

#Before we proceed with further evaluation metrics, we should tackle the issue of
# class imbalance.
table(train_set$y)

#Applying SMOTE technique with ROSE library. We'll balance positive and negative classes so that
# both are 32447 (number of majority 'no' class).
datab <- ovun.sample(y ~ ., data = train_set, method = 'over', N = 32447 * 2)$data
log_model <- train(y ~ ., data = datab, method = 'glm', family = 'binomial', trControl = train_control)
datab$y <- factor(datab$y, levels = c('yes','no'))
table(datab$y)

#Recalculating confusion matrix.
test_pred_prob <- predict(log_model, newdata = test_set, type = 'prob')
test_pred_class <- predict(log_model, newdata = test_set, type = 'raw')
conf_matrix <- confusionMatrix(test_pred_class, test_set$y)
print(conf_matrix)

#Calculating F1 score metric.
precision <- conf_matrix$byClass['Pos Pred Value']
recall <- conf_matrix$byClass['Sensitivity']
F1_score <- 2 * (precision * recall) / (precision + recall)
print(F1_score)
#Returns a F1 score of 0.51%.


#Creating ROC object.
ROC_obj <- roc(response = test_set$y, predictor = test_pred_prob[, 'yes'])
plot(ROC_obj, main = 'ROC Curve',col = "#000000")
AUC_value <- auc(ROC_obj)
text(0.8,0.2, paste("AUC =", round(AUC_value, 2)), col = "#000000")


#In this project, we're particularly focused on identifying potential clients who are likely
# to subscribe to a term deposit,  since making an incorrect prediction here doesn't cost
# us anything.
#Training model with Random Forest technique with adjusted class weights to improve sensitivity.
rf_model <- randomForest(y ~ ., data = train_set, ntree = 100,
                         mtry = sqrt(ncol(train_set)-1), classwt = c(no= 1, yes = 3))
rf_prediction <- predict(rf_model, newdata = test_set)
rf_confusion <- table(Predicted = rf_prediction, Actual = test_set$y)
rf_sensitivity <- rf_confusion[2,2] / (rf_confusion[2,2] + rf_confusion[2,1])
print(rf_sensitivity)
print(rf_confusion)

#Using random forest modeling we can reach an impressive sensitivity rate of 0.99%
