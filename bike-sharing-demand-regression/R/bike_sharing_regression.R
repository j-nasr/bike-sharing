# ------------------------------------------------------------------------------
# Predicting Daily Bike Rental Demand: Comparing Regression Models
# Course: Predictive Analytics | Group project (see README for authors)
#
# Question: Which regression specification best predicts daily Capital Bikeshare
#           rentals from calendar and weather variables?
# Approach: Fit 5 linear models and compare them with a validation-set split,
#           LOOCV, 5-fold CV and 10-fold CV (lower MSE = better).
#
# Run from the repository root:  Rscript R/bike_sharing_regression.R
# ------------------------------------------------------------------------------

library(boot)  # cv.glm()

# ---- 1. Load and prepare data -------------------------------------------------
df <- read.csv("data/bike_sharing_daily.csv")
df <- na.omit(df)
df$cnt <- df$cnt / 1000   # response in thousands of rides, so MSE is easier to read

str(df)
summary(df)

# ---- 2. Candidate models ------------------------------------------------------
# Formulas kept exactly as in the original analysis.
formulas <- list(
  "Model 1" = cnt ~ .,
  "Model 2" = cnt ~ mnth + weathersit + hum + windspeed,
  "Model 3" = cnt ~ season + yr + mnth + weekday + workingday + weathersit +
                temp + atemp + hum + windspeed * hum + temp * weathersit,
  "Model 4" = cnt ~ season + yr + mnth + weekday + workingday + weathersit +
                temp + atemp + hum + I(atemp^2) + I(hum^2),
  "Model 5" = cnt ~ weathersit
)

# ---- 3. Validation-set approach (70/30 split, repeated) -----------------------
# One split can be lucky or unlucky, so repeat it and average the test MSE.
n_reps <- 100
val_mse <- matrix(NA, nrow = n_reps, ncol = length(formulas),
                  dimnames = list(NULL, names(formulas)))

for (i in seq_len(n_reps)) {
  set.seed(i)
  idx   <- sample(nrow(df), round(nrow(df) * 0.7))
  train <- df[idx, ]
  test  <- df[-idx, ]
  for (m in names(formulas)) {
    fit <- lm(formulas[[m]], data = train)
    val_mse[i, m] <- mean((test$cnt - predict(fit, test))^2)
  }
}

# ---- 4. Cross-validation (LOOCV, 5-fold, 10-fold) -----------------------------
cv_error <- function(formula, K = nrow(df)) {
  fit <- glm(formula, data = df)          # glm() with gaussian family == lm()
  cv.glm(df, fit, K = K)$delta[1]         # raw CV estimate of test MSE
}

set.seed(100)  # k-fold folds are random; fix the seed for reproducibility
results <- data.frame(
  Model        = names(formulas),
  Validation   = round(colMeans(val_mse), 4),
  LOOCV        = round(sapply(formulas, cv_error), 4),
  CV_5_fold    = round(sapply(formulas, cv_error, K = 5), 4),
  CV_10_fold   = round(sapply(formulas, cv_error, K = 10), 4),
  row.names    = NULL
)
print(results)

# ---- 5. Save results and figures ----------------------------------------------
dir.create("outputs/figures", recursive = TRUE, showWarnings = FALSE)
write.csv(results, "outputs/model_comparison.csv", row.names = FALSE)

png("outputs/figures/model_comparison_r.png", width = 900, height = 550, res = 120)
best <- which.min(results$LOOCV)
barplot(results$LOOCV, names.arg = results$Model,
        col = ifelse(seq_along(results$LOOCV) == best, "#1f6f8b", "grey75"),
        border = NA, ylab = "LOOCV MSE (thousands of rides squared)",
        main = "Model 4 has the lowest cross-validated error")
dev.off()

# Coefficients of the full model (Model 1) for interpretation
print(summary(lm(formulas[["Model 1"]], data = df))$coefficients)
